"""LAN discovery: periodically broadcasts a small UDP beacon so clients can find this server."""

import asyncio
import json
import logging
import socket

from game import settings

logger = logging.getLogger(__name__)

SERVICE_NAME = "mutateit"


def _beacon_payload() -> bytes:
    return json.dumps(
        {"service": SERVICE_NAME, "port": settings.SERVER_PORT, "name": socket.gethostname()}
    ).encode("utf-8")


async def run_beacon() -> None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setblocking(False)
    payload = _beacon_payload()
    logger.info("Broadcasting discovery beacon on UDP port %d", settings.BEACON_PORT)

    warned = False
    try:
        while True:
            try:
                sock.sendto(payload, ("255.255.255.255", settings.BEACON_PORT))
            except OSError as e:
                # E.g. no network; discovery is best effort, clients can still enter the address by hand.
                if not warned:
                    logger.warning("Discovery beacon failed to send: %s", e)
                    warned = True
            await asyncio.sleep(settings.BEACON_INTERVAL_S)
    finally:
        sock.close()
