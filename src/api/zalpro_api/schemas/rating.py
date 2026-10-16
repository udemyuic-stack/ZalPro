from datetime import datetime

from pydantic import Field

from zalpro_api.schemas.base import OutModel, StrictModel


class RatingIn(StrictModel):
    stars: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


class RatingOut(OutModel):
    trainer_id: str
    stars: int
    comment: str
    updated_at: datetime
