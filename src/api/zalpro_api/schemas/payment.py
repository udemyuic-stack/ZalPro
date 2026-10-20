from datetime import datetime
from typing import Literal

from pydantic import Field

from zalpro_api.schemas.base import OutModel, StrictModel

Provider = Literal["payme", "click"]
OrderStatus = Literal["pending", "created", "paid", "canceled"]
PLAN_MONTHS = (1, 3, 6, 12)


class PaymentOrderIn(StrictModel):
    months: int = Field(strict=True)
    provider: Provider


class PaymentPlanOut(OutModel):
    months: int
    price: int
    currency: str


class PaymentOptionsOut(OutModel):
    providers: list[Provider]
    plans: list[PaymentPlanOut]


class PaymentOrderOut(OutModel):
    id: str
    provider: Provider
    months: int
    amount: int
    currency: str
    status: OrderStatus
    created_at: datetime
    paid_at: datetime | None
    expires_at: datetime | None
    pay_url: str | None
