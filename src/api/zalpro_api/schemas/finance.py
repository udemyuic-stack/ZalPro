import re
from typing import Self

from pydantic import Field, model_validator

from zalpro_api.schemas.base import OutModel, StrictModel
from zalpro_api.schemas.subscription import MAX_YEAR, MIN_YEAR

MAX_GYM_ID_LENGTH = 128
MONTH_PATTERN = re.compile(r"^(\d{4})-(0[1-9]|1[0-2])$")


class MonthQuery(StrictModel):
    month: str
    gym_id: str | None = Field(default=None, max_length=MAX_GYM_ID_LENGTH)

    @model_validator(mode="after")
    def check_month(self) -> Self:
        match = MONTH_PATTERN.match(self.month)
        if match is None or not MIN_YEAR <= int(match.group(1)) <= MAX_YEAR:
            raise ValueError("Oy YYYY-MM ko'rinishida bo'lishi kerak")
        return self

    @property
    def year_and_month(self) -> tuple[int, int]:
        year, month = self.month.split("-")
        return int(year), int(month)


class TrainerBreakdownOut(OutModel):
    trainer_id: str
    name: str
    clients: int
    subs_count: int
    subs_sums: dict[str, int]


class MonthlyReportOut(OutModel):
    month: str
    subs_count: int
    subs_sums: dict[str, int]
    orders_count: int
    shop_sums: dict[str, int]
    profit: dict[str, int]
    no_cost_orders: int
    trainers: list[TrainerBreakdownOut]
