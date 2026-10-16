import asyncio
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, status

from zalpro_api.core.errors import ApiError
from zalpro_api.core.security import decode_access_claims
from zalpro_api.models import User
from zalpro_api.services import permissions

router = APIRouter(prefix="/ws", tags=["chat-ws"])


async def authorize(websocket: WebSocket, uid: str) -> tuple[User, datetime] | None:
    token = websocket.query_params.get("token")
    if not token:
        return None
    try:
        user_id, expires_at = decode_access_claims(token, websocket.app.state.settings)
    except ApiError:
        return None
    async with websocket.app.state.sessionmaker() as session:
        actor = await session.get(User, user_id)
        chat_owner = await session.get(User, uid)
    if actor is None or chat_owner is None:
        return None
    if not permissions.can_read_chat(actor, chat_owner):
        return None
    return actor, expires_at


async def pump(
    websocket: WebSocket, queue: asyncio.Queue[dict[str, Any]], expires_at: datetime
) -> None:
    while True:
        remaining = (expires_at - datetime.now(UTC)).total_seconds()
        if remaining <= 0:
            return
        try:
            payload = await asyncio.wait_for(queue.get(), timeout=remaining)
        except TimeoutError:
            return
        await websocket.send_json(payload)


async def watch_disconnect(websocket: WebSocket) -> None:
    while True:
        message = await websocket.receive()
        if message["type"] == "websocket.disconnect":
            return


@router.websocket("/chats/{uid}")
async def chat_socket(websocket: WebSocket, uid: str) -> None:
    await websocket.accept()
    authorized = await authorize(websocket, uid)
    if authorized is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
    _, expires_at = authorized
    hub = websocket.app.state.hub
    queue = hub.subscribe(uid)
    sender = asyncio.create_task(pump(websocket, queue, expires_at))
    watcher = asyncio.create_task(watch_disconnect(websocket))
    try:
        done, pending = await asyncio.wait({sender, watcher}, return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()
        await asyncio.gather(*pending, return_exceptions=True)
        if sender in done and sender.exception() is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
    except WebSocketDisconnect:
        return
    finally:
        hub.unsubscribe(uid, queue)
