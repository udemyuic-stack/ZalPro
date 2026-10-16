import asyncio
from collections import defaultdict
from typing import Any

QUEUE_SIZE = 100


class ChatHub:
    def __init__(self) -> None:
        self._queues: dict[str, set[asyncio.Queue[dict[str, Any]]]] = defaultdict(set)

    def subscribe(self, chat_uid: str) -> asyncio.Queue[dict[str, Any]]:
        queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=QUEUE_SIZE)
        self._queues[chat_uid].add(queue)
        return queue

    def unsubscribe(self, chat_uid: str, queue: asyncio.Queue[dict[str, Any]]) -> None:
        queues = self._queues.get(chat_uid)
        if queues is None:
            return
        queues.discard(queue)
        if not queues:
            del self._queues[chat_uid]

    def publish(self, chat_uid: str, payload: dict[str, Any]) -> None:
        for queue in tuple(self._queues.get(chat_uid, ())):
            try:
                queue.put_nowait(payload)
            except asyncio.QueueFull:
                continue

    def subscriber_count(self, chat_uid: str) -> int:
        return len(self._queues.get(chat_uid, ()))
