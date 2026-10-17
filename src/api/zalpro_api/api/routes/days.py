from typing import Annotated

from fastapi import APIRouter, Path, Query

from zalpro_api.api.deps import CurrentUser, SessionDep
from zalpro_api.schemas.day import (
    MAX_EXTRA_AT,
    MAX_MEAL_INDEX,
    DayOut,
    DayRange,
    ExerciseMark,
    ExtraIn,
    FeedbackIn,
    MealMark,
    WaterIn,
    WritableDay,
)
from zalpro_api.services import days as days_service
from zalpro_api.services import permissions
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/users", tags=["days"])

DayPath = Annotated[WritableDay, Path()]
MealIndex = Annotated[int, Path(ge=0, le=MAX_MEAL_INDEX)]
ExtraAt = Annotated[int, Path(ge=0, le=MAX_EXTRA_AT)]
ExerciseKey = Annotated[str, Path(min_length=1, max_length=100)]


@router.get("/{user_id}/days", response_model=list[DayOut])
async def list_days(
    user_id: str, window: Annotated[DayRange, Query()], actor: CurrentUser, session: SessionDep
) -> list[DayOut]:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return await days_service.list_days(session, user_id, window.from_, window.to)


@router.get("/{user_id}/days/{day}", response_model=DayOut)
async def read_day(user_id: str, day: DayPath, actor: CurrentUser, session: SessionDep) -> DayOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return await days_service.get_day(session, user_id, day)


@router.put("/{user_id}/days/{day}/meals/{index}", response_model=DayOut)
async def mark_meal(
    user_id: str,
    day: DayPath,
    index: MealIndex,
    body: MealMark,
    actor: CurrentUser,
    session: SessionDep,
) -> DayOut:
    permissions.ensure_self(actor, user_id)
    return await days_service.set_meal(session, user_id, day, index, body.done)


@router.post("/{user_id}/days/{day}/extras", response_model=DayOut)
async def add_extra(
    user_id: str, day: DayPath, body: ExtraIn, actor: CurrentUser, session: SessionDep
) -> DayOut:
    permissions.ensure_self(actor, user_id)
    return await days_service.add_extra(session, user_id, day, body)


@router.delete("/{user_id}/days/{day}/extras/{at}", response_model=DayOut)
async def remove_extra(
    user_id: str, day: DayPath, at: ExtraAt, actor: CurrentUser, session: SessionDep
) -> DayOut:
    permissions.ensure_self(actor, user_id)
    return await days_service.remove_extra(session, user_id, day, at)


@router.put("/{user_id}/days/{day}/workout/start", response_model=DayOut)
async def start_workout(
    user_id: str, day: DayPath, actor: CurrentUser, session: SessionDep
) -> DayOut:
    permissions.ensure_self(actor, user_id)
    return await days_service.start_workout(session, user_id, day)


@router.put("/{user_id}/days/{day}/workout/exercises/{key:path}", response_model=DayOut)
async def mark_exercise(
    user_id: str,
    day: DayPath,
    key: ExerciseKey,
    body: ExerciseMark,
    actor: CurrentUser,
    session: SessionDep,
) -> DayOut:
    permissions.ensure_self(actor, user_id)
    return await days_service.set_exercise(session, user_id, day, key, body.done)


@router.put("/{user_id}/days/{day}/workout/feedback", response_model=DayOut)
async def set_feedback(
    user_id: str, day: DayPath, body: FeedbackIn, actor: CurrentUser, session: SessionDep
) -> DayOut:
    permissions.ensure_self(actor, user_id)
    return await days_service.set_feedback(session, user_id, day, body.rating)


@router.put("/{user_id}/days/{day}/water", response_model=DayOut)
async def set_water(
    user_id: str, day: DayPath, body: WaterIn, actor: CurrentUser, session: SessionDep
) -> DayOut:
    permissions.ensure_self(actor, user_id)
    return await days_service.set_water(session, user_id, day, body.glasses)
