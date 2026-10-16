import asyncio
import json
from collections.abc import AsyncIterator, Awaitable, Callable
from datetime import timedelta
from typing import Any

import pytest
import pytest_asyncio
import uvicorn
from httpx import AsyncClient
from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed

from zalpro_api.core.config import Settings
from zalpro_api.core.security import create_access_token
from zalpro_api.models import User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

POLICY_VIOLATION = 1008
WAIT = 3.0


@pytest_asyncio.fixture
async def server(app: Any) -> AsyncIterator[str]:
    config = uvicorn.Config(app, host="127.0.0.1", port=0, log_level="warning", lifespan="off")
    instance = uvicorn.Server(config)
    task = asyncio.create_task(instance.serve())
    for _ in range(300):
        if instance.started:
            break
        await asyncio.sleep(0.01)
    port = instance.servers[0].sockets[0].getsockname()[1]
    yield f"ws://127.0.0.1:{port}"
    instance.should_exit = True
    await task


def ws_url(base: str, chat: User, token: str | None) -> str:
    suffix = "" if token is None else f"?token={token}"
    return f"{base}/v1/ws/chats/{chat.id}{suffix}"


def token_for(user: User, settings: Settings, lifetime: timedelta | None = None) -> str:
    return create_access_token(user.id, settings, lifetime)


async def expect_policy_close(url: str) -> None:
    async with connect(url) as socket:
        with pytest.raises(ConnectionClosed) as info:
            await asyncio.wait_for(socket.recv(), WAIT)
    assert info.value.rcvd is not None
    assert info.value.rcvd.code == POLICY_VIOLATION


async def wait_for_subscribers(app: Any, chat: User, expected: int) -> None:
    for _ in range(300):
        if app.state.hub.subscriber_count(chat.id) == expected:
            return
        await asyncio.sleep(0.01)
    assert app.state.hub.subscriber_count(chat.id) == expected


async def test_missing_token_is_closed(server: str, make_user: UserFactory) -> None:
    chat = await make_user("user")

    await expect_policy_close(ws_url(server, chat, None))


async def test_invalid_token_is_closed(server: str, make_user: UserFactory) -> None:
    chat = await make_user("user")

    await expect_policy_close(ws_url(server, chat, "garbage"))


async def test_expired_token_is_closed(
    server: str, make_user: UserFactory, settings: Settings
) -> None:
    chat = await make_user("user")
    token = token_for(chat, settings, timedelta(seconds=-5))

    await expect_policy_close(ws_url(server, chat, token))


async def test_foreign_chat_is_closed(
    server: str, app: Any, make_user: UserFactory, settings: Settings
) -> None:
    chat = await make_user("user")
    stranger = await make_user("user")

    await expect_policy_close(ws_url(server, chat, token_for(stranger, settings)))

    assert app.state.hub.subscriber_count(chat.id) == 0


async def test_barmen_is_closed(server: str, make_user: UserFactory, settings: Settings) -> None:
    chat = await make_user("user")
    barmen = await make_user("barmen")

    await expect_policy_close(ws_url(server, chat, token_for(barmen, settings)))


async def test_unknown_chat_is_closed(
    server: str, make_user: UserFactory, settings: Settings
) -> None:
    user = await make_user("user")
    ghost = User(id="ghost")

    await expect_policy_close(ws_url(server, ghost, token_for(user, settings)))


async def test_authorized_client_receives_posted_message(
    server: str,
    app: Any,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    chat = await make_user("user")
    owner_token = token_for(chat, settings)

    async with connect(ws_url(server, chat, owner_token)) as socket:
        await wait_for_subscribers(app, chat, 1)
        posted = await client.post(
            f"/v1/chats/{chat.id}/messages", json={"text": "salom"}, headers=auth_headers(chat)
        )
        received = json.loads(await asyncio.wait_for(socket.recv(), WAIT))

    assert posted.status_code == 201
    assert received["id"] == posted.json()["id"]
    assert received["text"] == "salom"
    assert received["sender_id"] == chat.id
    assert received["kind"] == "user"
    assert received["created_at"]


async def test_message_for_other_chat_is_not_delivered(
    server: str,
    app: Any,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    chat = await make_user("user")
    other = await make_user("user")

    async with connect(ws_url(server, chat, token_for(chat, settings))) as socket:
        await wait_for_subscribers(app, chat, 1)
        await client.post(
            f"/v1/chats/{other.id}/messages", json={"text": "x"}, headers=auth_headers(other)
        )
        with pytest.raises(TimeoutError):
            await asyncio.wait_for(socket.recv(), 0.3)


async def test_owner_can_listen_to_any_chat(
    server: str,
    app: Any,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    chat = await make_user("user")
    owner = await make_user("owner")

    async with connect(ws_url(server, chat, token_for(owner, settings))) as socket:
        await wait_for_subscribers(app, chat, 1)
        await client.post(
            f"/v1/chats/{chat.id}/messages", json={"text": "x"}, headers=auth_headers(owner)
        )
        received = json.loads(await asyncio.wait_for(socket.recv(), WAIT))

    assert received["sender_id"] == owner.id


async def test_client_messages_are_ignored(
    server: str, app: Any, make_user: UserFactory, settings: Settings
) -> None:
    chat = await make_user("user")

    async with connect(ws_url(server, chat, token_for(chat, settings))) as socket:
        await wait_for_subscribers(app, chat, 1)
        await socket.send("hello")
        with pytest.raises(TimeoutError):
            await asyncio.wait_for(socket.recv(), 0.3)
        assert app.state.hub.subscriber_count(chat.id) == 1


async def test_connection_closes_when_token_expires(
    server: str, app: Any, make_user: UserFactory, settings: Settings
) -> None:
    chat = await make_user("user")
    token = token_for(chat, settings, timedelta(seconds=1))

    async with connect(ws_url(server, chat, token)) as socket:
        await wait_for_subscribers(app, chat, 1)
        with pytest.raises(ConnectionClosed) as info:
            await asyncio.wait_for(socket.recv(), WAIT)

    assert info.value.rcvd is not None
    assert info.value.rcvd.code == POLICY_VIOLATION
    await wait_for_subscribers(app, chat, 0)


async def test_subscriber_is_removed_after_disconnect(
    server: str, app: Any, make_user: UserFactory, settings: Settings
) -> None:
    chat = await make_user("user")

    async with connect(ws_url(server, chat, token_for(chat, settings))):
        await wait_for_subscribers(app, chat, 1)

    await wait_for_subscribers(app, chat, 0)


async def test_multiple_clients_all_receive(
    server: str,
    app: Any,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    chat = await make_user("user")
    url = ws_url(server, chat, token_for(chat, settings))

    async with connect(url) as first, connect(url) as second:
        await wait_for_subscribers(app, chat, 2)
        await client.post(
            f"/v1/chats/{chat.id}/messages", json={"text": "hamma"}, headers=auth_headers(chat)
        )
        a = json.loads(await asyncio.wait_for(first.recv(), WAIT))
        b = json.loads(await asyncio.wait_for(second.recv(), WAIT))

    assert a["text"] == b["text"] == "hamma"
    await wait_for_subscribers(app, chat, 0)
