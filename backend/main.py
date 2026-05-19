from fastapi import FastAPI, HTTPException
from typing import List, Dict, AsyncIterator
import sqlite3
from pathlib import Path
import logging
from contextlib import asynccontextmanager

from models.schemas import *
from data.loader import load_proteins_from_directory, get_score, Protein
from db.db import (
    Highscore,
    init_db,
    get_new_session,
    get_highscore_db,
    get_current_turn_count,
    get_best_session_score,
    set_highscore_db,
    add_trajectory,
    get_trajectories
)

DATA_PATH = Path(__file__).parent / "dms_data" / "thermo_data"
DB_PATH = Path(__file__).parent / "db" / "database.sqlite3"
PROTEINS_DB: Dict[str, Protein] = {}
DB_CONNECTION: sqlite3.Connection
logger = logging.getLogger(__name__)
MAX_TURN_COUNT = 20

@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    global PROTEINS_DB
    global DB_CONNECTION
    print("Loading Protein Data...")
    PROTEINS_DB = load_proteins_from_directory(DATA_PATH)
    if PROTEINS_DB is None:
        logger.error("Failed to read proteins from data directory")
        exit(1)
    print("Complete!")
    print("Loading Database...")
    DB_CONNECTION = init_db(DB_PATH)
    if DB_CONNECTION is None:
        logger.error("Failed to initialize the database")
        exit(1)
    print("Complete!")
    yield
    print("Closing Database...")
    DB_CONNECTION.close()
    print("Complete!")

app = FastAPI(title="Protein Engineering Game API", description="Protein Engineering Game API", version="0.0.1", lifespan=lifespan)


@app.get("/proteins", response_model=List[ProteinBase], tags=["proteins"])
async def list_proteins():
    logger.log(level=logging.DEBUG, msg="Listing Proteins")
    return [ProteinBase(pdb_id=protein.pdb_id, name=protein.name, wildtype_sequence=protein.wildtype_sequence) for protein in PROTEINS_DB.values()]

@app.post("/evaluate", response_model=EvaluationResponse, tags=["sessions"])
async def evaluate_mutant(mutation_request: MutationRequest):
    logger.log(level=logging.INFO, msg=f"Evaluating Mutant: {mutation_request}")
    current_turn_count = get_current_turn_count(session_id=mutation_request.session_id, connection=DB_CONNECTION)
    if current_turn_count is None:
        raise HTTPException(status_code=400, detail="Invalid session_id")

    if current_turn_count >= MAX_TURN_COUNT:
        raise HTTPException(status_code=400, detail="There are no rounds left for this session")

    # single step logic
    score = get_score(protein=PROTEINS_DB[mutation_request.pdb_id], mutant=mutation_request.mutant)
    score = score if score is not None else 1.0 # TODO: data augmentation in case of missing data

    add_trajectory(session_id=mutation_request.session_id, mutant=mutation_request.mutant, score=score, connection=DB_CONNECTION)
    trajectories = get_trajectories(session_id=mutation_request.session_id, connection=DB_CONNECTION)
    current_turn_count = max([trajectory.turn_count for trajectory in trajectories] + [0]) # while slow, gives me peace of mind that I am using up-to date data

    # final round logic
    if current_turn_count == MAX_TURN_COUNT:
        highscore = get_highscore_db(connection=DB_CONNECTION)
        if highscore is None:
            highscore = 0
        best_session_score = get_best_session_score(session_id=mutation_request.session_id, connection=DB_CONNECTION)
        if best_session_score is None:
            best_session_score = 0
        if highscore.score < best_session_score:
            set_highscore_db(session_id=mutation_request.session_id, score=best_session_score, connection=DB_CONNECTION)

    return EvaluationResponse(
        session_id=mutation_request.session_id,
        pdb_id=mutation_request.pdb_id,
        mutant=mutation_request.mutant,
        score=score,
        turn_count=current_turn_count,
        history=[TrajectoryStepBase(mutant=trajectory.mutant, score=trajectory.score, turn_count=trajectory.turn_count) for trajectory in trajectories]
    )

@app.post("/session", response_model=SessionResponse, tags=["sessions"])
async def create_session(session_create: SessionCreate):
    logger.log(level=logging.INFO, msg=f"Creating Session: {session_create}")
    if session_create.username == "":
        raise HTTPException(status_code=400, detail="Invalid username")
    if session_create.pdb_id not in PROTEINS_DB:
        raise HTTPException(status_code=400, detail="Invalid protein id")

    session_id = get_new_session(username=session_create.username, pdb_id=session_create.pdb_id, connection=DB_CONNECTION)
    return SessionResponse(session_id=session_id)

@app.get("/highscore", response_model=HighScoreResponse, tags=["sessions"])
async def get_highscore():
    logger.log(level=logging.DEBUG, msg=f"Getting Highscore")
    highscore = get_highscore_db(DB_CONNECTION)
    if highscore is None:
        raise HTTPException(status_code=404, detail="Highscore not found")

    return HighScoreResponse(username=highscore.username, score=highscore.score)
