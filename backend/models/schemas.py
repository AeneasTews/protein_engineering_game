from db.db import Highscore
from pydantic import BaseModel, Field


class TrajectoryStepBase(BaseModel):
    mutant: str
    score: float
    turn_count: int


class ProteinBase(BaseModel):
    pdb_id: str = Field(..., description="4-character PDB ID", examples=["1E0L"])
    name: str = Field(
        ...,
        description="Name identifying the protein in a specific organism",
        examples=["TCRG1_MOUSE"],
    )
    wildtype_sequence: str = Field(..., description="Wildtype amino acid sequence")


class MutationRequest(BaseModel):
    session_id: int = Field(..., description="Session id")
    pdb_id: str = Field(..., description="4-character PDB ID", examples=["1E0L"])
    mutant: str = Field(
        ...,
        description="Mutation key identifying the specific mutations",
        examples=["A72C", "T53A:G8A"],
    )


class EvaluationResponse(BaseModel):
    session_id: int = Field(..., description="Session id")
    pdb_id: str = Field(..., description="4-character PDB ID", examples=["1E0L"])
    mutant: str = Field(
        ...,
        description="Mutation key identifying the specific mutations",
        examples=["A72C", "T53A:G8A"],
    )
    score: float = Field(..., description="Score of the mutant")
    turn_count: int = Field(..., description="Current turn count [1 - 20]")
    history: list[TrajectoryStepBase] = Field(..., description="History of the session")


class SessionCreate(BaseModel):
    username: str = Field(..., description="Username")
    pdb_id: str = Field(..., description="Selected protein pdb-id", examples=["1E0L"])


class SessionResponse(BaseModel):
    session_id: int = Field(..., description="Session id")


class HighScoreRequest(BaseModel):
    pdb_id: str = Field(
        ...,
        description="pdb id of structure for which the highscore should be returned",
    )


class HighScoreResponse(BaseModel):
    username: str = Field(..., description="Username")
    score: float = Field(..., description="Score of the high score")


class HighScoresRequest(BaseModel):
    pdb_ids: list[str] = Field(
        ..., description="List of pdb ids to request highscores for"
    )


class HighScoresResponse(BaseModel):
    highscores: dict[str, Highscore] = Field(
        ..., description="Dictionary of pdb ids: (username, score)"
    )


class AtomSchema(BaseModel):
    element: str = Field(..., description="Element symbol; 'C'")
    atom_name: str = Field(..., description="Atom name within the residue; 'CA'")
    x: float
    y: float
    z: float


class ResidueSchema(BaseModel):
    position: int = Field(
        ..., description="1-based position, matches wildtype_sequence[position - 1]"
    )
    name: str = Field(..., description="3-letter residue name")
    secondary_structure: str = Field(..., description="'loop', 'helix', 'sheet'")
    atom: AtomSchema = Field(..., description="The residue's CA")


class StructureResponse(BaseModel):
    pdb_id: str = Field(..., description="4-character PDB ID", examples=["1E0L"])
    residues: list[ResidueSchema]
