import uuid
from typing import Annotated, Literal, Self

from pydantic import AwareDatetime, Field, StringConstraints, model_validator

from zalpro_api.models.message import MAX_CHAT_AUDIO_MS
from zalpro_api.schemas.base import OutModel, StrictModel

MAX_MESSAGE_LENGTH = 2000
DEFAULT_MESSAGES_LIMIT = 50
MAX_MESSAGES_LIMIT = 200

MessageText = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_MESSAGE_LENGTH)
]
MediaKindName = Literal["image", "video", "audio"]
MediaStatusName = Literal["processing", "ready", "failed"]
MediaKey = Annotated[str, Field(min_length=1, max_length=200)]


class MessageIn(StrictModel):
    text: MessageText | None = None
    media_key: MediaKey | None = None
    media_kind: MediaKindName | None = None
    media_duration_ms: int | None = Field(default=None, strict=True, ge=1, le=MAX_CHAT_AUDIO_MS)

    @model_validator(mode="after")
    def check_content(self) -> Self:
        if (self.media_key is None) != (self.media_kind is None):
            raise ValueError("media_key va media_kind birga berilishi kerak")
        if (self.media_kind == "audio") != (self.media_duration_ms is not None):
            raise ValueError("media_duration_ms faqat audio uchun va majburiy")
        if self.text is None and self.media_key is None:
            raise ValueError("Xabar matni yoki media kerak")
        return self


class MessageOut(OutModel):
    id: uuid.UUID
    chat_uid: str
    sender_id: str
    kind: str
    text: str
    created_at: AwareDatetime
    media_kind: MediaKindName | None = None
    media_status: MediaStatusName | None = None
    media_url: str | None = None
    media_duration_ms: int | None = None
