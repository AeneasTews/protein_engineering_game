import asyncio
import json
import logging.handlers
import os
import sqlite3
import sys
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager, suppress
from pathlib import Path
from typing import Optional

from data.loader import (
    NORMALIZED_TARGET,
    Protein,
    get_score,
    load_proteins_from_directory,
)
from data.structure_loader import ExtractedStructure, load_and_validate_structures
from db.db import (
    add_trajectory,
    get_highscore_db,
    get_highscores_db,
    get_leaderboard as get_leaderboard_db,
    get_new_session,
    get_session_info,
    get_trajectories,
    init_db,
    update_highscore_if_better,
)
from fastapi import FastAPI, Header, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from game import settings
from game.discovery import run_beacon
from game.matches import MatchManager
from game.players import NicknameTaken, PlayerRegistry
from models.schemas import *

DATA_PATH = Path(__file__).parent / "dms_data" / "thermo_data"
DB_PATH = Path(
    os.environ.get("DB_PATH", Path(__file__).parent / "db" / "database.sqlite3")
)
LOG_PATH = Path(__file__).parent / "logs"
STRUCTURE_CACHE_PATH = Path(__file__).parent / "db" / "structure_cache"
PROTEINS_DB: dict[str, Protein] = {}
STRUCTURES_DB: dict[str, ExtractedStructure] = {}
DB_CONNECTION: sqlite3.Connection
# Match state lives in memory, so the backend must run as a single process (one uvicorn worker).
PLAYER_REGISTRY = PlayerRegistry()
MATCH_MANAGER: MatchManager

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
ALLOWED_ORIGINS = (
    [o.strip() for o in _raw_origins.split(",")] if _raw_origins != "*" else ["*"]
)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    global PROTEINS_DB
    global STRUCTURES_DB
    global DB_CONNECTION
    global MATCH_MANAGER

    logger.info("Loading protein data from %s", DATA_PATH)
    proteins_db = load_proteins_from_directory(DATA_PATH)
    if proteins_db is None:
        logger.critical(
            "Failed to read proteins from data directory — aborting startup"
        )
        sys.exit(1)
    PROTEINS_DB = proteins_db
    logger.info("Loaded %d proteins", len(PROTEINS_DB))

    logger.info("Validating structures for %d proteins", len(PROTEINS_DB))
    STRUCTURES_DB = load_and_validate_structures(PROTEINS_DB, STRUCTURE_CACHE_PATH)
    PROTEINS_DB = {
        pdb_id: p for pdb_id, p in PROTEINS_DB.items() if pdb_id in STRUCTURES_DB
    }
    if not PROTEINS_DB:
        logger.critical("No proteins have a validated structure — aborting startup")
        sys.exit(1)
    logger.info("%d proteins have a validated structure", len(PROTEINS_DB))

    logger.info("Initializing database at %s", DB_PATH)
    db_connection = init_db(DB_PATH)
    if db_connection is None:
        logger.critical("Failed to initialize the database — aborting startup")
        sys.exit(1)
    DB_CONNECTION = db_connection
    logger.info("Database ready")

    MATCH_MANAGER = MatchManager(PLAYER_REGISTRY, DB_CONNECTION, PROTEINS_DB)
    beacon_task = asyncio.create_task(run_beacon()) if settings.BEACON_ENABLED else None

    yield

    if beacon_task is not None:
        beacon_task.cancel()
        with suppress(asyncio.CancelledError):
            await beacon_task
    await MATCH_MANAGER.shutdown()

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


@app.get("/proteins", response_model=list[ProteinBase], tags=["proteins"])
async def list_proteins():
    logger.debug("Listing %d proteins", len(PROTEINS_DB))
    return [
        ProteinBase(pdb_id=p.pdb_id, name=p.name, wildtype_sequence=p.wildtype_sequence)
        for p in PROTEINS_DB.values()
    ]


