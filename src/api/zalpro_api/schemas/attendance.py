from datetime import date

from pydantic import AwareDatetime

from zalpro_api.schemas.base import OutModel, StrictModel


class AttendanceIn(StrictModel):
    present: bool


class AttendanceOut(OutModel):
    day: date
    present: bool
    marked_by: str | None = None
    marked_at: AwareDatetime | None = None
