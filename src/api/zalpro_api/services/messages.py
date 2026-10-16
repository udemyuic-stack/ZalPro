import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Message
from zalpro_api.services.chat_hub import ChatHub

STAGED_KEY = "staged_messages"


def message_payload(message: Message) -> dict[str, Any]:
    return {
        "id": str(message.id),
        "chat_uid": message.chat_uid,
        "sender_id": message.sender_id,
        "kind": message.kind,
        "text": message.text,
        "created_at": message.created_at.isoformat(),
    }


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


async def list_messages(
    session: AsyncSession, chat_uid: str, limit: int, before: datetime | None
) -> list[Message]:
    statement = select(Message).where(Message.chat_uid == chat_uid)
    if before is not None:
        statement = statement.where(Message.created_at < before)
    statement = statement.order_by(Message.created_at.desc(), Message.id.desc()).limit(limit)
    return list((await session.scalars(statement)).all())


async def post_message(
    session: AsyncSession, hub: ChatHub, chat_uid: str, sender_id: str, text: str
) -> Message:
    message = await stage_message(session, chat_uid, sender_id, text, kind="user")
    await session.commit()
    publish_staged(session, hub)
    return message
