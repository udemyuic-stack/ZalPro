import re
from datetime import UTC, date, datetime, timedelta
from typing import Annotated, Self

from pydantic import AfterValidator, BeforeValidator, Field, field_validator, model_validator

from zalpro_api.schemas.base import OutModel, StrictModel

MIN_DAY = date(2020, 1, 1)
MAX_DAY_AHEAD = timedelta(days=2)
MAX_RANGE_DAYS = 400
MAX_MEAL_INDEX = 49
MAX_EXTRAS = 50
MAX_GYM_DONE = 100
MAX_WATER = 30
MAX_EXTRA_AT = 9_007_199_254_740_991
ISO_DAY_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def parse_iso_day(value: object) -> object:
    if isinstance(value, str):
        if not ISO_DAY_PATTERN.match(value):
            raise ValueError("Sana YYYY-MM-DD ko'rinishida bo'lishi kerak")
        return date.fromisoformat(value)
    return value


def check_day_window(value: date) -> date:
    latest = datetime.now(UTC).date() + MAX_DAY_AHEAD
    if not MIN_DAY <= value <= latest:
        raise ValueError("Sana ruxsat etilgan oraliqdan tashqarida")
    return value


IsoDay = Annotated[date, BeforeValidator(parse_iso_day)]
WritableDay = Annotated[IsoDay, AfterValidator(check_day_window)]
ExtraName = Annotated[str, Field(min_length=1, max_length=80)]
NonNegative = Annotated[float, Field(ge=0, allow_inf_nan=False)]


class ExtraIn(StrictModel):
    name: ExtraName
    grams: NonNegative
    kcal: NonNegative
    protein: NonNegative
    at: int = Field(ge=0, le=MAX_EXTRA_AT)


class ExtraOut(OutModel):
    name: str
    grams: float
    kcal: float
    protein: float
    at: int


class MealMark(StrictModel):
    done: bool


class ExerciseMark(StrictModel):
    done: bool


class WaterIn(StrictModel):
    glasses: int = Field(ge=0, le=MAX_WATER)


class OptionalDayRange(StrictModel):
    from_: IsoDay | None = Field(default=None, alias="from")
    to: IsoDay | None = None

    @model_validator(mode="after")
    def check_order_and_span(self) -> Self:
        if self.from_ is None or self.to is None:
            return self
        if self.from_ > self.to:
            raise ValueError("'from' 'to' dan katta bo'lmasligi kerak")
        if (self.to - self.from_).days + 1 > MAX_RANGE_DAYS:
            raise ValueError(f"Oraliq {MAX_RANGE_DAYS} kundan oshmasligi kerak")
        return self


class DayRange(StrictModel):
    from_: IsoDay = Field(alias="from")
    to: IsoDay

    @model_validator(mode="after")
    def check_order_and_span(self) -> Self:
        if self.from_ > self.to:
            raise ValueError("'from' 'to' dan katta bo'lmasligi kerak")
        if (self.to - self.from_).days + 1 > MAX_RANGE_DAYS:
            raise ValueError(f"Oraliq {MAX_RANGE_DAYS} kundan oshmasligi kerak")
        return self


class DayOut(OutModel):
    day: date
    done: list[int]
    extras: list[ExtraOut]
    gym_started: bool
    gym_done: list[str]
    water: int

    @field_validator("extras")
    @classmethod
    def sort_extras(cls, value: list[ExtraOut]) -> list[ExtraOut]:
        return sorted(value, key=lambda extra: extra.at)
