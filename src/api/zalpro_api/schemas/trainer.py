from typing import ClassVar

from pydantic import Field

from zalpro_api.schemas.base import Name, OutModel, PatchModel, StrictModel


class TrainerCreate(StrictModel):
    name: Name | None = None
    bio: str = Field(default="", max_length=300)
    accepting: bool = True


class TrainerUpdate(PatchModel):
    non_nullable: ClassVar[frozenset[str]] = frozenset({"name", "bio", "accepting"})

    name: Name | None = None
    bio: str | None = Field(default=None, max_length=300)
    accepting: bool | None = None
    gym_id: str | None = None


class TrainerOut(OutModel):
    id: str
    name: str
    bio: str
    accepting: bool
    gym_id: str | None
