import uuid

from pydantic import AwareDatetime, Field

from zalpro_api.schemas.base import OutModel, StrictModel

MAX_WEIGHT = 500
MAX_WEIGHTS_LIMIT = 500


class WeightIn(StrictModel):
    weight: float = Field(gt=0, le=MAX_WEIGHT, allow_inf_nan=False)


class WeightOut(OutModel):
    id: uuid.UUID
    date: AwareDatetime
    weight: float
