from typing import Annotated

from pydantic import AwareDatetime, Field

from zalpro_api.schemas.base import OutModel, StrictModel

MIN_DAYS_LEFT = -3650
MAX_DAYS_LEFT = 31
MAX_CLIENT_ID_LENGTH = 128

DaysLeft = Annotated[int, Field(strict=True, ge=MIN_DAYS_LEFT, le=MAX_DAYS_LEFT)]


class ReminderIn(StrictModel):
    client_id: str = Field(min_length=1, max_length=MAX_CLIENT_ID_LENGTH)
    days_left: DaysLeft


class ReminderOut(OutModel):
    id: str
    client_id: str
    client_name: str
    trainer_id: str
    sent_by: str
    sent_at: AwareDatetime
    days_left: int