@app.get("/structure/{pdb_id}", response_model=StructureResponse, tags=["proteins"])
async def get_structure(pdb_id: str):
    logger.debug("Get structure pdb_id=%s", pdb_id)
    if pdb_id not in PROTEINS_DB:
        logger.warning("Get structure rejected: unknown pdb_id=%s", pdb_id)
        raise HTTPException(status_code=400, detail="Invalid protein id")
    structure = STRUCTURES_DB[pdb_id]
    return StructureResponse(
        pdb_id=structure.pdb_id,
        cif=structure.cif,
        residues=[
            ResidueMappingSchema(
                position=r.position,
                chain_id=r.chain_id,
                auth_seq_id=r.auth_seq_id,
                insertion_code=r.insertion_code,
            )
            for r in structure.residues
        ],
    )


@app.post("/evaluate", response_model=EvaluationResponse, tags=["sessions"])
async def evaluate_mutant(
    mutation_request: MutationRequest,
    x_player_token: Optional[str] = Header(default=None),
):
    logger.info(
        "Evaluate mutant session_id=%d pdb_id=%s mutant=%s",
        mutation_request.session_id,
        mutation_request.pdb_id,
        mutation_request.mutant,
    )
    session = get_session_info(
        session_id=mutation_request.session_id, connection=DB_CONNECTION
    )
    if session is None:
        logger.warning(
            "Evaluate rejected: unknown session_id=%d", mutation_request.session_id
        )
        raise HTTPException(status_code=400, detail="Invalid session_id")

    if session.pdb_id != mutation_request.pdb_id:
        logger.warning(
            "Evaluate rejected: pdb_id=%s does not match session_id=%d",
            mutation_request.pdb_id,
            session.session_id,
        )
        raise HTTPException(
            status_code=400, detail="pdb_id does not match the session's protein"
        )

    if session.match_id is not None:
        rejection = MATCH_MANAGER.check_can_evaluate(session, x_player_token)
        if rejection is not None:
            status_code, detail = rejection
            logger.warning(
                "Evaluate rejected: session_id=%d: %s", session.session_id, detail
            )
            raise HTTPException(status_code=status_code, detail=detail)

    if session.turn_count >= session.max_turns:
        logger.warning(
            "Evaluate rejected: session_id=%d has exhausted %d turns",
            session.session_id,
            session.max_turns,
        )
        raise HTTPException(
            status_code=400, detail="There are no rounds left for this session"
        )

    # No await between the turn check above and add_trajectory below: the single event
    # loop is what keeps two concurrent requests from spending the same turn.
    score = get_score(
        protein=PROTEINS_DB[mutation_request.pdb_id], mutant=mutation_request.mutant
    )
    score = score if score is not None else NORMALIZED_TARGET

    add_trajectory(
        session_id=mutation_request.session_id,
        mutant=mutation_request.mutant,
        score=score,
        connection=DB_CONNECTION,
    )
    trajectories = get_trajectories(
        session_id=mutation_request.session_id, connection=DB_CONNECTION
    )
    current_turn_count = max([t.turn_count for t in trajectories] + [0])

    if session.match_id is not None:
        # Match sessions update the highscore when the match finishes, however it ends.
        await MATCH_MANAGER.on_evaluation(
            session, mutation_request.mutant, score, current_turn_count
        )
    elif current_turn_count == session.max_turns:
        update_highscore_if_better(
            connection=DB_CONNECTION,
            session_id=session.session_id,
            pdb_id=session.pdb_id,
        )

    return EvaluationResponse(
        session_id=mutation_request.session_id,
        pdb_id=mutation_request.pdb_id,
        mutant=mutation_request.mutant,
        score=score,
        turn_count=current_turn_count,
        max_turns=session.max_turns,
        history=[
            TrajectoryStepBase(mutant=t.mutant, score=t.score, turn_count=t.turn_count)
            for t in trajectories
        ],
    )


