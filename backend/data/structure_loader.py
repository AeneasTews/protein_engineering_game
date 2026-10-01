from __future__ import annotations

import logging
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import gemmi
from data.loader import Protein

logger = logging.getLogger(__name__)

RCSB_CIF_URL = "https://files.rcsb.org/download/{pdb_id}.cif"
FETCH_TIMEOUT_SECONDS = 30


@dataclass
class ResidueMapping:
    """Where one position of the game's wildtype sequence lives in the served mmCIF."""

    position: int  # 1-based, matches wildtype_sequence[position - 1]
    chain_id: str  # label_asym_id
    auth_seq_id: int
    insertion_code: str  # "" when the residue has none


@dataclass
class ExtractedStructure:
    pdb_id: str
    cif: str  # first model, matched chain and residue window only; no ligands or waters
    residues: list[ResidueMapping]


def _fetch_cif_text(pdb_id: str) -> str | None:
    url = RCSB_CIF_URL.format(pdb_id=pdb_id)
    try:
        with urllib.request.urlopen(url, timeout=FETCH_TIMEOUT_SECONDS) as response:
            return response.read().decode("utf-8")
    except (urllib.error.URLError, TimeoutError, ValueError) as e:
        logger.error("Failed to fetch %s: %s", url, e)
        return None


def _one_letter(residue_name: str) -> str:
    info = gemmi.find_tabulated_residue(residue_name)
    if not info.is_amino_acid():
        return "\0"
    return info.one_letter_code.upper()


def _polymer_sequence(polymer: list[gemmi.Residue]) -> str:
    return "".join(_one_letter(r.name) for r in polymer)


def _has_ca(residue: gemmi.Residue) -> bool:
    return any(atom.name == "CA" for atom in residue)


def _trimmed_cif(
    st: gemmi.Structure, chain_name: str, window: list[gemmi.Residue]
) -> str:
    """The structure cut down to what the game shows: model 1, one chain, the window's residues.

    Header records (entities, helices, sheets) are kept so the client's mmCIF parser can
    read secondary structure the same way it would from the original file.
    """
    keep = {(r.seqid.num, r.seqid.icode) for r in window}
    trimmed = st.clone()
    while len(trimmed) > 1:
        del trimmed[1]
    trimmed.remove_ligands_and_waters()
    model = trimmed[0]
    for name in [c.name for c in model if c.name != chain_name]:
        model.remove_chain(name)
    chain = model[chain_name]
    for i in reversed(range(len(chain))):
        if (chain[i].seqid.num, chain[i].seqid.icode) not in keep:
            del chain[i]
    trimmed.remove_empty_chains()
    _clip_secondary_structure(trimmed, chain_name, list(chain))
    return trimmed.make_mmcif_document().as_string()


def _clip_to_residues(
    start: gemmi.AtomAddress,
    end: gemmi.AtomAddress,
    chain_name: str,
    residues: list[gemmi.Residue],
) -> bool:
    """Moves the range ends onto the first/last kept residue inside it; False if none is."""
    if start.chain_name != chain_name:
        return False
    lo, hi = start.res_id.seqid, end.res_id.seqid
    inside = [r for r in residues if not (r.seqid < lo) and not (hi < r.seqid)]
    if not inside:
        return False
    start.res_id = inside[0]
    end.res_id = inside[-1]
    return True


def _clip_secondary_structure(
    st: gemmi.Structure, chain_name: str, residues: list[gemmi.Residue]
) -> None:
    # gemmi drops a helix or strand whose first or last residue was trimmed away, which
    # would turn e.g. a helix starting just before the window into loop.
    for i in reversed(range(len(st.helices))):
        helix = st.helices[i]
        if not _clip_to_residues(helix.start, helix.end, chain_name, residues):
            del st.helices[i]
    for s in reversed(range(len(st.sheets))):
        strands = st.sheets[s].strands
        for i in reversed(range(len(strands))):
            if not _clip_to_residues(strands[i].start, strands[i].end, chain_name, residues):
                del strands[i]
        if len(strands) == 0:
            del st.sheets[s]


def _extract_window(
    pdb_id: str,
    st: gemmi.Structure,
    chain_name: str,
    window: list[gemmi.Residue],
    start_position: int,
) -> ExtractedStructure:
    residues = []
    for i, residue in enumerate(window):
        if not _has_ca(residue):
            # Still drawn if it has other atoms, but not selectable from the sequence panel.
            logger.warning(
                "%s: polymer residue %s %d has no resolved CA; not mapping it",
                pdb_id,
                residue.name,
                residue.seqid.num,
            )
            continue
        if residue.seqid.num is None:
            continue
        residues.append(
            ResidueMapping(
                position=start_position + i,
                chain_id=residue.subchain,
                auth_seq_id=residue.seqid.num,
                insertion_code=residue.seqid.icode.strip(),
            )
        )
    return ExtractedStructure(
        pdb_id=pdb_id, cif=_trimmed_cif(st, chain_name, window), residues=residues
    )


# Parses structure, checks if wildtype seq is substring of sequence with coordinates or the other way around. returns whichever is shorter
def extract_structure(
    pdb_id: str, cif_text: str, wildtype_sequence: str
) -> ExtractedStructure | None:
    try:
        st = gemmi.read_structure_string(cif_text)
        st.setup_entities()
        st.remove_alternative_conformations()
    except RuntimeError as e:
        logger.error("%s: failed to parse mmCIF: %s", pdb_id, e)
        return None

    if len(st) == 0:
        logger.error("%s: mmCIF has no models", pdb_id)
        return None

    for chain in st[0]:
        polymer = list(chain.get_polymer())
        if not polymer:
            continue
        observed_sequence = _polymer_sequence(polymer)

        offset = observed_sequence.find(wildtype_sequence)
        if offset != -1:
            logger.info(
                "%s: chain %s covers wildtype_sequence at offset %d",
                pdb_id,
                chain.name,
                offset,
            )
            window = polymer[offset : offset + len(wildtype_sequence)]
            return _extract_window(pdb_id, st, chain.name, window, start_position=1)

        offset = wildtype_sequence.find(observed_sequence)
        if offset != -1:
            logger.info(
                "%s: chain %s is a %d-residue subset of wildtype_sequence starting at position %d",
                pdb_id,
                chain.name,
                len(polymer),
                offset + 1,
            )
            return _extract_window(
                pdb_id, st, chain.name, polymer, start_position=offset + 1
            )

    logger.warning(
        "%s: wildtype_sequence does not match any chain's observed sequence; excluding...",
        pdb_id,
    )
    return None


def _cache_path(cache_dir: Path, pdb_id: str) -> Path:
    # The raw download is cached, so changes to extraction never require refetching.
    return cache_dir / f"{pdb_id}.cif"


def load_and_validate_structures(
    proteins: dict[str, Protein], cache_dir: Path
) -> dict[str, ExtractedStructure]:
    cache_dir.mkdir(parents=True, exist_ok=True)
    structures: dict[str, ExtractedStructure] = {}

    for pdb_id, protein in proteins.items():
        cache_file = _cache_path(cache_dir, pdb_id)
        if cache_file.exists():
            cif_text = cache_file.read_text()
        else:
            cif_text = _fetch_cif_text(pdb_id)
            if cif_text is None:
                continue
            cache_file.write_text(cif_text)

        structure = extract_structure(pdb_id, cif_text, protein.wildtype_sequence)
        if structure is None:
            continue
        structures[pdb_id] = structure

    logger.info(
        "Validated structures for %d/%d proteins", len(structures), len(proteins)
    )
    return structures
