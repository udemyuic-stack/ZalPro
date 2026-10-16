import uuid

from pydantic import AwareDatetime, Field

from zalpro_api.models.photo import MAX_PHOTO_BYTES, MAX_PHOTO_WEIGHT
from zalpro_api.schemas.base import OutModel, StrictModel


class PhotoUploadIn(StrictModel):
    weight: float = Field(strict=True, gt=0, le=MAX_PHOTO_WEIGHT, allow_inf_nan=False)
    size: int = Field(strict=True, ge=1, le=MAX_PHOTO_BYTES)


class PhotoUploadOut(OutModel):
    photo_id: uuid.UUID
    upload_url: str
    expires_in: int


class PhotoOut(OutModel):
    id: uuid.UUID
    taken_at: AwareDatetime
    weight: float
    size: int
    download_url: str
