from datetime import date
from typing import Annotated, Literal

from pydantic import AwareDatetime, StringConstraints

from zalpro_api.schemas.base import OutModel, StrictModel


class AttendanceIn(StrictModel):
    present: bool


class AttendanceOut(OutModel):
    day: date
    present: bool
    marked_by: str | None = None
    marked_at: AwareDatetime | None = None


class CheckinTokenOut(OutModel):
    token: str
    expires_in: int


class ScanIn(StrictModel):
    token: Annotated[str, StringConstraints(min_length=1, max_length=2048)]


class ScanOut(OutModel):
    user_id: str
    name: str
    day: date
    already_present: bool
    subscription_expires_at: AwareDatetime | None
    days_left: int | None
    subscription: Literal["active", "expired", "none"]
