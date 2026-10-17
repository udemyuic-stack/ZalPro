from datetime import datetime
from typing import Annotated, Literal, Self

from pydantic import Field, StringConstraints, model_validator

from zalpro_api.schemas.base import OutModel, StrictModel

Muscle = Literal[
    "chest",
    "shoulders",
    "biceps",
    "triceps",
    "forearms",
    "abs",
    "back",
    "traps",
    "glutes",
    "quads",
    "hamstrings",
    "calves",
]
Level = Literal["", "beginner", "middle", "pro"]
ExerciseName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]


class ExerciseIn(StrictModel):
    name: ExerciseName
    muscle: Muscle
    sets: str = Field(default="", max_length=40)
    tip: str = Field(default="", max_length=500)
    also: list[Muscle] = Field(default_factory=list, max_length=6)
    level: Level = ""

    @model_validator(mode="after")
    def reject_primary_muscle_in_also(self) -> Self:
        if self.muscle in self.also:
            raise ValueError("also ichida asosiy mushak bo'lmasligi kerak")
        return self


class ExerciseCreate(ExerciseIn):
    base: str = Field(default="", max_length=80)


class ExerciseOut(OutModel):
    id: str
    name: str
    muscle: str
    sets: str
    tip: str
    also: list[str]
    created_at: datetime
    created_by: str
    base: str
    level: str
    has_video: bool
    video_status: Literal["processing", "ready", "failed"] | None = None
