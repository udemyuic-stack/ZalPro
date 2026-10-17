from typing import Literal

from pydantic import Field

from zalpro_api.models.exercise import MAX_VIDEO_BYTES
from zalpro_api.schemas.base import OutModel, StrictModel

VideoContentType = Literal["video/mp4", "video/quicktime", "video/webm"]
VideoStatus = Literal["processing", "ready", "failed"]


class VideoUploadIn(StrictModel):
    size: int = Field(strict=True, ge=1, le=MAX_VIDEO_BYTES)
    content_type: VideoContentType = "video/mp4"


class VideoUploadOut(OutModel):
    key: str
    upload_url: str
    expires_in: int


class VideoConfirmIn(StrictModel):
    key: str = Field(min_length=1, max_length=200)


class VideoConfirmOut(OutModel):
    status: VideoStatus


class VideoUrlOut(OutModel):
    status: VideoStatus | None
    url: str | None
    expires_in: int | None
