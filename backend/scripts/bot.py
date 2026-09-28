"""A simple bot opponent for testing multiplayer with a single human (or none).

It accepts every challenge (and rematch), then plays a greedy random walk: each turn it adds
one random mutation to its best variant so far and keeps the result if it scores higher.

    uv run python scripts/bot.py                            # wait for challenges
    uv run python scripts/bot.py --challenge alice          # challenge "alice" once she's online
    uv run python scripts/bot.py --server http://192.168.1.20:8000 --think 2
"""

import argparse
import asyncio
import json
import random
import time
import urllib.error
import urllib.request

import websockets

AMINO_ACIDS = "ACDEFGHIKLMNPQRSTVWY"


def post_json(url: str, body: dict, headers: dict | None = None) -> tuple[int, dict]:
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", **(headers or {})},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def build_mutant(mutations: dict[int, str], wildtype: str) -> str:
    return ":".join(f"{wildtype[pos - 1]}{pos}{aa}" for pos, aa in sorted(mutations.items()))


async def play_match(server: str, token: str, start: dict, think: float) -> None:
    clock_offset = start["server_now"] - time.time()
    now = lambda: time.time() + clock_offset  # noqa: E731

    await asyncio.sleep(max(0.0, start["starts_at"] - now()))
    wildtype = start["protein"]["wildtype_sequence"]
    best_mutations: dict[int, str] = {}
    best_score = float("-inf")
    turns_left = start["max_turns"] - start["you"]["turn_count"]

    while turns_left > 0 and now() < start["ends_at"]:
        await asyncio.sleep(think * random.uniform(0.5, 1.5))
        candidate = dict(best_mutations)
        position = random.randrange(1, len(wildtype) + 1)
        candidate[position] = random.choice([aa for aa in AMINO_ACIDS if aa != wildtype[position - 1]])

        status, body = await asyncio.to_thread(
            post_json,
            f"{server}/evaluate",
            {"session_id": start["session_id"], "pdb_id": start["protein"]["pdb_id"], "mutant": build_mutant(candidate, wildtype)},
            {"X-Player-Token": token},
        )
        if status != 200:
            print(f"  evaluate stopped: {status} {body.get('detail')}")
            return
        turns_left = body["max_turns"] - body["turn_count"]
        if body["score"] > best_score:
            best_score, best_mutations = body["score"], candidate
        print(f"  turn {body['turn_count']}: {body['mutant']} -> {body['score']:.2f} (best {best_score:.2f})")


async def run(server: str, nickname: str, challenge: str | None, think: float) -> None:
    status, player = post_json(f"{server}/players", {"nickname": nickname})
    if status != 200:
        raise SystemExit(f"Could not register {nickname!r}: {status} {player.get('detail')}")
    print(f"Registered as {player['nickname']}")

    ws_url = server.replace("http", "ws", 1) + f"/ws?token={player['token']}"
    async with websockets.connect(ws_url) as ws:
        challenged = False
        games: set[asyncio.Task] = set()  # Holds references so running games aren't garbage collected.
        async for raw in ws:
            message = json.loads(raw)
            kind = message["type"]
            if kind == "lobby" and challenge and not challenged:
                target = next((p for p in message["players"] if p["nickname"].casefold() == challenge.casefold()), None)
                if target and target["status"] == "idle":
                    await ws.send(json.dumps({"type": "challenge", "to": target["player_id"]}))
                    challenged = True
                    print(f"Challenged {target['nickname']}")
            elif kind == "challenge_received":
                print(f"Accepting challenge from {message['from']['nickname']}")
                await ws.send(json.dumps({"type": "challenge_response", "challenge_id": message["challenge_id"], "accept": True}))
            elif kind == "match_start":
                print(f"Match on {message['protein']['name']} ({message['protein']['pdb_id']}) vs {message['opponent']['nickname']}")
                # A game that outlives its match stops on its own once /evaluate answers 409.
                game = asyncio.create_task(play_match(server, player["token"], message, think))
                games.add(game)
                game.add_done_callback(games.discard)
            elif kind == "match_end":
                won = message["winner_id"] == player["player_id"]
                outcome = "draw" if message["winner_id"] is None else ("won" if won else "lost")
                print(f"Match over ({message['reason']}): {outcome} "
                      f"{message['you']['best_score']} vs {message['opponent']['best_score']}")
            elif kind == "error":
                print(f"Server error: {message['message']}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--server", default="http://localhost:8000")
    parser.add_argument("--nickname", default="Bot")
    parser.add_argument("--challenge", help="nickname to challenge once it is online and idle")
    parser.add_argument("--think", type=float, default=4.0, help="average seconds between moves")
    args = parser.parse_args()
    try:
        asyncio.run(run(args.server.rstrip("/"), args.nickname, args.challenge, args.think))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
