from typing import Annotated

from fastapi import APIRouter, Path, Query

from zalpro_api.api.deps import CurrentUser, SessionDep, SettingsDep
from zalpro_api.schemas.day import DayRange, IsoDay
from zalpro_api.schemas.streak_freeze import StreakFreezeIn, StreakFreezeOut
from zalpro_api.services import permissions
from zalpro_api.services import streak_freezes as streak_freeze_service
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/users", tags=["streak-freezes"])

WeekPath = Annotated[IsoDay, Path()]


@router.get("/{user_id}/streak-freezes", response_model=list[StreakFreezeOut])
async def list_streak_freezes(
    user_id: str, window: Annotated[DayRange, Query()], actor: CurrentUser, session: SessionDep
) -> list[StreakFreezeOut]:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_streak_freezes(actor, target)
    return await streak_freeze_service.list_streak_freezes(
        session, user_id, window.from_, window.to
    )


@router.post("/{user_id}/streak-freezes", response_model=StreakFreezeOut)
async def grant_streak_freeze(
    user_id: str,
    body: StreakFreezeIn,
    actor: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> StreakFreezeOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_grant_streak_freeze(actor, target)
    return await streak_freeze_service.grant_streak_freeze(
        session, settings, user_id, body.week_start, actor.id
    )


@router.delete("/{user_id}/streak-freezes/{week_start}", status_code=204)
async def revoke_streak_freeze(
    user_id: str, week_start: WeekPath, actor: CurrentUser, session: SessionDep
) -> None:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_grant_streak_freeze(actor, target)
    await streak_freeze_service.revoke_streak_freeze(session, user_id, week_start)
