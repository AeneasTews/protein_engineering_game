from dataclasses import dataclass, field
import re
import pandas as pd
import logging
from pathlib import Path
from typing import Optional, List, Tuple, Dict


logger = logging.getLogger(__name__)


REQUIRED_COLUMNS = {"mutant", "mutated_sequence", "DMS_score"}


@dataclass
class Protein:
    pdb_id: str
    name: str
    wildtype_sequence: str
    mutants: dict = field(default_factory=dict)


# parses filename, example: TCRG1_MOUSE_Tsuboyama_2023_1E0L.csv --> organism: TCRG1_MOUSE, PDB: 1E0L
def parse_filename(filename: str) -> Optional[Tuple[str, str]]:
    PATTERN = re.compile(r"^(.+?)_Tsuboyama_2023_([A-Z0-9]{4}).csv$")
    match = PATTERN.match(filename)
    if not match:
        return None

    name = match.group(1)
    pdb_id = match.group(2)
    return name, pdb_id


def _parse_mutation_entry(mutation: str) -> Optional[List[Tuple[int, str, str]]]:
    output = []
    PATTERN = re.compile("^([A-Z])([0-9]+)([A-Z])$")
    for m in mutation.split(":"):
        match = PATTERN.match(m)
        if not match:
            return None

        output.append((int(match.group(2)), match.group(1), match.group(3)))

    return output


def _build_mutation_key(mutants: list[tuple[int, str, str]]) -> str:
    mutants.sort(key=lambda mutant: mutant[0])
    return ":".join([f"{mutant[1]}{mutant[0]}{mutant[2]}" for mutant in mutants])
    

def _build_wildtype(df: pd.DataFrame) -> Optional[str]:
    entry = df.iloc[0]
    mutants = _parse_mutation_entry(entry["mutant"])
    if mutants is None:
        return None

    wildtype_sequence = entry["mutated_sequence"]
    for mutant in mutants:
        wildtype_sequence = wildtype_sequence[0:mutant[0] - 1] + mutant[1] + wildtype_sequence[mutant[0]:] # convert 1-based indexing

    return wildtype_sequence


def _parse_mutants(df: pd.DataFrame) -> Optional[Dict[str, Tuple[float, List[Tuple[int, str, str]]]]]:
    output = {"": (1.0, [(0, "", "")])}
    for i, row in df.iterrows():
        mutants = _parse_mutation_entry(str(row["mutant"]))
        if mutants is None:
            return None

        mutant_key = _build_mutation_key(mutants)
        if mutant_key is None:
            return None

        output[mutant_key] = (row["DMS_score"], mutants)

    return output


def load_protein_from_csv(path: Path) -> Optional[Protein]:
    try:
        out = parse_filename(path.name)
        if out is None:
            raise Exception("Unable to parse filename")
        name, pdb_id = out
        df = pd.read_csv(path)
    except Exception as e:
        print(e)
        logger.error(f"An error occurred whilst trying to parse: {path}")
        return None

    missing_columns = REQUIRED_COLUMNS - set(df.columns)
    if missing_columns:
        logger.error(f"Columns: {missing_columns} are missing from {path}; Unable to load")
        return None

    df = df.dropna(subset=list(REQUIRED_COLUMNS))
    if df.empty:
        logger.error(f"No valid columns after dropping nulls whilst trying to load {path}")
        return None

    wildtype_sequence = _build_wildtype(df)
    if wildtype_sequence is None:
        logger.error(f"Failed to build wildtype sequence for {path}")
        return None

    mutants = _parse_mutants(df)
    if mutants is None:
        logger.error(f"An error occurred whilst trying to parse mutants of {path}")
        return None

    return Protein(pdb_id, name, wildtype_sequence, mutants)


def load_proteins_from_directory(path: Path) -> Optional[Dict[str, Protein]]:
    try:
        files = [f for f in path.glob("**/*.csv") if f.is_file()]
    except Exception as e:
        logger.error("Error ocurred whilst trying to find files")
        return None

    proteins = {}
    for file in files:
        protein = load_protein_from_csv(file)
        if protein is None:
            continue
        proteins[protein.pdb_id] = protein

    return proteins


def get_score(protein: Protein, mutant: str) -> Optional[float]:
    mutant = _parse_mutation_entry(mutant)
    if mutant is None:
        return None
    mutant_key = _build_mutation_key(mutant)
    if mutant_key in protein.mutants:
        return protein.mutants[mutant_key][0]

    return None


#print(load_proteins_from_directory(Path("/home/aeneastews/work/hiwi_rostlab/learn_flutter/protein_engineering_game/backend/dms_data/thermo_data/")))