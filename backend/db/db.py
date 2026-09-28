import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Dict
import logging


logger = logging.getLogger(__name__)


@dataclass
class Session:
    session_id: int
    turn_count: int


@dataclass
class TrajectoryStep:
    mutant: str
    score: float
    turn_count: int


@dataclass
class Highscore:
    username: str
    score: float


@dataclass
class SessionInfo:
    session_id: int
    username: str
    pdb_id: str
    turn_count: int
    max_turns: int
    match_id: Optional[int]


@dataclass
class LeaderboardEntry:
    nickname: str
    wins: int
    losses: int
    draws: int


DEFAULT_MAX_TURNS = 20


def _add_column_if_missing(cur: sqlite3.Cursor, table: str, column: str, definition: str) -> None:
    columns = {row[1] for row in cur.execute(f"PRAGMA table_info({table});").fetchall()}
    if column not in columns:
        cur.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition};")


def init_db(path: Path) -> Optional[sqlite3.Connection]:
    try:
        connection = sqlite3.connect(str(path))
        cur = connection.cursor()
        cur.execute(f"""
        CREATE TABLE IF NOT EXISTS sessions (
            session_id INTEGER PRIMARY KEY,
            username TEXT NOT NULL,
            turn_count INTEGER NOT NULL,
            pdb_id TEXT NOT NULL,
            max_turns INTEGER NOT NULL DEFAULT {DEFAULT_MAX_TURNS},
            match_id INTEGER
        );
        """)
        # Databases created before multiplayer lack these columns.
        _add_column_if_missing(cur, "sessions", "max_turns", f"INTEGER NOT NULL DEFAULT {DEFAULT_MAX_TURNS}")
        _add_column_if_missing(cur, "sessions", "match_id", "INTEGER")
        cur.execute("""
        CREATE TABLE IF NOT EXISTS matches (
            match_id INTEGER PRIMARY KEY,
            pdb_id TEXT NOT NULL,
            p1_name TEXT NOT NULL,
            p2_name TEXT NOT NULL,
            p1_session INTEGER,
            p2_session INTEGER,
            winner_name TEXT,
            reason TEXT,
            started_at FLOAT NOT NULL,
            ended_at FLOAT
        );
        """)
        cur.execute("""
        CREATE TABLE IF NOT EXISTS trajectories (
            trajectory_id INTEGER PRIMARY KEY,
            session_id INTEGER NOT NULL,
            mutant TEXT NOT NULL,
            score FLOAT NOT NULL,
            turn_count INTEGER NOT NULL,
            FOREIGN KEY (session_id) REFERENCES sessions (session_id)
        );
        """)
        cur.execute("""
        CREATE TABLE IF NOT EXISTS highscore (
            pdb_id VARCHAR(4) PRIMARY KEY,
            username TEXT NOT NULL,
            score FLOAT NOT NULL
        );
        """)
        connection.commit()
        cur.close()
        return connection
    except Exception as e:
        logger.error("Failed to initialize the database: %s", e)
        return None


def get_new_session(
    username: str,
    pdb_id: str,
    connection: sqlite3.Connection,
    max_turns: int = DEFAULT_MAX_TURNS,
    match_id: Optional[int] = None,
) -> int:
    cur = connection.cursor()
    cur.execute("""
    INSERT INTO sessions (username, turn_count, pdb_id, max_turns, match_id)
    VALUES (?, ?, ?, ?, ?);
    """, (username, 0, pdb_id, max_turns, match_id))
    session_id = cur.lastrowid
    connection.commit()
    cur.close()

    if session_id is None:
        logger.error("INSERT into sessions returned no lastrowid (username=%r, pdb_id=%s)", username, pdb_id)
        raise RuntimeError("Failed to create a new session")

    logger.info("Created session_id=%d for username=%r pdb_id=%s", session_id, username, pdb_id)
    return session_id


def get_session_info(session_id: int, connection: sqlite3.Connection) -> Optional[SessionInfo]:
    cur = connection.cursor()
    res = cur.execute("""
    SELECT session_id, username, pdb_id, turn_count, max_turns, match_id
    FROM sessions
    WHERE session_id = ?;
    """, (session_id,)).fetchone()
    cur.close()
    if res is None:
        return None
    return SessionInfo(*res)


def get_current_turn_count(session_id: int, connection: sqlite3.Connection) -> Optional[int]:
    cur = connection.cursor()
    res = cur.execute("""
    SELECT turn_count
    FROM sessions
    WHERE session_id = ?;
    """, (session_id,)).fetchone()
    cur.close()
    if res is None:
        return None
    return res[0]


def get_best_session_score(session_id: int, connection: sqlite3.Connection) -> Optional[float]:
    cur = connection.cursor()
    res = cur.execute("""
    SELECT MAX(t.score)
    FROM sessions s, trajectories t
    WHERE s.session_id = t.session_id
    AND s.session_id = ?;
    """, (session_id,)).fetchone()
    cur.close()
    if res is None:
        return None
    return res[0]


def add_trajectory(session_id: int, mutant: str, score: float, connection: sqlite3.Connection) -> None:
    cur = connection.cursor()
    cur.execute("""
    INSERT INTO trajectories (session_id, mutant, score, turn_count)
    VALUES (?, ?, ?, (SELECT COALESCE(MAX(turn_count), 0) FROM trajectories WHERE session_id = ?) + 1);
    """, (session_id, mutant, score, session_id))
    cur.execute("""
    UPDATE sessions
    SET turn_count = turn_count + 1
    WHERE session_id = ?;
    """, (session_id,))
    connection.commit()
    cur.close()


