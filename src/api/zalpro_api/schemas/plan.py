from typing import Annotated

from pydantic import AfterValidator, Field, StringConstraints

from zalpro_api.schemas.base import OutModel, StrictModel

DAY_KEYS = frozenset(str(day) for day in range(1, 8))
MAX_MEALS_PER_DAY = 20
MAX_ITEMS_PER_MEAL = 50
MAX_FORBIDDEN = 50

PlanTitle = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
Amount = Annotated[float, Field(ge=0, allow_inf_nan=False)]


def validate_day_keys(value: dict[str, object]) -> dict[str, object]:
    if not set(value) <= DAY_KEYS:
        raise ValueError("Kalit 1 dan 7 gacha bo'lishi kerak")
    return value


class MealItem(StrictModel):
    name: str = Field(max_length=80)
    grams: Amount = 0.0
    kcal: Amount = 0.0
    protein: Amount = 0.0


class Meal(StrictModel):
    time: str = Field(default="", max_length=10)
    title: str = Field(default="", max_length=60)
    items: list[MealItem] = Field(default_factory=list, max_length=MAX_ITEMS_PER_MEAL)


class MealItemOut(OutModel):
    name: str
    grams: float = 0.0
    kcal: float = 0.0
    protein: float = 0.0


class MealOut(OutModel):
    time: str = ""
    title: str = ""
    items: list[MealItemOut] = []


MealList = Annotated[list[Meal], Field(max_length=MAX_MEALS_PER_DAY)]
WeekMeals = Annotated[dict[str, MealList], AfterValidator(validate_day_keys)]
DayPhotos = Annotated[
    dict[str, Annotated[str, Field(max_length=500)]], AfterValidator(validate_day_keys)
]


class PlanIn(StrictModel):
    title: PlanTitle
    note: str = Field(default="", max_length=5000)
    forbidden: list[Annotated[str, Field(max_length=80)]] = Field(
        default_factory=list, max_length=MAX_FORBIDDEN
    )
    meals: MealList = Field(default_factory=list)
    week: WeekMeals = Field(default_factory=dict)
    photos: DayPhotos = Field(default_factory=dict)


class PlanOut(OutModel):
    id: str
    title: str
    note: str
    forbidden: list[str]
    meals: list[MealOut]
    week: dict[str, list[MealOut]]
    photos: dict[str, str]
