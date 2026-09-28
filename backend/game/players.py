import logging
import secrets
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class NicknameTaken(Exception):
    pass


@dataclass(eq=False)
class Player:
    player_id: str
    nickname: str
    token: str
    websocket: Optional[WebSocket] = None
    match_id: Optional[int] = None
    last_opponent_id: Optional[str] = None

    @property
    def connected(self) -> bool:
        return self.websocket is not None

    @property
    def status(self) -> str:
        return "in_match" if self.match_id is not None else "idle"

    async def send(self, message: Dict[str, Any]) -> None:
        if self.websocket is None:
            return
        try:
            await self.websocket.send_json(message)
        except Exception as e:
            # The receive loop notices the broken socket and runs the disconnect path.
            logger.debug("Failed to send %s to %r: %s", message.get("type"), self.nickname, e)


class PlayerRegistry:
    """In-memory nickname registry. Players are identified by nickname only (no passwords)."""

    def __init__(self) -> None:
        self._by_nickname: Dict[str, Player] = {}
        self._by_token: Dict[str, Player] = {}
        self._by_id: Dict[str, Player] = {}

    def register(self, nickname: str) -> Player:
        """Returns a new player, or the existing one if that nickname is currently offline.

        Handing an offline player's identity back to whoever claims the nickname lets someone
        who restarted the app resume a running match. On a trusted LAN that's the desired behavior.
        """
        key = nickname.casefold()
        existing = self._by_nickname.get(key)
        if existing is not None:
            if existing.connected:
                raise NicknameTaken(nickname)
            return existing

        player = Player(player_id=secrets.token_hex(8), nickname=nickname, token=secrets.token_urlsafe(24))
        self._by_nickname[key] = player
        self._by_token[player.token] = player
        self._by_id[player.player_id] = player
        logger.info("Registered player %r (%s)", nickname, player.player_id)
        return player

    def by_token(self, token: str) -> Optional[Player]:
        return self._by_token.get(token)

    def by_id(self, player_id: str) -> Optional[Player]:
        return self._by_id.get(player_id)

    def online(self) -> List[Player]:
        return [p for p in self._by_id.values() if p.connected]

    def lobby_message(self) -> Dict[str, Any]:
        return {
            "type": "lobby",
            "players": [
                {"player_id": p.player_id, "nickname": p.nickname, "status": p.status}
                for p in sorted(self.online(), key=lambda p: p.nickname.casefold())
            ],
        }

    async def broadcast_lobby(self) -> None:
        message = self.lobby_message()
        for player in self.online():
            await player.send(message)
