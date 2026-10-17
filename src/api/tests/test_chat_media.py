import re
import uuid
from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import FakeStorage
from zalpro_api.models import Message, User
from zalpro_api.models.message import MAX_CHAT_VIDEO_BYTES
from zalpro_api.models.photo import MAX_IMAGE_BYTES

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
MessageFactory = Callable[..., Awaitable[Message]]


def messages_url(chat: User) -> str:
    return f"/v1/chats/{chat.id}/messages"


def upload_url(chat: User) -> str:
    return f"/v1/chats/{chat.id}/media/upload-url"


def image_key(chat: User) -> str:
    return f"chats/{chat.id}/image/{uuid.uuid4().hex}.jpg"


def raw_key(chat: User) -> str:
    return f"chats/{chat.id}/raw/{uuid.uuid4().hex}"


@pytest.fixture
async def trainee(make_user: UserFactory) -> User:
    return await make_user("user")


async def failing_transcode(source: Any, target: Any) -> None:
    raise RuntimeError("boom")


async def test_upload_url_for_image_uses_chat_prefix(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        upload_url(trainee),
        headers=auth_headers(trainee),
        json={"kind": "image", "content_type": "image/png", "size": 1000},
    )

    assert response.status_code == 201
    assert re.fullmatch(rf"chats/{trainee.id}/image/[0-9a-f]{{32}}\.png", response.json()["key"])
    assert storage.put_calls == [(response.json()["key"], 1000)]


async def test_upload_url_for_video_uses_raw_prefix(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        upload_url(trainee),
        headers=auth_headers(trainee),
        json={"kind": "video", "content_type": "video/quicktime", "size": 9_000_000},
    )

    assert response.status_code == 201
    assert re.fullmatch(rf"chats/{trainee.id}/raw/[0-9a-f]{{32}}", response.json()["key"])


@pytest.mark.parametrize(
    "payload",
    [
        {"kind": "image", "content_type": "video/mp4", "size": 10},
        {"kind": "video", "content_type": "image/png", "size": 10},
        {"kind": "image", "content_type": "image/gif", "size": 10},
        {"kind": "image", "content_type": "image/png", "size": MAX_IMAGE_BYTES + 1},
        {"kind": "video", "content_type": "video/mp4", "size": MAX_CHAT_VIDEO_BYTES + 1},
        {"kind": "video", "content_type": "video/mp4", "size": 0},
    ],
)
async def test_upload_url_rejects_invalid_requests(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    response = await client.post(upload_url(trainee), headers=auth_headers(trainee), json=payload)

    assert response.status_code == 422
    assert storage.put_calls == []


async def test_upload_url_forbidden_for_other_user(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user("user")

    response = await client.post(
        upload_url(trainee),
        headers=auth_headers(other),
        json={"kind": "image", "content_type": "image/png", "size": 10},
    )

    assert response.status_code == 403
    assert storage.put_calls == []


async def test_image_message_is_ready_with_url(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    key = image_key(trainee)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "image"},
    )

    body = response.json()
    assert response.status_code == 201
    assert body["text"] == ""
    assert body["media_kind"] == "image"
    assert body["media_status"] == "ready"
    assert key in body["media_url"]
    assert "type=image/jpeg" in body["media_url"]


async def test_image_message_keeps_caption(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    key = image_key(trainee)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"text": "mana", "media_key": key, "media_kind": "image"},
    )

    assert response.json()["text"] == "mana"


async def test_video_message_processes_then_becomes_ready(
    client: AsyncClient,
    storage: FakeStorage,
    video_worker: Any,
    trainee: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    key = raw_key(trainee)
    storage.objects[key] = 1000

    created = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "video"},
    )
    await video_worker.join()
    listed = await client.get(messages_url(trainee), headers=auth_headers(trainee))

    assert created.status_code == 201
    assert created.json()["media_status"] == "processing"
    assert created.json()["media_url"] is None
    item = listed.json()[0]
    assert item["media_status"] == "ready"
    assert re.search(rf"chats/{trainee.id}/video/[0-9a-f]{{32}}\.mp4", item["media_url"])
    assert "type=video/mp4" in item["media_url"]
    assert storage.deleted == [key]
    assert len(storage.uploads) == 1


async def test_video_ready_publishes_updated_payload(
    app: Any,
    client: AsyncClient,
    storage: FakeStorage,
    video_worker: Any,
    trainee: User,
    auth_headers: HeadersFactory,
) -> None:
    key = raw_key(trainee)
    storage.objects[key] = 1000
    queue = app.state.hub.subscribe(trainee.id)

    created = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "video"},
    )
    await video_worker.join()

    first = queue.get_nowait()
    second = queue.get_nowait()
    assert first["id"] == created.json()["id"]
    assert first["media_status"] == "processing"
    assert "updated" not in first
    assert second["id"] == created.json()["id"]
    assert second["updated"] is True
    assert second["media_status"] == "ready"
    assert second["media_url"] is not None


