from typing import Annotated, Literal

from pydantic import AfterValidator, AwareDatetime, Field, StringConstraints

from zalpro_api.models.announcement import MAX_BODY_LENGTH, MAX_TITLE_LENGTH
from zalpro_api.schemas.base import OutModel, StrictModel

Title = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_TITLE_LENGTH)
]
Body = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_BODY_LENGTH)
]
EXPIRY_CHOICES = frozenset({1, 7, 30})


def validate_expiry(value: int) -> int:
    if value not in EXPIRY_CHOICES:
        raise ValueError("Muddat 1, 7 yoki 30 kun bo'lishi kerak")
    return value


ExpiresInDays = Annotated[int, Field(strict=True), AfterValidator(validate_expiry)] | None


class AnnouncementIn(StrictModel):
    title: Title
    body: Body
    audience: Literal["all", "students"]
    expires_in_days: ExpiresInDays = None


class AnnouncementOut(OutModel):
    id: str
    title: str
    body: str
    audience: Literal["all", "students"]
    author_id: str
    author_name: str
    created_at: AwareDatetime
    expires_at: AwareDatetime | None
