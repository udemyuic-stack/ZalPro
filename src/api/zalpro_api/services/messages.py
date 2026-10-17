import uuid
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.models import Message
from zalpro_api.schemas.message import MessageIn, MessageOut
from zalpro_api.services import chat_media
from zalpro_api.services.chat_hub import ChatHub
from zalpro_api.services.message_view import message_out, message_payload
from zalpro_api.services.storage import Storage
from zalpro_api.services.video_transcode import VideoJob, VideoWorker

STAGED_KEY = "staged_messages"


async def stage_message(
    session: AsyncSession, chat_uid: str, sender_id: str, text: str, kind: str = "user"
) -> Message:
    message = Message(id=uuid.uuid4(), chat_uid=chat_uid, sender_id=sender_id, text=text, kind=kind)
    session.add(message)
    await session.flush()
    await session.refresh(message)
    session.info.setdefault(STAGED_KEY, []).append(message_payload(message))
    return message


def publish_staged(session: AsyncSession, hub: ChatHub) -> None:
    for payload in session.info.pop(STAGED_KEY, []):
        hub.publish(payload["chat_uid"], payload)


async def list_messages_out(
    session: AsyncSession,
    storage: Storage,
    settings: Settings,
    chat_uid: str,
    limit: int,
    before: datetime | None,
) -> list[MessageOut]:
    messages = await list_messages(session, chat_uid, limit, before)
    return [await message_out(storage, settings, message) for message in messages]


async def list_messages(
    session: AsyncSession, chat_uid: str, limit: int, before: datetime | None
) -> list[Message]:
    statement = select(Message).where(Message.chat_uid == chat_uid)
    if before is not None:
        statement = statement.where(Message.created_at < before)
    statement = statement.order_by(Message.created_at.desc(), Message.id.desc()).limit(limit)
    return list((await session.scalars(statement)).all())


async def post_message(
    session: AsyncSession,
    hub: ChatHub,
    storage: Storage,
    settings: Settings,
    worker: VideoWorker,
    chat_uid: str,
    sender_id: str,
    body: MessageIn,
) -> MessageOut:
    media_status = None
    if body.media_key is not None and body.media_kind is not None:
        await chat_media.ensure_uploaded(storage, chat_uid, body.media_key, body.media_kind)
        media_status = "processing" if body.media_kind == "video" else "ready"
    message = Message(
        id=uuid.uuid4(),
        chat_uid=chat_uid,
        sender_id=sender_id,
        kind="user",
        text=body.text or "",
        media_key=body.media_key,
        media_kind=body.media_kind,
        media_duration_ms=body.media_duration_ms,
        media_status=media_status,
    )
    session.add(message)
    await session.commit()
    await session.refresh(message)
    out = await message_out(storage, settings, message)
    if media_status == "processing" and body.media_key is not None:
        worker.enqueue(VideoJob(str(message.id), body.media_key, "message"))
    hub.publish(chat_uid, message_payload(message, out.media_url))
    return out
