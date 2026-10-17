import re
import uuid

from zalpro_api.core.errors import ApiError
from zalpro_api.models import Message
from zalpro_api.models.message import MAX_CHAT_AUDIO_BYTES, MAX_CHAT_VIDEO_BYTES
from zalpro_api.models.photo import MAX_IMAGE_BYTES
from zalpro_api.schemas.chat_media import ChatMediaUploadIn
from zalpro_api.schemas.image_upload import ImageUploadOut
from zalpro_api.services.storage import Storage

IMAGE_EXTENSIONS = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}
EXTENSION_TYPES = {extension: kind for kind, extension in IMAGE_EXTENSIONS.items()}
CHAT_VIDEO_CONTENT_TYPE = "video/mp4"
CHAT_AUDIO_CONTENT_TYPE = "audio/mp4"
HEX_NAME = r"[0-9a-f]{32}"


def image_prefix(chat_uid: str) -> str:
    return f"chats/{chat_uid}/image/"


def raw_prefix(chat_uid: str) -> str:
    return f"chats/{chat_uid}/raw/"


def video_prefix(chat_uid: str) -> str:
    return f"chats/{chat_uid}/video/"


def audio_prefix(chat_uid: str) -> str:
    return f"chats/{chat_uid}/audio/"


def build_raw_key(chat_uid: str) -> str:
    return f"{raw_prefix(chat_uid)}{uuid.uuid4().hex}"


def build_video_key(chat_uid: str) -> str:
    return f"{video_prefix(chat_uid)}{uuid.uuid4().hex}.mp4"


async def create_upload(
    storage: Storage, chat_uid: str, body: ChatMediaUploadIn, expires: int
) -> ImageUploadOut:
    if body.kind == "image":
        key = f"{image_prefix(chat_uid)}{uuid.uuid4().hex}.{IMAGE_EXTENSIONS[body.content_type]}"
    elif body.kind == "audio":
        key = f"{audio_prefix(chat_uid)}{uuid.uuid4().hex}.m4a"
    else:
        key = build_raw_key(chat_uid)
    upload_url = await storage.presign_put(key, body.size, expires)
    return ImageUploadOut(key=key, upload_url=upload_url, expires_in=expires)


def key_pattern(chat_uid: str, kind: str) -> str:
    if kind == "image":
        extensions = "|".join(EXTENSION_TYPES)
        return re.escape(image_prefix(chat_uid)) + HEX_NAME + r"\.(?:" + extensions + ")"
    if kind == "audio":
        return re.escape(audio_prefix(chat_uid)) + HEX_NAME + r"\.m4a"
    return re.escape(raw_prefix(chat_uid)) + HEX_NAME


async def ensure_uploaded(storage: Storage, chat_uid: str, key: str, kind: str) -> None:
    if re.fullmatch(key_pattern(chat_uid, kind), key) is None:
        raise ApiError(422, "media_key_invalid", "Media kaliti bu chatga tegishli emas")
    size = await storage.head(key)
    if size is None:
        raise ApiError(422, "media_not_uploaded", "Media yuklanmagan")
    limit = {"image": MAX_IMAGE_BYTES, "audio": MAX_CHAT_AUDIO_BYTES}.get(
        kind, MAX_CHAT_VIDEO_BYTES
    )
    if size > limit:
        await storage.delete(key)
        raise ApiError(422, "media_too_large", "Media hajmi chegaradan katta")


async def media_url(
    storage: Storage, message: Message, image_expires: int, video_expires: int
) -> str | None:
    if message.media_key is None or message.media_status != "ready":
        return None
    if message.media_kind == "audio":
        return await storage.presign_get(message.media_key, video_expires, CHAT_AUDIO_CONTENT_TYPE)
    if message.media_kind == "video":
        return await storage.presign_get(message.media_key, video_expires, CHAT_VIDEO_CONTENT_TYPE)
    content_type = EXTENSION_TYPES.get(message.media_key.rsplit(".", 1)[-1])
    return await storage.presign_get(message.media_key, image_expires, content_type)
