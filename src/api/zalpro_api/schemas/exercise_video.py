from pydantic import Field

from zalpro_api.models.exercise import MAX_VIDEO_BYTES
from zalpro_api.schemas.base import OutModel, StrictModel


class VideoUploadIn(StrictModel):
    size: int = Field(strict=True, ge=1, le=MAX_VIDEO_BYTES)


class VideoUploadOut(OutModel):
    key: str
    upload_url: str
    expires_in: int


class VideoConfirmIn(StrictModel):
    key: str = Field(min_length=1, max_length=200)


class VideoUrlOut(OutModel):
    url: str
    expires_in: int
