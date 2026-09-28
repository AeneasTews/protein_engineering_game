import itertools
import sqlite3
from contextlib import contextmanager

from db.db import init_db
from game import settings

_names = itertools.count()


def register(client, nickname=None):
    nickname = nickname or f"player{next(_names)}"
    response = client.post("/players", json={"nickname": nickname})
    assert response.status_code == 200, response.text
    return response.json()


def recv_until(ws, message_type):
    """Skips unrelated messages (e.g. lobby updates) until one of the given type arrives."""
    while True:
        message = ws.receive_json()
        if message["type"] == message_type:
            return message


def connect(client, player):
    return client.websocket_connect(f"/ws?token={player['token']}")


def mutant_at(start, position, choice=0):
    wildtype = start["protein"]["wildtype_sequence"][position - 1]
    alternatives = [aa for aa in "ACDEFGHIKLMNPQRSTVWY" if aa != wildtype]
    return f"{wildtype}{position}{alternatives[choice]}"


def evaluate(client, player, start, mutant, pdb_id=None, token="own"):
    headers = {}
    if token == "own":
        headers["X-Player-Token"] = player["token"]
    elif token is not None:
        headers["X-Player-Token"] = token
    return client.post(
        "/evaluate",
        json={
            "session_id": start["session_id"],
            "pdb_id": pdb_id or start["protein"]["pdb_id"],
            "mutant": mutant,
        },
        headers=headers,
    )


def start_match(wa, wb, b, pdb_id=None):
    wa.send_json({"type": "challenge", "to": b["player_id"], "pdb_id": pdb_id})
    challenge = recv_until(wb, "challenge_received")
    wb.send_json({"type": "challenge_response", "challenge_id": challenge["challenge_id"], "accept": True})
    return recv_until(wa, "match_start"), recv_until(wb, "match_start")


@contextmanager
def running_match(client):
    a, b = register(client), register(client)
    with connect(client, a) as wa, connect(client, b) as wb:
        start_a, start_b = start_match(wa, wb, b)
        yield a, b, wa, wb, start_a, start_b


def test_register_rejects_invalid_and_online_nicknames(client):
    assert client.post("/players", json={"nickname": "   "}).status_code == 400
    assert client.post("/players", json={"nickname": "x" * 25}).status_code == 400

    player = register(client, "Duplicate")
    with connect(client, player) as ws:
        recv_until(ws, "welcome")
        assert client.post("/players", json={"nickname": "duplicate"}).status_code == 409

    # Once offline, the nickname hands back the same identity so the player can resume.
    assert register(client, "duplicate")["player_id"] == player["player_id"]


def test_unknown_token_is_rejected(client):
    import pytest
    from starlette.websockets import WebSocketDisconnect

    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/ws?token=nope") as ws:
            ws.receive_json()


def test_lobby_lists_online_players(client):
    a, b = register(client), register(client)
    with connect(client, a) as wa, connect(client, b):
        while True:
            lobby = recv_until(wa, "lobby")
            nicknames = {p["nickname"] for p in lobby["players"]}
            if {a["nickname"], b["nickname"]} <= nicknames:
                break


def test_match_start_and_opponent_progress(client):
    with running_match(client) as (a, b, wa, wb, start_a, start_b):
        assert start_a["session_id"] != start_b["session_id"]
        assert start_a["protein"] == start_b["protein"]
        assert start_a["max_turns"] == settings.MATCH_TURNS
        assert start_a["opponent"]["nickname"] == b["nickname"]

        response = evaluate(client, a, start_a, mutant_at(start_a, 1))
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["turn_count"] == 1
        assert body["max_turns"] == settings.MATCH_TURNS

        progress = recv_until(wb, "opponent_progress")
        assert progress == {
            "type": "opponent_progress",
            "turn_count": 1,
            "best_score": body["score"],
            "new_best": True,
        }
        wa.send_json({"type": "forfeit"})
        recv_until(wa, "match_end")


def test_evaluate_rejects_foreign_or_missing_token_and_wrong_protein(client):
    with running_match(client) as (a, b, wa, wb, start_a, start_b):
        mutant = mutant_at(start_a, 1)
        assert evaluate(client, a, start_a, mutant, token=b["token"]).status_code == 403
        assert evaluate(client, a, start_a, mutant, token=None).status_code == 403
        other_pdb = next(p["pdb_id"] for p in client.get("/proteins").json() if p["pdb_id"] != start_a["protein"]["pdb_id"])
        assert evaluate(client, a, start_a, mutant, pdb_id=other_pdb).status_code == 400
        wa.send_json({"type": "forfeit"})
        recv_until(wa, "match_end")


def test_evaluate_blocked_during_countdown(client, monkeypatch):
    monkeypatch.setattr(settings, "COUNTDOWN_S", 30.0)
    with running_match(client) as (a, b, wa, wb, start_a, start_b):
        response = evaluate(client, a, start_a, mutant_at(start_a, 1))
        assert response.status_code == 409
        assert "not started" in response.json()["detail"]
        wa.send_json({"type": "forfeit"})
        recv_until(wa, "match_end")


