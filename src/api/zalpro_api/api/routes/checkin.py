from fastapi import APIRouter

from zalpro_api.api.deps import CurrentUser, ScanActor, SessionDep, SettingsDep
from zalpro_api.core.security import CHECKIN_TOKEN_SECONDS, create_checkin_token
from zalpro_api.schemas.attendance import CheckinTokenOut, ScanIn, ScanOut
from zalpro_api.services import attendance as attendance_service

router = APIRouter(tags=["checkin"])


@router.get("/users/me/checkin-token", response_model=CheckinTokenOut)
async def read_checkin_token(actor: CurrentUser, settings: SettingsDep) -> CheckinTokenOut:
    token = create_checkin_token(actor.id, settings)
    return CheckinTokenOut(token=token, expires_in=CHECKIN_TOKEN_SECONDS)


@router.post("/attendance/scan", response_model=ScanOut)
async def scan_checkin(
    body: ScanIn, actor: ScanActor, session: SessionDep, settings: SettingsDep
) -> ScanOut:
    return await attendance_service.scan_checkin(session, settings, actor, body.token)
