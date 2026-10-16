from typing import Annotated

from pydantic import Field, StringConstraints

from zalpro_api.schemas.base import OutModel, StrictModel

FoodName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
Nutrient = Annotated[float, Field(ge=0, allow_inf_nan=False)]


class FoodIn(StrictModel):
    name: FoodName
    kcal: Nutrient = 0.0
    protein: Nutrient = 0.0
    fat: Nutrient = 0.0
    carbs: Nutrient = 0.0
    image: str = Field(default="", max_length=500)


class FoodOut(OutModel):
    id: str
    name: str
    kcal: float
    protein: float
    fat: float
    carbs: float
    image: str
