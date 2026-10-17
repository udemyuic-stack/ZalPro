from typing import Annotated, Literal

from pydantic import Field

from zalpro_api.models.photo import MAX_IMAGE_BYTES
from zalpro_api.models.product import MAX_PRODUCT_IMAGES
from zalpro_api.schemas.base import OutModel, StrictModel

ImageContentType = Literal["image/jpeg", "image/png", "image/webp"]
ImageKey = Annotated[str, Field(min_length=1, max_length=200)]


class ImageUploadIn(StrictModel):
    size: int = Field(strict=True, ge=1, le=MAX_IMAGE_BYTES)
    content_type: ImageContentType


class ImageUploadOut(OutModel):
    key: str
    upload_url: str
    expires_in: int


class ImageConfirmIn(StrictModel):
    key: ImageKey


class ImagesConfirmIn(StrictModel):
    keys: list[ImageKey] = Field(max_length=MAX_PRODUCT_IMAGES)
