from typing import Annotated, Literal

from pydantic import AwareDatetime, Field, computed_field

from zalpro_api.schemas.base import OutModel, StrictModel
from zalpro_api.schemas.day import OptionalDayRange

MAX_QTY = 20
MAX_SIZE_LENGTH = 20
MAX_COLOR_LENGTH = 30
MAX_PRODUCT_ID_LENGTH = 128

OrderStatus = Literal["new", "given", "canceled"]
TargetStatus = Literal["given", "canceled"]


class OrderIn(StrictModel):
    product_id: str = Field(min_length=1, max_length=MAX_PRODUCT_ID_LENGTH)
    qty: Annotated[int, Field(strict=True, ge=1, le=MAX_QTY)]
    size: str = Field(default="", max_length=MAX_SIZE_LENGTH)
    color: str = Field(default="", max_length=MAX_COLOR_LENGTH)


class OrderStatusIn(StrictModel):
    status: TargetStatus


class OrderListQuery(OptionalDayRange):
    status: OrderStatus | None = None


class OrderOut(OutModel):
    id: str
    client_id: str
    client_name: str
    client_phone: str
    trainer_id: str
    gym_id: str
    product_id: str
    product_name: str
    category: str
    size: str
    color: str
    price: int
    currency: str
    qty: int
    status: str
    created_at: AwareDatetime
    updated_at: AwareDatetime | None
    given_by: str
    given_at: AwareDatetime | None

    @computed_field
    @property
    def total(self) -> int:
        return self.price * self.qty
