from typing import Literal, Self

from pydantic import Field, model_validator

from zalpro_api.models.message import MAX_CHAT_AUDIO_BYTES, MAX_CHAT_VIDEO_BYTES
from zalpro_api.models.photo import MAX_IMAGE_BYTES
from zalpro_api.schemas.base import StrictModel
from zalpro_api.schemas.message import MediaKindName

ChatMediaContentType = Literal[
    "image/jpeg",
    "image/png",
    "image/webp",
    "video/mp4",
    "video/quicktime",
    "video/webm",
    "audio/mp4",
]


class ChatMediaUploadIn(StrictModel):
    kind: MediaKindName
    content_type: ChatMediaContentType
    size: int = Field(strict=True, ge=1, le=MAX_CHAT_VIDEO_BYTES)

    @model_validator(mode="after")
    def check_kind(self) -> Self:
        if not self.content_type.startswith(self.kind + "/"):
            raise ValueError("content_type media turiga mos emas")
        if self.kind == "image" and self.size > MAX_IMAGE_BYTES:
            raise ValueError("Rasm hajmi chegaradan katta")
        if self.kind == "audio" and self.size > MAX_CHAT_AUDIO_BYTES:
            raise ValueError("Audio hajmi chegaradan katta")
        return self
