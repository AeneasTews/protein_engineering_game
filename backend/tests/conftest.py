import os
import sys
import tempfile
from pathlib import Path

# main.py reads DB_PATH at import time, so the environment has to be set up first.
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))
os.environ["DB_PATH"] = str(Path(tempfile.mkdtemp(prefix="mutateit-test-")) / "test.sqlite3")
os.environ["MUTATEIT_DISABLE_BEACON"] = "1"
WEB_DIR = Path(tempfile.mkdtemp(prefix="mutateit-web-"))
(WEB_DIR / "index.html").write_text("<!doctype html><title>MutateIt</title>")
os.environ["MUTATEIT_WEB_DIR"] = str(WEB_DIR)

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402
from game import settings  # noqa: E402


@pytest.fixture(scope="session")
def client():
    # Session-scoped: startup parses every DMS CSV and validates every structure.
    with TestClient(main.app) as test_client:
        yield test_client


@pytest.fixture(autouse=True)
def fast_timings(monkeypatch):
    monkeypatch.setattr(settings, "COUNTDOWN_S", 0.0)
    monkeypatch.setattr(settings, "MATCH_DURATION_S", 30.0)
    monkeypatch.setattr(settings, "DISCONNECT_GRACE_S", 0.3)
    monkeypatch.setattr(settings, "MATCH_TURNS", 15)
