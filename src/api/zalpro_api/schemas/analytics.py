from typing import Self

from pydantic import Field, model_validator

from zalpro_api.schemas.base import OutModel
from zalpro_api.schemas.day import DayRange

MAX_ANALYTICS_DAYS = 366


class AnalyticsRange(DayRange):
    @model_validator(mode="after")
    def check_analytics_span(self) -> Self:
        if (self.to - self.from_).days + 1 > MAX_ANALYTICS_DAYS:
            raise ValueError(f"Oraliq {MAX_ANALYTICS_DAYS} kundan oshmasligi kerak")
        return self


class ShopTotalsOut(OutModel):
    orders: int
    units: int
    revenue: int
    profit: int
    no_cost_orders: int


class TopProductOut(OutModel):
    product_id: str
    name: str
    category: str
    currency: str
    units: int
    revenue: int
    profit: int


class WeekdaySalesOut(OutModel):
    weekday: int
    currency: str
    orders: int
    revenue: int


class ShopAnalyticsOut(OutModel):
    from_: str = Field(serialization_alias="from")
    to: str
    totals: dict[str, ShopTotalsOut]
    top_products: list[TopProductOut]
    by_weekday: list[WeekdaySalesOut]


class ChurnItemOut(OutModel):
    user_id: str
    name: str
    phone: str
    trainer_id: str | None
    trainer_name: str
    reasons: list[str]
    score: int
    last_visit: str | None
    visits_last14: int
    visits_prev14: int
    expires_at: str | None


class ChurnOut(OutModel):
    as_of: str
    items: list[ChurnItemOut]


class RetentionSplitOut(OutModel):
    eligible: int
    retained: int


class RetentionCohortOut(OutModel):
    day: int
    eligible: int
    retained: int
    rate: float | None
    with_trainer: RetentionSplitOut
    without_trainer: RetentionSplitOut


class RetentionOut(OutModel):
    from_: str = Field(serialization_alias="from")
    to: str
    cohorts: list[RetentionCohortOut]


class TrainerRowOut(OutModel):
    trainer_id: str | None
    name: str
    students: int
    active_students: int
    visits_per_student_week: float
    feedback_count: int
    hard_count: int
    hard_share: float | None


class TrainersOut(OutModel):
    from_: str = Field(serialization_alias="from")
    to: str
    rows: list[TrainerRowOut]
