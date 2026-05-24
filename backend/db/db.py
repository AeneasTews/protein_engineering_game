import sqlite3
from typing import List, Optional
from pathlib import Path
from dataclasses import dataclass
import logging
import os


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


def init_db(path: Path, initial_highscore: float) -> Optional[sqlite3.Connection]:
    try:
        connection = sqlite3.connect(str(path))
        cur = connection.cursor()
        cur.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            session_id INTEGER PRIMARY KEY,
            username TEXT NOT NULL,
            turn_count INTEGER NOT NULL,
            pdb_id TEXT NOT NULL
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
            username TEXT NOT NULL,
            score FLOAT NOT NULL
        );
        """)
        cur.execute("""
        INSERT INTO highscore (username, score)
        VALUES ('nobody', ?);
        """, [initial_highscore])
        connection.commit()
        cur.close()
        return connection
    except Exception as e:
        logger.error(f"Failed to initialize the database: {e}")
        os.remove(str(path))
        return None


def get_new_session(username: str, pdb_id: str, connection: sqlite3.Connection) -> int:
    cur = connection.cursor()
    cur.execute("""
    INSERT INTO sessions (username, turn_count, pdb_id)
    VALUES (?, ?, ?);
    """, (username, 0, pdb_id))
    session_id = cur.lastrowid
    connection.commit()
    cur.close()
    return session_id


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


def get_highscore_db(connection: sqlite3.Connection) -> Optional[Highscore]:
    cur = connection.cursor()
    res = cur.execute("""
    SELECT username, score
    FROM highscore
    LIMIT 1;
    """).fetchone()
    cur.close()
    if res is None:
        return None
    return Highscore(username=res[0], score=res[1])


def set_highscore_db(session_id: int, score: float, connection: sqlite3.Connection) -> None:
    cur = connection.cursor()
    cur.execute("""
    UPDATE highscore
    SET username = (SELECT username FROM sessions WHERE session_id = ? LIMIT 1), score = ?
    WHERE TRUE;
    """, (session_id, score))
    connection.commit()
    cur.close()