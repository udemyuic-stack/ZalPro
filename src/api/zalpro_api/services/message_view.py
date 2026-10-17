from typing import Any

from zalpro_api.core.config import Settings
from zalpro_api.models import Message
from zalpro_api.schemas.message import MessageOut
from zalpro_api.services import chat_media
from zalpro_api.services.storage import Storage


def message_payload(message: Message, media_url: str | None = None) -> dict[str, Any]:
    return {
        "id": str(message.id),
        "chat_uid": message.chat_uid,
        "sender_id": message.sender_id,
        "kind": message.kind,
        "text": message.text,
        "created_at": message.created_at.isoformat(),
        "media_kind": message.media_kind,
        "media_status": message.media_status,
        "media_url": media_url,
        "media_duration_ms": message.media_duration_ms,
    }


async def message_out(storage: Storage, settings: Settings, message: Message) -> MessageOut:
    url = await chat_media.media_url(
        storage, message, settings.photo_url_seconds, settings.video_url_seconds
    )
    return MessageOut.model_validate(message).model_copy(update={"media_url": url})
