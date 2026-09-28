import asyncio
import logging
import math
import random
import secrets
import sqlite3
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from data.loader import Protein
from db.db import (
    SessionInfo,
    create_match,
    finish_match,
    get_new_session,
    set_match_sessions,
    update_highscore_if_better,
)
from fastapi import WebSocket
from game import settings
from game.players import Player, PlayerRegistry

logger = logging.getLogger(__name__)


@dataclass
class Evaluation:
    mutant: str
    score: float
    turn_count: int
    at: float


@dataclass(eq=False)
class MatchPlayer:
    player: Player
    session_id: int
    history: List[Evaluation] = field(default_factory=list)
    best: Optional[Evaluation] = None

    @property
    def turn_count(self) -> int:
        return self.history[-1].turn_count if self.history else 0

    def rank_key(self) -> Tuple[float, float, float]:
        """Higher is better: best score, then fewer turns to reach it, then reached earlier."""
        if self.best is None:
            return (-math.inf, 0.0, 0.0)
        return (self.best.score, -self.best.turn_count, -self.best.at)

    def progress(self) -> Dict[str, Any]:
        return {
            "player_id": self.player.player_id,
            "nickname": self.player.nickname,
            "turn_count": self.turn_count,
            "best_score": self.best.score if self.best else None,
        }

    def history_json(self) -> List[Dict[str, Any]]:
        return [{"mutant": e.mutant, "score": e.score, "turn_count": e.turn_count} for e in self.history]

    def result(self) -> Dict[str, Any]:
        return {
            **self.progress(),
            "best_mutant": self.best.mutant if self.best else None,
            "history": self.history_json(),
        }


@dataclass(eq=False)
class Match:
    match_id: int
    protein: Protein
    max_turns: int
    starts_at: float
    ends_at: float
    players: List[MatchPlayer]
    finished: bool = False
    clock_task: Optional[asyncio.Task] = None
    grace_tasks: Dict[str, asyncio.Task] = field(default_factory=dict)

    def entry_for(self, player: Player) -> MatchPlayer:
        return next(mp for mp in self.players if mp.player is player)

    def entry_for_session(self, session_id: int) -> Optional[MatchPlayer]:
        return next((mp for mp in self.players if mp.session_id == session_id), None)

    def opponent_of(self, entry: MatchPlayer) -> MatchPlayer:
        return next(mp for mp in self.players if mp is not entry)


@dataclass
class Challenge:
    challenge_id: str
    challenger: Player
    target: Player
    pdb_id: Optional[str]
    rematch: bool


class MatchError(Exception):
    pass


