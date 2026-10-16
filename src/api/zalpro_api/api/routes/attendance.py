from typing import Annotated

from fastapi import APIRouter, Path, Query

from zalpro_api.api.deps import CurrentUser, SessionDep
from zalpro_api.schemas.attendance import AttendanceIn, AttendanceOut
from zalpro_api.schemas.day import DayRange, WritableDay
from zalpro_api.services import attendance as attendance_service
from zalpro_api.services import permissions
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/users", tags=["attendance"])

DayPath = Annotated[WritableDay, Path()]


@router.get("/{user_id}/attendance", response_model=list[AttendanceOut])
async def list_attendance(
    user_id: str, window: Annotated[DayRange, Query()], actor: CurrentUser, session: SessionDep
) -> list[AttendanceOut]:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return await attendance_service.list_attendance(session, user_id, window.from_, window.to)


@router.get("/{user_id}/attendance/{day}", response_model=AttendanceOut)
async def read_attendance(
    user_id: str, day: DayPath, actor: CurrentUser, session: SessionDep
) -> AttendanceOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return await attendance_service.get_attendance(session, user_id, day)


@router.put("/{user_id}/attendance/{day}", response_model=AttendanceOut)
async def mark_attendance(
    user_id: str, day: DayPath, body: AttendanceIn, actor: CurrentUser, session: SessionDep
) -> AttendanceOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_manage(actor, target)
    return await attendance_service.mark_attendance(session, user_id, day, body.present, actor.id)