def get_trajectories(session_id: int, connection: sqlite3.Connection) -> List[TrajectoryStep]:
    cur = connection.cursor()
    res = cur.execute("""
    SELECT mutant, score, turn_count
    FROM trajectories
    WHERE session_id = ?
    ORDER BY turn_count;
    """, (session_id,)).fetchall()
    cur.close()

    return [TrajectoryStep(mutant=entry[0], score=entry[1], turn_count=entry[2]) for entry in res]


def get_highscore_db(connection: sqlite3.Connection, pdb_id: str) -> Highscore:
    cur = connection.cursor()
    res = cur.execute("""
    SELECT pdb_id, username, score
    FROM highscore
    WHERE pdb_id = ?
    LIMIT 1;
    """, [pdb_id]).fetchone()
    cur.close()
    if res is None:
        return init_highscore_db(pdb_id=pdb_id, connection=connection)
        
    return Highscore(username=res[1], score=res[2])


def set_highscore_db(connection: sqlite3.Connection, session_id: int, score: float, pdb_id: str) -> None:
    cur = connection.cursor()
    cur.execute("""
    UPDATE highscore
    SET username = (SELECT username FROM sessions WHERE session_id = ? LIMIT 1), score = ?
    WHERE pdb_id = ?;
    """, (session_id, score, pdb_id))
    connection.commit()
    cur.close()


def update_highscore_if_better(connection: sqlite3.Connection, session_id: int, pdb_id: str) -> bool:
    highscore = get_highscore_db(connection=connection, pdb_id=pdb_id)
    best_session_score = get_best_session_score(session_id=session_id, connection=connection)
    if best_session_score is None or highscore.score >= best_session_score:
        return False
    logger.info("New highscore for pdb_id=%s: %.4f (session_id=%d)", pdb_id, best_session_score, session_id)
    set_highscore_db(connection=connection, session_id=session_id, score=best_session_score, pdb_id=pdb_id)
    return True


def init_highscore_db(connection: sqlite3.Connection, pdb_id: str) -> Highscore:
    DEFAULT_NAME = "Evolution"
    DEFAULT_SCORE = 0
    cur = connection.cursor()
    cur.execute("""
    INSERT INTO highscore (pdb_id, username, score)
    VALUES (?, ?, ?);
    """, [pdb_id, DEFAULT_NAME, DEFAULT_SCORE])
    connection.commit()
    cur.close()
    return Highscore(username=DEFAULT_NAME, score=DEFAULT_SCORE)


def get_highscores_db(connection: sqlite3.Connection, pdb_ids: List[str]) -> Dict[str, Highscore]:
    cur = connection.cursor()
    placeholders = ','.join('?' for _ in pdb_ids)
    res = cur.execute(f"""
    SELECT pdb_id, username, score
    FROM highscore
    WHERE pdb_id IN ({placeholders});
    """, pdb_ids).fetchall()
    if res is None or len(res) == 0:
        return {pdb_id: init_highscore_db(connection=connection, pdb_id=pdb_id) for pdb_id in pdb_ids}

    highscores = {entry[0]: Highscore(username=entry[1], score=entry[2]) for entry in res}
    missing_highscores = set(pdb_ids) - set(highscores.keys())
    highscores.update({pdb_id: init_highscore_db(connection=connection, pdb_id=pdb_id) for pdb_id in missing_highscores})
    return highscores


def create_match(connection: sqlite3.Connection, pdb_id: str, p1_name: str, p2_name: str, started_at: float) -> int:
    cur = connection.cursor()
    cur.execute("""
    INSERT INTO matches (pdb_id, p1_name, p2_name, started_at)
    VALUES (?, ?, ?, ?);
    """, (pdb_id, p1_name, p2_name, started_at))
    match_id = cur.lastrowid
    connection.commit()
    cur.close()
    if match_id is None:
        raise RuntimeError("Failed to create a new match")
    return match_id


def set_match_sessions(connection: sqlite3.Connection, match_id: int, p1_session: int, p2_session: int) -> None:
    cur = connection.cursor()
    cur.execute("""
    UPDATE matches
    SET p1_session = ?, p2_session = ?
    WHERE match_id = ?;
    """, (p1_session, p2_session, match_id))
    connection.commit()
    cur.close()


def finish_match(
    connection: sqlite3.Connection, match_id: int, winner_name: Optional[str], reason: str, ended_at: float
) -> None:
    cur = connection.cursor()
    cur.execute("""
    UPDATE matches
    SET winner_name = ?, reason = ?, ended_at = ?
    WHERE match_id = ?;
    """, (winner_name, reason, ended_at, match_id))
    connection.commit()
    cur.close()


def get_leaderboard(connection: sqlite3.Connection, limit: int = 20) -> List[LeaderboardEntry]:
    cur = connection.cursor()
    res = cur.execute("""
    SELECT name,
           SUM(winner_name = name) AS wins,
           SUM(winner_name IS NOT NULL AND winner_name != name) AS losses,
           SUM(winner_name IS NULL) AS draws
    FROM (
        SELECT p1_name AS name, winner_name FROM matches WHERE ended_at IS NOT NULL
        UNION ALL
        SELECT p2_name AS name, winner_name FROM matches WHERE ended_at IS NOT NULL
    )
    GROUP BY name
    ORDER BY wins DESC, losses ASC, name ASC
    LIMIT ?;
    """, (limit,)).fetchall()
    cur.close()
    return [LeaderboardEntry(nickname=r[0], wins=r[1] or 0, losses=r[2] or 0, draws=r[3] or 0) for r in res]