class MatchManager:
    def __init__(self, registry: PlayerRegistry, connection: sqlite3.Connection, proteins: Dict[str, Protein]):
        self._registry = registry
        self._connection = connection
        self._proteins = proteins
        self._matches: Dict[int, Match] = {}
        self._challenges: Dict[str, Challenge] = {}

    # ------------------------------------------------------------------
    # Connection lifecycle
    # ------------------------------------------------------------------

    async def connect(self, player: Player, websocket: WebSocket) -> None:
        previous = player.websocket
        player.websocket = websocket
        if previous is not None and previous is not websocket:
            try:
                await previous.close(code=4000, reason="Replaced by a newer connection")
            except Exception:
                pass

        await player.send({"type": "welcome", "player_id": player.player_id, "nickname": player.nickname})

        match = self._active_match(player)
        if match is not None:
            task = match.grace_tasks.pop(player.player_id, None)
            if task is not None:
                task.cancel()
            entry = match.entry_for(player)
            await player.send(self._match_start_message(match, entry, resume=True))
            await match.opponent_of(entry).player.send({"type": "opponent_status", "connected": True})

        for challenge in self._challenges.values():
            if challenge.target is player:
                await player.send(self._challenge_received_message(challenge))

        await self._registry.broadcast_lobby()

    async def disconnect(self, player: Player, websocket: WebSocket) -> None:
        if player.websocket is not websocket:
            return  # Already replaced by a newer connection.
        player.websocket = None
        await self._drop_challenges_involving(player)

        match = self._active_match(player)
        if match is not None:
            opponent = match.opponent_of(match.entry_for(player))
            await opponent.player.send({"type": "opponent_status", "connected": False})
            match.grace_tasks[player.player_id] = asyncio.create_task(self._forfeit_after_grace(match, player))

        await self._registry.broadcast_lobby()

    async def handle(self, player: Player, message: Dict[str, Any]) -> None:
        message_type = message.get("type")
        try:
            if message_type == "ping":
                await player.send({"type": "pong", "server_now": time.time()})
            elif message_type == "challenge":
                await self._challenge(player, str(message.get("to", "")), message.get("pdb_id"), rematch=False)
            elif message_type == "challenge_response":
                await self._respond(player, str(message.get("challenge_id", "")), bool(message.get("accept")))
            elif message_type == "cancel_challenge":
                await self._cancel_outgoing(player)
            elif message_type == "rematch":
                await self._rematch(player)
            elif message_type == "forfeit":
                match = self._active_match(player)
                if match is None:
                    raise MatchError("You are not in a match")
                await self.finish(match, "forfeit", loser=player)
            else:
                raise MatchError(f"Unknown message type: {message_type!r}")
        except MatchError as e:
            await player.send({"type": "error", "message": str(e)})

    async def shutdown(self) -> None:
        for match in list(self._matches.values()):
            for task in [match.clock_task, *match.grace_tasks.values()]:
                if task is not None:
                    task.cancel()
        self._matches.clear()

    # ------------------------------------------------------------------
    # Challenges
    # ------------------------------------------------------------------

    async def _challenge(self, player: Player, target_id: str, pdb_id: Optional[str], rematch: bool) -> None:
        target = self._registry.by_id(target_id)
        if target is None or not target.connected:
            raise MatchError("That player is not online")
        if target is player:
            raise MatchError("You can't challenge yourself")
        if player.match_id is not None or target.match_id is not None:
            raise MatchError("That player is already in a match")
        if pdb_id is not None and pdb_id not in self._proteins:
            raise MatchError("Unknown protein")

        # Challenging someone who already challenged you counts as accepting.
        reverse = next(
            (c for c in self._challenges.values() if c.challenger is target and c.target is player), None
        )
        if reverse is not None:
            await self._respond(player, reverse.challenge_id, accept=True)
            return

        await self._cancel_outgoing(player)
        challenge = Challenge(
            challenge_id=secrets.token_hex(6), challenger=player, target=target, pdb_id=pdb_id, rematch=rematch
        )
        self._challenges[challenge.challenge_id] = challenge
        await target.send(self._challenge_received_message(challenge))
        await player.send(
            {
                "type": "challenge_sent",
                "challenge_id": challenge.challenge_id,
                "to": {"player_id": target.player_id, "nickname": target.nickname},
                "pdb_id": pdb_id,
                "rematch": rematch,
            }
        )

    async def _respond(self, player: Player, challenge_id: str, accept: bool) -> None:
        challenge = self._challenges.get(challenge_id)
        if challenge is None or challenge.target is not player:
            raise MatchError("That challenge no longer exists")
        del self._challenges[challenge_id]
        challenger = challenge.challenger

        if not accept:
            await challenger.send(
                {"type": "challenge_declined", "challenge_id": challenge_id, "by": player.nickname}
            )
            return

        if not challenger.connected or challenger.match_id is not None or player.match_id is not None:
            raise MatchError("That challenge is no longer available")

        await self._drop_challenges_involving(challenger)
        await self._drop_challenges_involving(player)
        await self._start_match(challenger, player, challenge.pdb_id)

    async def _cancel_outgoing(self, player: Player) -> None:
        for challenge in [c for c in self._challenges.values() if c.challenger is player]:
            del self._challenges[challenge.challenge_id]
            await challenge.target.send({"type": "challenge_cancelled", "challenge_id": challenge.challenge_id})

    async def _drop_challenges_involving(self, player: Player) -> None:
        for challenge in [c for c in self._challenges.values() if player in (c.challenger, c.target)]:
            del self._challenges[challenge.challenge_id]
            other = challenge.target if challenge.challenger is player else challenge.challenger
            await other.send({"type": "challenge_cancelled", "challenge_id": challenge.challenge_id})

    async def _rematch(self, player: Player) -> None:
        opponent = self._registry.by_id(player.last_opponent_id) if player.last_opponent_id else None
        if opponent is None:
            raise MatchError("No previous opponent to rematch")
        await self._challenge(player, opponent.player_id, None, rematch=True)

    def _challenge_received_message(self, challenge: Challenge) -> Dict[str, Any]:
        return {
            "type": "challenge_received",
            "challenge_id": challenge.challenge_id,
            "from": {"player_id": challenge.challenger.player_id, "nickname": challenge.challenger.nickname},
            "pdb_id": challenge.pdb_id,
            "rematch": challenge.rematch,
        }

    # ------------------------------------------------------------------
    # Match lifecycle
    # ------------------------------------------------------------------

    def _active_match(self, player: Player) -> Optional[Match]:
        if player.match_id is None:
            return None
        return self._matches.get(player.match_id)

    async def _start_match(self, first: Player, second: Player, pdb_id: Optional[str]) -> None:
        protein = self._proteins[pdb_id] if pdb_id else random.choice(list(self._proteins.values()))
        starts_at = time.time() + settings.COUNTDOWN_S
        ends_at = starts_at + settings.MATCH_DURATION_S
        max_turns = settings.MATCH_TURNS

        match_id = create_match(self._connection, protein.pdb_id, first.nickname, second.nickname, starts_at)
        entries = [
            MatchPlayer(
                player=p,
                session_id=get_new_session(
                    username=p.nickname,
                    pdb_id=protein.pdb_id,
                    connection=self._connection,
                    max_turns=max_turns,
                    match_id=match_id,
                ),
            )
            for p in (first, second)
        ]
        set_match_sessions(self._connection, match_id, entries[0].session_id, entries[1].session_id)

        match = Match(
            match_id=match_id,
            protein=protein,
            max_turns=max_turns,
            starts_at=starts_at,
            ends_at=ends_at,
            players=entries,
        )
        self._matches[match_id] = match
        for entry in entries:
            entry.player.match_id = match_id
        match.clock_task = asyncio.create_task(self._run_clock(match))
        logger.info("Match %d started: %r vs %r on %s", match_id, first.nickname, second.nickname, protein.pdb_id)

        for entry in entries:
            await entry.player.send(self._match_start_message(match, entry, resume=False))
        await self._registry.broadcast_lobby()

    def _match_start_message(self, match: Match, entry: MatchPlayer, resume: bool) -> Dict[str, Any]:
        opponent = match.opponent_of(entry)
        return {
            "type": "match_start",
            "resume": resume,
            "match_id": match.match_id,
            "session_id": entry.session_id,
            "protein": {
                "pdb_id": match.protein.pdb_id,
                "name": match.protein.name,
                "wildtype_sequence": match.protein.wildtype_sequence,
            },
            "max_turns": match.max_turns,
            "starts_at": match.starts_at,
            "ends_at": match.ends_at,
            "server_now": time.time(),
            "you": {**entry.progress(), "history": entry.history_json()},
            "opponent": {**opponent.progress(), "connected": opponent.player.connected},
        }

    async def _run_clock(self, match: Match) -> None:
        try:
            await asyncio.sleep(max(0.0, match.ends_at - time.time()))
            await self.finish(match, "time_up")
        except asyncio.CancelledError:
            pass

    async def _forfeit_after_grace(self, match: Match, player: Player) -> None:
        try:
            await asyncio.sleep(settings.DISCONNECT_GRACE_S)
            await self.finish(match, "disconnect", loser=player)
        except asyncio.CancelledError:
            pass

    def check_can_evaluate(self, session: SessionInfo, token: Optional[str]) -> Optional[Tuple[int, str]]:
        """Returns (status_code, detail) if this match session may not evaluate right now."""
        match = self._matches.get(session.match_id) if session.match_id is not None else None
        if match is None or match.finished:
            return 409, "This match is over"
        entry = match.entry_for_session(session.session_id)
        if entry is None or token is None or entry.player.token != token:
            return 403, "This session belongs to another player"
        now = time.time()
        if now < match.starts_at:
            return 409, "The match has not started yet"
        if now >= match.ends_at:
            return 409, "Time is up"
        return None

    async def on_evaluation(self, session: SessionInfo, mutant: str, score: float, turn_count: int) -> None:
        match = self._matches.get(session.match_id) if session.match_id is not None else None
        if match is None or match.finished:
            return
        entry = match.entry_for_session(session.session_id)
        if entry is None:
            return

        evaluation = Evaluation(mutant=mutant, score=score, turn_count=turn_count, at=time.time())
        entry.history.append(evaluation)
        new_best = entry.best is None or score > entry.best.score
        if new_best:
            entry.best = evaluation

        await match.opponent_of(entry).player.send(
            {
                "type": "opponent_progress",
                "turn_count": entry.turn_count,
                "best_score": entry.best.score if entry.best else None,
                "new_best": new_best,
            }
        )

        if all(mp.turn_count >= match.max_turns for mp in match.players):
            await self.finish(match, "turns_exhausted")

    async def finish(self, match: Match, reason: str, loser: Optional[Player] = None) -> None:
        if match.finished:
            return
        match.finished = True
        current = asyncio.current_task()
        for task in [match.clock_task, *match.grace_tasks.values()]:
            if task is not None and task is not current:
                task.cancel()
        match.grace_tasks.clear()
        self._matches.pop(match.match_id, None)

        first, second = match.players
        winner: Optional[MatchPlayer]
        if loser is not None:
            winner = second if first.player is loser else first
        elif first.rank_key() > second.rank_key():
            winner = first
        elif second.rank_key() > first.rank_key():
            winner = second
        else:
            winner = None

        finish_match(
            self._connection,
            match.match_id,
            winner.player.nickname if winner else None,
            reason,
            ended_at=time.time(),
        )
        for entry in match.players:
            update_highscore_if_better(self._connection, entry.session_id, match.protein.pdb_id)
        logger.info(
            "Match %d finished (%s): winner=%r", match.match_id, reason, winner.player.nickname if winner else None
        )

        for entry in match.players:
            opponent = match.opponent_of(entry)
            entry.player.match_id = None
            entry.player.last_opponent_id = opponent.player.player_id
        for entry in match.players:
            opponent = match.opponent_of(entry)
            await entry.player.send(
                {
                    "type": "match_end",
                    "match_id": match.match_id,
                    "reason": reason,
                    "winner_id": winner.player.player_id if winner else None,
                    "you": entry.result(),
                    "opponent": opponent.result(),
                }
            )
        await self._registry.broadcast_lobby()
