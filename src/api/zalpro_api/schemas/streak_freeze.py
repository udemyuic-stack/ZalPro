from datetime import date

from pydantic import field_validator

from zalpro_api.schemas.base import OutModel, StrictModel
from zalpro_api.schemas.day import IsoDay


class StreakFreezeIn(StrictModel):
    week_start: IsoDay

    @field_validator("week_start")
    @classmethod
    def check_monday(cls, value: date) -> date:
        if value.weekday() != 0:
            raise ValueError("week_start dushanba bo'lishi kerak")
        return value


class StreakFreezeOut(OutModel):
    week_start: date
    granted_by: str | None = None
