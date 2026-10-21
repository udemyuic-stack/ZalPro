from datetime import datetime
from typing import ClassVar, Literal

from pydantic import Field

from zalpro_api.schemas.base import OutModel, PatchModel, StrictModel

Muscle = Literal["arms", "chest", "legs"]


class ChallengeStepIn(StrictModel):
    exercise: str = Field(min_length=1, max_length=40)
    target: int = Field(gt=0, le=10000)
    coins: int = Field(ge=0, le=100000)
    muscle: Muscle


class ChallengeStepPatch(PatchModel):
    non_nullable: ClassVar[frozenset[str]] = frozenset({"exercise", "target", "coins", "muscle"})

    exercise: str | None = Field(default=None, min_length=1, max_length=40)
    target: int | None = Field(default=None, gt=0, le=10000)
    coins: int | None = Field(default=None, ge=0, le=100000)
    muscle: Muscle | None = None


class ChallengeStepAdminOut(OutModel):
    id: str
    position: int
    exercise: str
    target: int
    coins: int
    muscle: str
    created_at: datetime