@app.post("/session", response_model=SessionResponse, tags=["sessions"])
async def create_session(session_create: SessionCreate):
    logger.info(
        "Create session username=%r pdb_id=%s",
        session_create.username,
        session_create.pdb_id,
    )
    if session_create.username == "":
        logger.warning("Create session rejected: empty username")
        raise HTTPException(status_code=400, detail="Invalid username")
    if session_create.pdb_id not in PROTEINS_DB:
        logger.warning(
            "Create session rejected: unknown pdb_id=%s", session_create.pdb_id
        )
        raise HTTPException(status_code=400, detail="Invalid protein id")

    session_id = get_new_session(
        username=session_create.username,
        pdb_id=session_create.pdb_id,
        connection=DB_CONNECTION,
    )
    logger.info(
        "Created session_id=%d for username=%r pdb_id=%s",
        session_id,
        session_create.username,
        session_create.pdb_id,
    )
    return SessionResponse(session_id=session_id)


@app.post("/highscore", response_model=HighScoreResponse, tags=["sessions"])
async def get_highscore(highscore_request: HighScoreRequest):
    logger.debug("Get highscore pdb_id=%s", highscore_request.pdb_id)
    if highscore_request.pdb_id not in PROTEINS_DB:
        logger.warning(
            "Get highscore rejected: unknown pdb_id=%s", highscore_request.pdb_id
        )
        raise HTTPException(status_code=400, detail="Invalid protein id")
    highscore = get_highscore_db(DB_CONNECTION, highscore_request.pdb_id)
    return HighScoreResponse(username=highscore.username, score=highscore.score)


@app.post("/highscores", response_model=HighScoresResponse, tags=["sessions"])
async def get_highscores(highscores_request: HighScoresRequest):
    logger.debug("Get highscores for a pdb_ids=%s", highscores_request.pdb_ids)
    if any(pdb_id not in PROTEINS_DB for pdb_id in highscores_request.pdb_ids):
        logger.warning("Get highscores rejected: unknown pdb ids in request")
        raise HTTPException(status_code=400, detail="Invalid protein id")
    highscores = get_highscores_db(DB_CONNECTION, highscores_request.pdb_ids)
    return HighScoresResponse(highscores=highscores)


@app.post("/players", response_model=PlayerResponse, tags=["multiplayer"])
async def register_player(player_create: PlayerCreate):
    nickname = player_create.nickname.strip()
    if not nickname or len(nickname) > settings.MAX_NICKNAME_LENGTH:
        logger.warning("Register player rejected: invalid nickname %r", nickname)
        raise HTTPException(
            status_code=400,
            detail=f"Nickname must be 1-{settings.MAX_NICKNAME_LENGTH} characters",
        )
    try:
        player = PLAYER_REGISTRY.register(nickname)
    except NicknameTaken:
        logger.warning("Register player rejected: nickname %r is online", nickname)
        raise HTTPException(status_code=409, detail="That nickname is already online")
    return PlayerResponse(
        player_id=player.player_id, nickname=player.nickname, token=player.token
    )


@app.get(
    "/leaderboard", response_model=list[LeaderboardEntrySchema], tags=["multiplayer"]
)
async def get_leaderboard():
    return [
        LeaderboardEntrySchema(
            nickname=e.nickname, wins=e.wins, losses=e.losses, draws=e.draws
        )
        for e in get_leaderboard_db(DB_CONNECTION)
    ]


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str = ""):
    player = PLAYER_REGISTRY.by_token(token)
    if player is None:
        await websocket.close(code=4401, reason="Unknown token; register via /players")
        return

    await websocket.accept()
    await MATCH_MANAGER.connect(player, websocket)
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                await player.send({"type": "error", "message": "Invalid JSON"})
                continue
            if not isinstance(message, dict):
                await player.send({"type": "error", "message": "Expected a JSON object"})
                continue
            await MATCH_MANAGER.handle(player, message)
    except WebSocketDisconnect:
        pass
    finally:
        await MATCH_MANAGER.disconnect(player, websocket)


# Optionally serve the Flutter web build (MUTATEIT_WEB_DIR, e.g. ../app/build/web) so players can
# join from a browser at this server's address. Mounted last, so the API routes above take precedence.
WEB_DIR = os.environ.get("MUTATEIT_WEB_DIR")
if WEB_DIR:
    logger.info("Serving the web app from %s", WEB_DIR)
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")