def test_turns_exhausted_ends_match_with_correct_winner(client, monkeypatch):
    monkeypatch.setattr(settings, "MATCH_TURNS", 2)
    with running_match(client) as (a, b, wa, wb, start_a, start_b):
        scores = {}
        for player, start, choice in ((a, start_a, 0), (b, start_b, 5)):
            results = [
                evaluate(client, player, start, mutant_at(start, position, choice)).json()["score"]
                for position in (2, 3)
            ]
            scores[player["player_id"]] = max(results)

        # A third evaluation is over the turn budget (and the match is already over).
        assert evaluate(client, a, start_a, mutant_at(start_a, 4)).status_code in (400, 409)

        end_a, end_b = recv_until(wa, "match_end"), recv_until(wb, "match_end")
        assert end_a["reason"] == end_b["reason"] == "turns_exhausted"
        assert end_a["winner_id"] == end_b["winner_id"]
        assert end_a["you"]["best_score"] == scores[a["player_id"]]
        assert end_a["opponent"]["best_mutant"] == end_b["you"]["best_mutant"]
        assert len(end_a["you"]["history"]) == 2

        best_a, best_b = scores[a["player_id"]], scores[b["player_id"]]
        if best_a != best_b:
            expected = a if best_a > best_b else b
            assert end_a["winner_id"] == expected["player_id"]

        leaderboard = {e["nickname"]: e for e in client.get("/leaderboard").json()}
        assert leaderboard[a["nickname"]]["wins"] + leaderboard[a["nickname"]]["losses"] + leaderboard[a["nickname"]]["draws"] == 1


def test_time_up_without_evaluations_is_a_draw(client, monkeypatch):
    monkeypatch.setattr(settings, "MATCH_DURATION_S", 0.3)
    with running_match(client) as (a, b, wa, wb, start_a, start_b):
        end = recv_until(wa, "match_end")
        assert end["reason"] == "time_up"
        assert end["winner_id"] is None
        assert evaluate(client, a, start_a, mutant_at(start_a, 1)).status_code == 409


def test_forfeit_gives_opponent_the_win(client):
    with running_match(client) as (a, b, wa, wb, start_a, start_b):
        wa.send_json({"type": "forfeit"})
        end = recv_until(wb, "match_end")
        assert end["reason"] == "forfeit"
        assert end["winner_id"] == b["player_id"]


def test_disconnect_forfeits_after_grace_period(client):
    a, b = register(client), register(client)
    with connect(client, a) as wa:
        with connect(client, b) as wb:
            start_match(wa, wb, b)
        assert recv_until(wa, "opponent_status")["connected"] is False
        end = recv_until(wa, "match_end")
        assert end["reason"] == "disconnect"
        assert end["winner_id"] == a["player_id"]


def test_reconnect_within_grace_period_resumes_match(client, monkeypatch):
    monkeypatch.setattr(settings, "DISCONNECT_GRACE_S", 30.0)
    a, b = register(client), register(client)
    with connect(client, a) as wa:
        with connect(client, b) as wb:
            _, start_b = start_match(wa, wb, b)
            evaluate(client, b, start_b, mutant_at(start_b, 1))
        assert recv_until(wa, "opponent_status")["connected"] is False

        with connect(client, b) as wb:
            resumed = recv_until(wb, "match_start")
            assert resumed["resume"] is True
            assert resumed["session_id"] == start_b["session_id"]
            assert len(resumed["you"]["history"]) == 1
            assert recv_until(wa, "opponent_status")["connected"] is True
            wb.send_json({"type": "forfeit"})
            assert recv_until(wa, "match_end")["winner_id"] == a["player_id"]


def test_decline_and_mutual_rematch(client):
    a, b = register(client), register(client)
    with connect(client, a) as wa, connect(client, b) as wb:
        wa.send_json({"type": "challenge", "to": b["player_id"]})
        challenge = recv_until(wb, "challenge_received")
        wb.send_json({"type": "challenge_response", "challenge_id": challenge["challenge_id"], "accept": False})
        assert recv_until(wa, "challenge_declined")["by"] == b["nickname"]

        start_match(wa, wb, b)
        wa.send_json({"type": "forfeit"})
        recv_until(wa, "match_end")
        recv_until(wb, "match_end")

        wa.send_json({"type": "rematch"})
        assert recv_until(wb, "challenge_received")["rematch"] is True
        wb.send_json({"type": "rematch"})  # Offering a rematch back accepts it.
        assert recv_until(wa, "match_start")["opponent"]["nickname"] == b["nickname"]
        recv_until(wb, "match_start")
        wa.send_json({"type": "forfeit"})
        recv_until(wa, "match_end")


def test_practice_sessions_are_unchanged(client):
    protein = client.get("/proteins").json()[0]
    session_id = client.post("/session", json={"username": "solo", "pdb_id": protein["pdb_id"]}).json()["session_id"]
    wildtype = protein["wildtype_sequence"][0]
    mutant = f"{wildtype}1{'A' if wildtype != 'A' else 'G'}"
    response = client.post("/evaluate", json={"session_id": session_id, "pdb_id": protein["pdb_id"], "mutant": mutant})
    assert response.status_code == 200, response.text
    assert response.json()["max_turns"] == 20


def test_init_db_migrates_old_sessions_table(tmp_path):
    path = tmp_path / "old.sqlite3"
    old = sqlite3.connect(path)
    old.execute(
        "CREATE TABLE sessions (session_id INTEGER PRIMARY KEY, username TEXT NOT NULL, "
        "turn_count INTEGER NOT NULL, pdb_id TEXT NOT NULL);"
    )
    old.execute("INSERT INTO sessions (username, turn_count, pdb_id) VALUES ('old', 3, '1E0L');")
    old.commit()
    old.close()

    connection = init_db(path)
    assert connection is not None
    row = connection.execute("SELECT turn_count, max_turns, match_id FROM sessions;").fetchone()
    assert row == (3, 20, None)
    connection.close()
