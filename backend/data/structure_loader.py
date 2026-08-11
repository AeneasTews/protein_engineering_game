from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

import gemmi
from data.loader import Protein

logger = logging.getLogger(__name__)

RCSB_CIF_URL = "https://files.rcsb.org/download/{pdb_id}.cif"
FETCH_TIMEOUT_SECONDS = 30


@dataclass
class ExtractedAtom:
    element: str
    atom_name: str
    x: float
    y: float
    z: float

    def to_json(self) -> dict:
        return {
            "element": self.element,
            "atom_name": self.atom_name,
            "x": self.x,
            "y": self.y,
            "z": self.z,
        }


class SecondaryStructure(Enum):
    LOOP = "loop"
    HELIX = "helix"
    SHEET = "sheet"


@dataclass
class ExtractedResidue:
    position: int  # 1-based, matches wildtype_sequence[position - 1]
    name: str  # 3-letter
    secondary_structure: SecondaryStructure
    atoms: list[ExtractedAtom]

    def to_json(self) -> dict:
        return {
            "position": self.position,
            "name": self.name,
            "secondary_structure": self.secondary_structure.value,
            "atoms": [a.to_json() for a in self.atoms],
        }


@dataclass
class ExtractedStructure:
    pdb_id: str
    residues: list[ExtractedResidue]

    def to_json(self) -> dict:
        return {"pdb_id": self.pdb_id, "residues": [r.to_json() for r in self.residues]}

    @staticmethod
    def from_json(data: dict) -> ExtractedStructure:
        return ExtractedStructure(
            pdb_id=data["pdb_id"],
            residues=[
                ExtractedResidue(
                    position=r["position"],
                    name=r["name"],
                    secondary_structure=SecondaryStructure(r["secondary_structure"]),
                    atoms=[ExtractedAtom(**a) for a in r["atoms"]],
                )
                for r in data["residues"]
            ],
        )


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


def _primary_ca(residue: gemmi.Residue) -> gemmi.Atom | None:
    for atom in residue:
        if atom.name == "CA":
            return atom
    return None


def _secondary_structure_at(
    st: gemmi.Structure, chain_name: str, seq_num: int
) -> SecondaryStructure:
    for helix in st.helices:
        if (
            helix.start.chain_name == chain_name
            and helix.start.res_id.seqid.num is not None
            and helix.end.res_id.seqid.num is not None
            and helix.start.res_id.seqid.num <= seq_num <= helix.end.res_id.seqid.num
        ):
            return SecondaryStructure.HELIX
    for sheet in st.sheets:
        for strand in sheet.strands:
            if (
                strand.start.chain_name == chain_name
                and strand.start.res_id.seqid.num is not None
                and strand.end.res_id.seqid.num is not None
                and strand.start.res_id.seqid.num
                <= seq_num
                <= strand.end.res_id.seqid.num
            ):
                return SecondaryStructure.SHEET
    return SecondaryStructure.LOOP


def _extract_window(
    pdb_id: str,
    st: gemmi.Structure,
    chain_name: str,
    window: list[gemmi.Residue],
    start_position: int,
) -> ExtractedStructure:
    residues = []
    for i, residue in enumerate(window):
        ca = _primary_ca(residue)
        if ca is None:
            # some can exist without CA, instead of skipping entire structure, just skip one
            logger.warning(
                "%s: polymer residue %s %d has no resolved CA; skipping",
                pdb_id,
                residue.name,
                residue.seqid.num,
            )
            continue

        if residue.seqid.num is None:
            continue

        residues.append(
            ExtractedResidue(
                position=start_position + i,
                name=residue.name,
                secondary_structure=_secondary_structure_at(
                    st, chain_name, residue.seqid.num
                ),
                atoms=[
                    ExtractedAtom(
                        element=ca.element.name,
                        atom_name=ca.name,
                        x=ca.pos.x,
                        y=ca.pos.y,
                        z=ca.pos.z,
                    )
                ],
            )
        )
    return ExtractedStructure(pdb_id=pdb_id, residues=residues)


def extract_structure(
    pdb_id: str, cif_text: str, wildtype_sequence: str
) -> ExtractedStructure | None:
    """
    Parses structure, checks if wildtype seq is substring of sequence with coordinates or the other way around. returns whichever is shorter
    """
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
    return cache_dir / f"{pdb_id}.json"


def load_and_validate_structures(
    proteins: dict[str, Protein], cache_dir: Path
) -> dict[str, ExtractedStructure]:
    cache_dir.mkdir(parents=True, exist_ok=True)
    structures: dict[str, ExtractedStructure] = {}

    for pdb_id, protein in proteins.items():
        cache_file = _cache_path(cache_dir, pdb_id)

        if cache_file.exists():
            try:
                structures[pdb_id] = ExtractedStructure.from_json(
                    json.loads(cache_file.read_text())
                )
                continue
            except (json.JSONDecodeError, KeyError, ValueError, TypeError) as e:
                logger.warning(
                    "%s: failed to read cached structure (%s); refetching...", pdb_id, e
                )

        cif_text = _fetch_cif_text(pdb_id)
        if cif_text is None:
            continue

        structure = extract_structure(pdb_id, cif_text, protein.wildtype_sequence)
        if structure is None:
            continue

        structures[pdb_id] = structure
        cache_file.write_text(json.dumps(structure.to_json()))

    logger.info(
        "Validated structures for %d/%d proteins", len(structures), len(proteins)
    )
    return structures
