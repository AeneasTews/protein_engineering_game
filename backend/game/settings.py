"""Tunable multiplayer settings.

Read these as module attributes (``settings.MATCH_TURNS``) at call time rather than
importing the values, so tests can monkeypatch them.
"""

import os


def _env_float(name: str, default: float) -> float:
    return float(os.environ.get(name, default))


MATCH_TURNS = int(os.environ.get("MUTATEIT_MATCH_TURNS", 15))
MATCH_DURATION_S = _env_float("MUTATEIT_MATCH_DURATION_S", 240.0)
COUNTDOWN_S = _env_float("MUTATEIT_COUNTDOWN_S", 3.0)
DISCONNECT_GRACE_S = _env_float("MUTATEIT_DISCONNECT_GRACE_S", 30.0)

MAX_NICKNAME_LENGTH = 24

BEACON_ENABLED = os.environ.get("MUTATEIT_DISABLE_BEACON", "") not in ("1", "true")
BEACON_PORT = int(os.environ.get("MUTATEIT_BEACON_PORT", 47800))
BEACON_INTERVAL_S = 2.0
# The HTTP port advertised in the beacon; must match the port uvicorn listens on.
SERVER_PORT = int(os.environ.get("MUTATEIT_PORT", 8000))
