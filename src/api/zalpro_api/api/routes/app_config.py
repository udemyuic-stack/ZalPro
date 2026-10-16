from fastapi import APIRouter

from zalpro_api.api.deps import SettingsDep
from zalpro_api.schemas.app_config import AppConfigOut

router = APIRouter(prefix="/app", tags=["app"])


@router.get("/config", response_model=AppConfigOut)
async def read_app_config(settings: SettingsDep) -> AppConfigOut:
    return AppConfigOut(
        min_app_build=settings.min_app_build, download_url=settings.app_download_url
    )
