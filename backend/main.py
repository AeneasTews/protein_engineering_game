import logging.handlers
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator, Dict
import sqlite3
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from data.loader import NORMALIZED_TARGET, Protein, get_score, load_proteins_from_directory
from db.db import (
    add_trajectory,
    get_best_session_score,
    get_current_turn_count,
    get_highscore_db,
    get_new_session,
    get_trajectories,
    init_db,
    set_highscore_db,
    get_highscores_db
)
from models.schemas import *

DATA_PATH = Path(__file__).parent / "dms_data" / "thermo_data"
DB_PATH = Path(os.environ.get("DB_PATH", Path(__file__).parent / "db" / "database.sqlite3"))
LOG_PATH = Path(__file__).parent / "logs"
PROTEINS_DB: Dict[str, Protein] = {}
DB_CONNECTION: sqlite3.Connection
MAX_TURN_COUNT = 20

LOG_PATH.mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.handlers.RotatingFileHandler(
            LOG_PATH / "backend.log",
            maxBytes=10 * 1024 * 1024,
            backupCount=5,
            encoding="utf-8",
        ),
        logging.StreamHandler(),
    ],
)

logger = logging.getLogger(__name__)

_raw_origins = os.environ.get("ALLOWED_ORIGINS", "*")
ALLOWED_ORIGINS = [o.strip() for o in _raw_origins.split(",")] if _raw_origins != "*" else ["*"]


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    global PROTEINS_DB
    global DB_CONNECTION

    logger.info("Loading protein data from %s", DATA_PATH)
    PROTEINS_DB = load_proteins_from_directory(DATA_PATH)
    if PROTEINS_DB is None:
        logger.critical("Failed to read proteins from data directory — aborting startup")
        exit(1)
    logger.info("Loaded %d proteins", len(PROTEINS_DB))

    logger.info("Initializing database at %s", DB_PATH)
    DB_CONNECTION = init_db(DB_PATH)
    if DB_CONNECTION is None:
        logger.critical("Failed to initialize the database — aborting startup")
        exit(1)
    logger.info("Database ready")

    yield

    logger.info("Closing database connection")
    DB_CONNECTION.close()
    logger.info("Shutdown complete")


app = FastAPI(
    title="Protein Engineering Game API",
    description="Protein Engineering Game API",
    version="0.0.1",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/proteins", response_model=List[ProteinBase], tags=["proteins"])
async def list_proteins():
    logger.debug("Listing %d proteins", len(PROTEINS_DB))
    return [
        ProteinBase(pdb_id=p.pdb_id, name=p.name, wildtype_sequence=p.wildtype_sequence)
        for p in PROTEINS_DB.values()
    ]


@app.post("/evaluate", response_model=EvaluationResponse, tags=["sessions"])
async def evaluate_mutant(mutation_request: MutationRequest):
    logger.info(
        "Evaluate mutant session_id=%d pdb_id=%s mutant=%s",
        mutation_request.session_id,
        mutation_request.pdb_id,
        mutation_request.mutant,
    )
    current_turn_count = get_current_turn_count(
        session_id=mutation_request.session_id, connection=DB_CONNECTION
    )
    if current_turn_count is None:
        logger.warning("Evaluate rejected: unknown session_id=%d", mutation_request.session_id)
        raise HTTPException(status_code=400, detail="Invalid session_id")

    if current_turn_count >= MAX_TURN_COUNT:
        logger.warning(
            "Evaluate rejected: session_id=%d has exhausted %d turns",
            mutation_request.session_id,
            MAX_TURN_COUNT,
        )
        raise HTTPException(status_code=400, detail="There are no rounds left for this session")

    score = get_score(protein=PROTEINS_DB[mutation_request.pdb_id], mutant=mutation_request.mutant)
    score = score if score is not None else NORMALIZED_TARGET

    add_trajectory(
        session_id=mutation_request.session_id,
        mutant=mutation_request.mutant,
        score=score,
        connection=DB_CONNECTION,
    )
    trajectories = get_trajectories(session_id=mutation_request.session_id, connection=DB_CONNECTION)
    current_turn_count = max([t.turn_count for t in trajectories] + [0])

    if current_turn_count == MAX_TURN_COUNT:
        highscore = get_highscore_db(connection=DB_CONNECTION, pdb_id=mutation_request.pdb_id)
        best_session_score = get_best_session_score(
            session_id=mutation_request.session_id, connection=DB_CONNECTION
        )
        if best_session_score is None:
            best_session_score = 0
        if highscore.score < best_session_score:
            logger.info(
                "New highscore for pdb_id=%s: %.4f (session_id=%d)",
                mutation_request.pdb_id,
                best_session_score,
                mutation_request.session_id,
            )
            set_highscore_db(
                session_id=mutation_request.session_id,
                score=best_session_score,
                pdb_id=mutation_request.pdb_id,
                connection=DB_CONNECTION,
            )

    return EvaluationResponse(
        session_id=mutation_request.session_id,
        pdb_id=mutation_request.pdb_id,
        mutant=mutation_request.mutant,
        score=score,
        turn_count=current_turn_count,
        history=[
            TrajectoryStepBase(mutant=t.mutant, score=t.score, turn_count=t.turn_count)
            for t in trajectories
        ],
    )


@app.post("/session", response_model=SessionResponse, tags=["sessions"])
async def create_session(session_create: SessionCreate):
    logger.info("Create session username=%r pdb_id=%s", session_create.username, session_create.pdb_id)
    if session_create.username == "":
        logger.warning("Create session rejected: empty username")
        raise HTTPException(status_code=400, detail="Invalid username")
    if session_create.pdb_id not in PROTEINS_DB:
        logger.warning("Create session rejected: unknown pdb_id=%s", session_create.pdb_id)
        raise HTTPException(status_code=400, detail="Invalid protein id")

    session_id = get_new_session(
        username=session_create.username,
        pdb_id=session_create.pdb_id,
        connection=DB_CONNECTION,
    )
    logger.info("Created session_id=%d for username=%r pdb_id=%s", session_id, session_create.username, session_create.pdb_id)
    return SessionResponse(session_id=session_id)


@app.post("/highscore", response_model=HighScoreResponse, tags=["sessions"])
async def get_highscore(highscore_request: HighScoreRequest):
    logger.debug("Get highscore pdb_id=%s", highscore_request.pdb_id)
    if highscore_request.pdb_id not in PROTEINS_DB:
        logger.warning("Get highscore rejected: unknown pdb_id=%s", highscore_request.pdb_id)
        raise HTTPException(status_code=400, detail="Invalid protein id")
    highscore = get_highscore_db(DB_CONNECTION, highscore_request.pdb_id)
    return HighScoreResponse(username=highscore.username, score=highscore.score)


@app.post("/highscores", response_model=HighScoresResponse, tags=["sessions"])
async def get_highscores(highscores_request: HighScoresRequest):
    logger.debug("Get highscores for a pdb_ids=%s", highscores_request.pdb_ids)
    if any([pdb_id not in PROTEINS_DB for pdb_id in highscores_request.pdb_ids]):
        logger.warning("Get highscores rejected: unknown pdb ids in request")
        raise HTTPException(status_code=400, detail="Invalid protein id")
    highscores = get_highscores_db(DB_CONNECTION, highscores_request.pdb_ids)
    return HighScoresResponse(highscores=highscores)
