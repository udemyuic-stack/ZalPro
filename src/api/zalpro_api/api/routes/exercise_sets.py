from typing import Annotated

from fastapi import APIRouter, Path, Query

from zalpro_api.api.deps import CurrentUser, SessionDep
from zalpro_api.schemas.day import IsoDay, WritableDay
from zalpro_api.schemas.exercise_set import ExerciseSetsIn, ExerciseSetsOut
from zalpro_api.services import exercise_sets as exercise_set_service
from zalpro_api.services import permissions
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/users", tags=["exercise-sets"])

ExerciseId = Annotated[str, Path(min_length=1, max_length=100)]


@router.get("/{user_id}/exercise-sets/{exercise_id}/previous", response_model=ExerciseSetsOut)
async def previous_exercise_sets(
    user_id: str,
    exercise_id: ExerciseId,
    before: Annotated[IsoDay, Query()],
    actor: CurrentUser,
    session: SessionDep,
) -> ExerciseSetsOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_self(actor, target.id)
    return await exercise_set_service.previous_sets(session, user_id, before, exercise_id)


@router.get("/{user_id}/exercise-sets/{day}/{exercise_id}", response_model=ExerciseSetsOut)
async def read_exercise_sets(
    user_id: str,
    day: Annotated[IsoDay, Path()],
    exercise_id: ExerciseId,
    actor: CurrentUser,
    session: SessionDep,
) -> ExerciseSetsOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return await exercise_set_service.get_sets(session, user_id, day, exercise_id)


@router.put("/{user_id}/exercise-sets/{day}/{exercise_id}", response_model=ExerciseSetsOut)
async def replace_exercise_sets(
    user_id: str,
    day: Annotated[WritableDay, Path()],
    exercise_id: ExerciseId,
    body: ExerciseSetsIn,
    actor: CurrentUser,
    session: SessionDep,
) -> ExerciseSetsOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_self(actor, target.id)
    return await exercise_set_service.replace_sets(session, user_id, day, exercise_id, body.sets)
