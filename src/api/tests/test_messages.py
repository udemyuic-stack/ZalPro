import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Gym, Message, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
MessageFactory = Callable[..., Awaitable[Message]]
GymFactory = Callable[..., Awaitable[Gym]]


def url(user: User) -> str:
    return f"/v1/chats/{user.id}/messages"


async def message_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Message)) or 0


@pytest.fixture
async def trainee(make_user: UserFactory) -> User:
    return await make_user("user")


async def test_self_can_read_and_post(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    created = await client.post(url(trainee), json={"text": "salom"}, headers=auth_headers(trainee))
    listed = await client.get(url(trainee), headers=auth_headers(trainee))

    assert created.status_code == 201
    assert created.json()["sender_id"] == trainee.id
    assert created.json()["kind"] == "user"
    assert created.json()["chat_uid"] == trainee.id
    assert [item["text"] for item in listed.json()] == ["salom"]


async def test_other_user_is_forbidden(
    client: AsyncClient, trainee: User, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    other = await make_user("user")

    read = await client.get(url(trainee), headers=auth_headers(other))
    write = await client.post(url(trainee), json={"text": "x"}, headers=auth_headers(other))

    assert read.status_code == 403
    assert write.status_code == 403
    assert read.json()["detail"]["code"] == "forbidden"


async def test_own_trainer_can_read_and_post(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    admin = await make_user("admin")
    student = await make_user("user", trainer_id=admin.id)

    read = await client.get(url(student), headers=auth_headers(admin))
    write = await client.post(url(student), json={"text": "yaxshi"}, headers=auth_headers(admin))

    assert read.status_code == 200
    assert write.status_code == 201
    assert write.json()["sender_id"] == admin.id


async def test_other_trainer_is_forbidden(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    admin = await make_user("admin")
    other_admin = await make_user("admin")
    student = await make_user("user", trainer_id=admin.id)

    read = await client.get(url(student), headers=auth_headers(other_admin))
    write = await client.post(url(student), json={"text": "x"}, headers=auth_headers(other_admin))

    assert read.status_code == 403
    assert write.status_code == 403


async def test_admin_of_other_gym_is_forbidden(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym_a = await make_gym()
    gym_b = await make_gym()
    admin_a = await make_user("admin", gym_id=gym_a.id)
    admin_b = await make_user("admin", gym_id=gym_b.id)
    student = await make_user("user", gym_id=gym_a.id, trainer_id=admin_a.id)

    own = await client.get(url(student), headers=auth_headers(admin_a))
    foreign = await client.get(url(student), headers=auth_headers(admin_b))
    foreign_post = await client.post(
        url(student), json={"text": "x"}, headers=auth_headers(admin_b)
    )

    assert own.status_code == 200
    assert foreign.status_code == 403
    assert foreign_post.status_code == 403


async def test_owner_can_read_and_post(
    client: AsyncClient, trainee: User, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")

    read = await client.get(url(trainee), headers=auth_headers(owner))
    write = await client.post(url(trainee), json={"text": "x"}, headers=auth_headers(owner))

    assert read.status_code == 200
    assert write.status_code == 201
    assert write.json()["sender_id"] == owner.id


async def test_barmen_is_forbidden(
    client: AsyncClient, trainee: User, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    barmen = await make_user("barmen")

    read = await client.get(url(trainee), headers=auth_headers(barmen))
    write = await client.post(url(trainee), json={"text": "x"}, headers=auth_headers(barmen))

    assert read.status_code == 403
    assert write.status_code == 403


async def test_requires_authentication(client: AsyncClient, trainee: User) -> None:
    read = await client.get(url(trainee))
    write = await client.post(url(trainee), json={"text": "x"})

    assert read.status_code == 401
    assert write.status_code == 401


async def test_unknown_chat_is_not_found(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    path = f"/v1/chats/{uuid.uuid4().hex}/messages"

    read = await client.get(path, headers=auth_headers(trainee))
    write = await client.post(path, json={"text": "x"}, headers=auth_headers(trainee))

    assert read.status_code == 404
    assert write.status_code == 404


@pytest.mark.parametrize("text", ["", "   ", "\n\t "])
async def test_blank_text_is_rejected(
    client: AsyncClient,
    db_session: AsyncSession,
    trainee: User,
    auth_headers: HeadersFactory,
    text: str,
) -> None:
    response = await client.post(url(trainee), json={"text": text}, headers=auth_headers(trainee))

    assert response.status_code == 422
    assert await message_count(db_session) == 0


async def test_text_length_boundaries(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    too_long = await client.post(
        url(trainee), json={"text": "a" * 2001}, headers=auth_headers(trainee)
    )
    longest = await client.post(
        url(trainee), json={"text": "a" * 2000}, headers=auth_headers(trainee)
    )

    assert too_long.status_code == 422
    assert longest.status_code == 201


async def test_text_is_stripped(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        url(trainee), json={"text": "  salom  "}, headers=auth_headers(trainee)
    )

    assert response.json()["text"] == "salom"


@pytest.mark.parametrize("extra", [{"sender_id": "x"}, {"kind": "system"}, {"chat_uid": "x"}])
async def test_extra_fields_are_rejected(
    client: AsyncClient,
    db_session: AsyncSession,
    trainee: User,
    auth_headers: HeadersFactory,
    extra: dict[str, Any],
) -> None:
    response = await client.post(
        url(trainee), json={"text": "x", **extra}, headers=auth_headers(trainee)
    )

    assert response.status_code == 422
    assert await message_count(db_session) == 0


async def test_missing_text_is_rejected(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(url(trainee), json={}, headers=auth_headers(trainee))

    assert response.status_code == 422


@pytest.mark.parametrize("method", ["PATCH", "PUT", "DELETE"])
async def test_messages_cannot_be_edited_or_deleted(
    client: AsyncClient,
    trainee: User,
    make_message: MessageFactory,
    auth_headers: HeadersFactory,
    method: str,
) -> None:
    message = await make_message(trainee.id)

    collection = await client.request(
        method, url(trainee), json={"text": "x"}, headers=auth_headers(trainee)
    )
    item = await client.request(
        method, f"{url(trainee)}/{message.id}", json={"text": "x"}, headers=auth_headers(trainee)
    )

    assert collection.status_code in (404, 405)
    assert item.status_code in (404, 405)


async def test_list_is_newest_first_with_id_tie_break(
    client: AsyncClient,
    trainee: User,
    make_message: MessageFactory,
    auth_headers: HeadersFactory,
) -> None:
    base = datetime(2026, 10, 1, tzinfo=UTC)
    first = await make_message(trainee.id, text="1", created_at=base)
    second = await make_message(trainee.id, text="2", created_at=base + timedelta(minutes=1))
    tie_a = await make_message(trainee.id, text="3", created_at=base + timedelta(minutes=2))
    tie_b = await make_message(trainee.id, text="4", created_at=base + timedelta(minutes=2))

    response = await client.get(url(trainee), headers=auth_headers(trainee))

    tied = sorted([tie_a, tie_b], key=lambda item: item.id, reverse=True)
    expected = [str(item.id) for item in tied] + [str(second.id), str(first.id)]
    assert [item["id"] for item in response.json()] == expected


async def test_list_only_returns_requested_chat(
    client: AsyncClient,
    trainee: User,
    make_user: UserFactory,
    make_message: MessageFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user("user")
    await make_message(other.id, text="begona")
    await make_message(trainee.id, text="o'zimniki")

    response = await client.get(url(trainee), headers=auth_headers(trainee))

    assert [item["text"] for item in response.json()] == ["o'zimniki"]


async def test_limit_restricts_result(
    client: AsyncClient,
    trainee: User,
    make_message: MessageFactory,
    auth_headers: HeadersFactory,
) -> None:
    base = datetime(2026, 10, 1, tzinfo=UTC)
    for index in range(5):
        await make_message(trainee.id, text=str(index), created_at=base + timedelta(minutes=index))

    response = await client.get(url(trainee), params={"limit": 2}, headers=auth_headers(trainee))

    assert [item["text"] for item in response.json()] == ["4", "3"]


async def test_default_limit_is_fifty(
    client: AsyncClient,
    trainee: User,
    make_message: MessageFactory,
    auth_headers: HeadersFactory,
) -> None:
    base = datetime(2026, 10, 1, tzinfo=UTC)
    for index in range(51):
        await make_message(trainee.id, text=str(index), created_at=base + timedelta(seconds=index))

    response = await client.get(url(trainee), headers=auth_headers(trainee))

    assert len(response.json()) == 50


async def test_before_returns_older_messages_only(
    client: AsyncClient,
    trainee: User,
    make_message: MessageFactory,
    auth_headers: HeadersFactory,
) -> None:
    base = datetime(2026, 10, 1, tzinfo=UTC)
    for index in range(4):
        await make_message(trainee.id, text=str(index), created_at=base + timedelta(minutes=index))
    cursor = (base + timedelta(minutes=2)).isoformat()

    response = await client.get(
        url(trainee), params={"before": cursor}, headers=auth_headers(trainee)
    )

    assert [item["text"] for item in response.json()] == ["1", "0"]


async def test_before_without_timezone_is_rejected(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(
        url(trainee), params={"before": "2026-10-01T00:00:00"}, headers=auth_headers(trainee)
    )

    assert response.status_code == 422


@pytest.mark.parametrize("limit", [0, 201, -1])
async def test_invalid_limit_is_rejected(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory, limit: int
) -> None:
    response = await client.get(
        url(trainee), params={"limit": limit}, headers=auth_headers(trainee)
    )

    assert response.status_code == 422


async def test_maximum_limit_is_accepted(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(url(trainee), params={"limit": 200}, headers=auth_headers(trainee))

    assert response.status_code == 200


async def test_response_shape(
    client: AsyncClient,
    trainee: User,
    make_message: MessageFactory,
    auth_headers: HeadersFactory,
) -> None:
    await make_message(trainee.id, kind="system", sender_id="other")

    response = await client.get(url(trainee), headers=auth_headers(trainee))

    item = response.json()[0]
    assert set(item) == {
        "id",
        "chat_uid",
        "sender_id",
        "kind",
        "text",
        "created_at",
        "media_kind",
        "media_status",
        "media_duration_ms",
        "media_url",
    }
    assert item["kind"] == "system"
    assert item["sender_id"] == "other"
