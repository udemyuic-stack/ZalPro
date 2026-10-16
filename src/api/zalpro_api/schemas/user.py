import re
from typing import Any, ClassVar, Literal

from pydantic import AwareDatetime, Field, field_validator

from zalpro_api.schemas.base import Name, OutModel, Password, PatchModel, PhoneNumber, StrictModel

Role = Literal["user", "admin", "owner", "barmen"]
ALLOWED_GYM_DAYS = ([2, 4, 6], [1, 3, 5])
HOME_WORKOUT_DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class UserOut(OutModel):
    id: str
    name: str
    phone: str
    role: str
    gender: str | None
    age: int | None
    height: float | None
    weight: float
    activity: float | None
    metabolism: str | None
    goal: str | None
    plan_id: str | None
    plan_assigned_at: AwareDatetime | None
    trainer_id: str | None
    gym_id: str | None
    gym_days: list[int]
    home_workout_date: str | None
    subscription_expires_at: AwareDatetime | None
    last_weigh_in: AwareDatetime | None
    program: dict[str, Any]
    created_at: AwareDatetime


class UserCreate(StrictModel):
    name: Name
    phone: PhoneNumber
    password: Password
    role: Role = "admin"
    gym_id: str | None = None


class UserPatch(PatchModel):
    non_nullable: ClassVar[frozenset[str]] = frozenset(
        {"name", "weight", "role", "gym_days", "program"}
    )

    name: Name | None = None
    gender: str | None = Field(default=None, max_length=20)
    age: int | None = Field(default=None, ge=1, le=120)
    height: float | None = Field(default=None, gt=0, le=300)
    weight: float | None = Field(default=None, ge=0, le=500)
    activity: float | None = Field(default=None, gt=0, le=5)
    metabolism: str | None = Field(default=None, max_length=40)
    goal: str | None = Field(default=None, max_length=40)
    plan_id: str | None = Field(default=None, max_length=100)
    plan_assigned_at: AwareDatetime | None = None
    trainer_id: str | None = None
    gym_id: str | None = None
    gym_days: list[int] | None = None
    home_workout_date: str | None = None
    subscription_expires_at: AwareDatetime | None = None
    program: dict[str, Any] | None = None
    role: Role | None = None

    @field_validator("gym_days")
    @classmethod
    def validate_gym_days(cls, value: list[int] | None) -> list[int] | None:
        if value is not None and value not in ALLOWED_GYM_DAYS:
            raise ValueError("Zal kunlari [2, 4, 6] yoki [1, 3, 5] bo'lishi kerak")
        return value

    @field_validator("home_workout_date")
    @classmethod
    def validate_home_workout_date(cls, value: str | None) -> str | None:
        if value is not None and not HOME_WORKOUT_DATE_PATTERN.match(value):
            raise ValueError("Sana yyyy-MM-dd shaklida bo'lishi kerak")
        return value


class PasswordReset(StrictModel):
    new_password: Password


class RoleUpdate(StrictModel):
    role: Role


class GymAssignment(StrictModel):
    gym_id: str | None


class TrainerAssignment(StrictModel):
    trainer_id: str | None
