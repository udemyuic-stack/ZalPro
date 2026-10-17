import re
import uuid
from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient

from tests.conftest import FakeStorage
from zalpro_api.models import User
from zalpro_api.models.message import MAX_CHAT_AUDIO_BYTES

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]


def messages_url(chat: User) -> str:
    return f"/v1/chats/{chat.id}/messages"


def upload_url(chat: User) -> str:
    return f"/v1/chats/{chat.id}/media/upload-url"


def audio_key(chat: User) -> str:
    return f"chats/{chat.id}/audio/{uuid.uuid4().hex}.m4a"


@pytest.fixture
async def trainee(make_user: UserFactory) -> User:
    return await make_user("user")


async def test_upload_url_for_audio_uses_audio_prefix(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        upload_url(trainee),
        headers=auth_headers(trainee),
        json={"kind": "audio", "content_type": "audio/mp4", "size": 1000},
    )

    assert response.status_code == 201
    assert re.fullmatch(rf"chats/{trainee.id}/audio/[0-9a-f]{{32}}\.m4a", response.json()["key"])
    assert storage.put_calls == [(response.json()["key"], 1000)]


@pytest.mark.parametrize(
    "payload",
    [
        {"kind": "audio", "content_type": "audio/mpeg", "size": 1000},
        {"kind": "audio", "content_type": "audio/wav", "size": 1000},
        {"kind": "audio", "content_type": "video/mp4", "size": 1000},
        {"kind": "video", "content_type": "audio/mp4", "size": 1000},
        {"kind": "audio", "content_type": "audio/mp4", "size": MAX_CHAT_AUDIO_BYTES + 1},
        {"kind": "audio", "content_type": "audio/mp4", "size": 0},
    ],
)
async def test_upload_url_rejects_invalid_audio(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    response = await client.post(upload_url(trainee), headers=auth_headers(trainee), json=payload)

    assert response.status_code == 422
    assert storage.put_calls == []


async def test_audio_message_is_ready_with_url_and_duration(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    key = audio_key(trainee)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "audio", "media_duration_ms": 4200},
    )

    body = response.json()
    assert response.status_code == 201
    assert body["text"] == ""
    assert body["media_kind"] == "audio"
    assert body["media_status"] == "ready"
    assert body["media_duration_ms"] == 4200
    assert key in body["media_url"]
    assert "type=audio/mp4" in body["media_url"]

    listing = await client.get(messages_url(trainee), headers=auth_headers(trainee))
    assert listing.json()[0]["media_duration_ms"] == 4200
    assert key in listing.json()[0]["media_url"]


@pytest.mark.parametrize("duration", [0, -1, 300_001, "5", True, 1.5, None])
async def test_audio_message_rejects_bad_duration(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    auth_headers: HeadersFactory,
    duration: Any,
) -> None:
    key = audio_key(trainee)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "audio", "media_duration_ms": duration},
    )

    assert response.status_code == 422


async def test_duration_without_audio_is_rejected(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    key = f"chats/{trainee.id}/image/{uuid.uuid4().hex}.jpg"
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "image", "media_duration_ms": 1000},
    )

    assert response.status_code == 422


async def test_audio_foreign_chat_key_is_rejected(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user("user")
    key = audio_key(other)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "audio", "media_duration_ms": 1000},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "media_key_invalid"


async def test_audio_missing_object_is_rejected(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": audio_key(trainee), "media_kind": "audio", "media_duration_ms": 1000},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "media_not_uploaded"


async def test_audio_oversized_object_is_rejected_and_deleted(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    key = audio_key(trainee)
    storage.objects[key] = MAX_CHAT_AUDIO_BYTES + 1

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "audio", "media_duration_ms": 1000},
    )

    assert response.status_code == 422
    assert storage.deleted == [key]


async def test_stranger_cannot_post_or_read_audio(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user("user")
    key = audio_key(trainee)
    storage.objects[key] = 1000
    body = {"media_key": key, "media_kind": "audio", "media_duration_ms": 1000}

    posted = await client.post(messages_url(trainee), headers=auth_headers(other), json=body)
    read = await client.get(messages_url(trainee), headers=auth_headers(other))

    assert posted.status_code == 403
    assert read.status_code == 403


async def test_trainer_and_trainerless_students_exchange_audio(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    trainer = await make_user("admin")
    with_trainer = await make_user("user", trainer_id=trainer.id)
    alone = await make_user("user")

    for student in (with_trainer, alone):
        key = audio_key(student)
        storage.objects[key] = 1000
        body = {"media_key": key, "media_kind": "audio", "media_duration_ms": 2000}
        sent = await client.post(messages_url(student), headers=auth_headers(student), json=body)
        assert sent.status_code == 201

    key = audio_key(with_trainer)
    storage.objects[key] = 1000
    reply = await client.post(
        messages_url(with_trainer),
        headers=auth_headers(trainer),
        json={"media_key": key, "media_kind": "audio", "media_duration_ms": 3000},
    )
    assert reply.status_code == 201
    seen = await client.get(messages_url(with_trainer), headers=auth_headers(with_trainer))
    assert [m["media_duration_ms"] for m in seen.json()] == [3000, 2000]
