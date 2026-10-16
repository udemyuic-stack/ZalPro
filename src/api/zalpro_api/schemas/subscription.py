from datetime import datetime
from typing import Literal, Self

from pydantic import AwareDatetime, Field, field_validator, model_validator

from zalpro_api.schemas.base import OutModel, StrictModel

MAX_MONTHS = 24
MAX_DAYS = 31
MAX_PRICE = 2_147_483_647
MIN_YEAR = 2000
MAX_YEAR = 2100

Currency = Literal["UZS", "USD"]


def check_year(value: datetime) -> datetime:
    if not MIN_YEAR <= value.year <= MAX_YEAR:
        raise ValueError("Sana ruxsat etilgan oraliqdan tashqarida")
    return value


class SubscriptionIn(StrictModel):
    start_date: AwareDatetime
    months: int = Field(default=0, ge=0, le=MAX_MONTHS, strict=True)
    days: int = Field(default=0, ge=0, le=MAX_DAYS, strict=True)
    price: int = Field(ge=0, le=MAX_PRICE, strict=True)
    currency: Currency
    paid_date: AwareDatetime | None = None

    @field_validator("start_date", "paid_date")
    @classmethod
    def validate_year(cls, value: datetime | None) -> datetime | None:
        return None if value is None else check_year(value)

    @model_validator(mode="after")
    def check_exclusive_duration(self) -> Self:
        if (self.months > 0) == (self.days > 0):
            raise ValueError("Oy yoki kundan faqat bittasi 0 dan katta bo'lishi kerak")
        return self


class SubscriptionOut(OutModel):
    id: str
    user_id: str
    start_date: datetime
    months: int
    days: int
    price: int
    currency: str
    paid_date: datetime | None
    created_at: datetime
    paid_at: datetime
    expires_at: datetime


class PaidWindow(StrictModel):
    from_: AwareDatetime | None = Field(default=None, alias="from")
    to: AwareDatetime | None = None

    @model_validator(mode="after")
    def check_order(self) -> Self:
        if self.from_ is not None and self.to is not None and self.from_ >= self.to:
            raise ValueError("'from' 'to' dan kichik bo'lishi kerak")
        return self