async def test_failed_transcode_marks_message_failed_and_publishes(
    app: Any,
    client: AsyncClient,
    storage: FakeStorage,
    video_worker: Any,
    trainee: User,
    auth_headers: HeadersFactory,
) -> None:
    video_worker.transcode = failing_transcode
    key = raw_key(trainee)
    storage.objects[key] = 1000
    queue = app.state.hub.subscribe(trainee.id)

    await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "video"},
    )
    await video_worker.join()
    listed = await client.get(messages_url(trainee), headers=auth_headers(trainee))

    queue.get_nowait()
    updated = queue.get_nowait()
    assert updated["media_status"] == "failed"
    assert updated["updated"] is True
    assert listed.json()[0]["media_status"] == "failed"
    assert listed.json()[0]["media_url"] is None
    assert storage.deleted == [key]


async def test_foreign_chat_key_is_rejected(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user("user")
    key = image_key(other)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "image"},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "media_key_invalid"


async def test_kind_mismatch_is_rejected(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    key = image_key(trainee)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": "video"},
    )

    assert response.json()["detail"]["code"] == "media_key_invalid"


async def test_missing_object_is_rejected(
    client: AsyncClient, storage: FakeStorage, trainee: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": image_key(trainee), "media_kind": "image"},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "media_not_uploaded"


@pytest.mark.parametrize(
    ("kind", "size"),
    [("image", MAX_IMAGE_BYTES + 1), ("video", MAX_CHAT_VIDEO_BYTES + 1)],
)
async def test_oversized_object_is_rejected_and_deleted(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    kind: str,
    size: int,
) -> None:
    key = image_key(trainee) if kind == "image" else raw_key(trainee)
    storage.objects[key] = size

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(trainee),
        json={"media_key": key, "media_kind": kind},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "media_too_large"
    assert storage.deleted == [key]


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"text": "   "},
        {"media_key": "x"},
        {"media_kind": "image"},
        {"text": "a", "media_key": "x", "media_kind": "audio"},
    ],
)
async def test_invalid_message_bodies_are_rejected(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    response = await client.post(messages_url(trainee), headers=auth_headers(trainee), json=payload)

    assert response.status_code == 422


async def test_other_user_cannot_post_media(
    client: AsyncClient,
    storage: FakeStorage,
    trainee: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user("user")
    key = image_key(trainee)
    storage.objects[key] = 1000

    response = await client.post(
        messages_url(trainee),
        headers=auth_headers(other),
        json={"media_key": key, "media_kind": "image"},
    )

    assert response.status_code == 403


async def test_plain_text_messages_still_work(
    client: AsyncClient, trainee: User, auth_headers: HeadersFactory
) -> None:
    created = await client.post(
        messages_url(trainee), headers=auth_headers(trainee), json={"text": "salom"}
    )

    assert created.status_code == 201
    assert created.json()["media_kind"] is None
    assert created.json()["media_status"] is None
    assert created.json()["media_url"] is None


async def test_recover_requeues_processing_videos_with_raw(
    app: Any,
    storage: FakeStorage,
    video_worker: Any,
    trainee: User,
    make_message: MessageFactory,
    db_session: AsyncSession,
) -> None:
    key = raw_key(trainee)
    storage.objects[key] = 1000
    message = await make_message(
        trainee.id, text="", media_key=key, media_kind="video", media_status="processing"
    )

    await video_worker.recover()
    await video_worker.join()
    await db_session.refresh(message)

    assert message.media_status == "ready"
    assert message.media_key != key


async def test_recover_fails_processing_video_without_raw(
    storage: FakeStorage,
    video_worker: Any,
    trainee: User,
    make_message: MessageFactory,
    db_session: AsyncSession,
) -> None:
    message = await make_message(
        trainee.id,
        text="",
        media_key=raw_key(trainee),
        media_kind="video",
        media_status="processing",
    )

    await video_worker.recover()
    await db_session.refresh(message)

    assert message.media_status == "failed"


async def test_deleted_message_discards_transcode_result(
    storage: FakeStorage,
    video_worker: Any,
    trainee: User,
    make_message: MessageFactory,
    db_session: AsyncSession,
) -> None:
    from zalpro_api.services.video_transcode import VideoJob

    key = raw_key(trainee)
    storage.objects[key] = 1000
    message = await make_message(
        trainee.id, text="", media_key=key, media_kind="video", media_status="processing"
    )
    message_id = str(message.id)
    await db_session.delete(message)
    await db_session.commit()

    video_worker.enqueue(VideoJob(message_id, key, "message"))
    await video_worker.join()

    assert storage.uploads == {}
    assert storage.deleted == [key]
