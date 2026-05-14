from pydantic import BaseModel, Field
from typing import List, Tuple


class TrajectoryStepBase(BaseModel):
    mutant: str
    score: float
    turn_count: int


class ProteinBase(BaseModel):
    pdb_id: str = Field(..., description="4-character PDB ID", examples=["1E0L"])
    name: str = Field(..., description="Name identifying the protein in a specific organism", examples=["TCRG1_MOUSE"])
    wildtype_sequence: str = Field(..., description="Wildtype amino acid sequence")


class MutationRequest(BaseModel):
    session_id: int = Field(..., description="Session id")
    pdb_id: str = Field(..., description="4-character PDB ID", examples=["1E0L"])
    mutant: str = Field(..., description="Mutation key identifying the specific mutations", examples=["A72C", "T53A:G8A"])


class EvaluationResponse(BaseModel):
    session_id: int = Field(..., description="Session id")
    pdb_id: str = Field(..., description="4-character PDB ID", examples=["1E0L"])
    mutant: str = Field(..., description="Mutation key identifying the specific mutations", examples=["A72C", "T53A:G8A"])
    score: float = Field(..., description="Score of the mutant")
    turn_count: int = Field(..., description="Current turn count [1 - 20]")
    history: List[TrajectoryStepBase] = Field(..., description="History of the session")


class SessionCreate(BaseModel):
    username: str = Field(..., description="Username")
    pdb_id: str = Field(..., description="Selected protein pdb-id", examples=["1E0L"])


class SessionResponse(BaseModel):
    session_id: int = Field(..., description="Session id")


class HighScoreResponse(BaseModel):
    username: str = Field(..., description="Username")
    score: float = Field(..., description="Score of the high score")