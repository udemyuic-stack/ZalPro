from datetime import date
from typing import Annotated, Self

from pydantic import Field, model_validator

from zalpro_api.schemas.base import OutModel, StrictModel

MAX_SETS = 20

SetNo = Annotated[int, Field(ge=1, le=MAX_SETS)]
WeightKg = Annotated[float, Field(ge=0, le=1000, allow_inf_nan=False)]
Reps = Annotated[int, Field(ge=0, le=1000)]


class ExerciseSetIn(StrictModel):
    set_no: SetNo
    weight_kg: WeightKg | None = None
    reps: Reps | None = None


class ExerciseSetsIn(StrictModel):
    sets: list[ExerciseSetIn] = Field(max_length=MAX_SETS)

    @model_validator(mode="after")
    def unique_set_numbers(self) -> Self:
        numbers = [item.set_no for item in self.sets]
        if len(numbers) != len(set(numbers)):
            raise ValueError("set_no takrorlanmasligi kerak")
        return self


class ExerciseSetOut(OutModel):
    set_no: int
    weight_kg: float | None = None
    reps: int | None = None


class ExerciseSetsOut(OutModel):
    day: date
    exercise_id: str
    sets: list[ExerciseSetOut]
