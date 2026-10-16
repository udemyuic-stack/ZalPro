from typing import Annotated

from fastapi import APIRouter, Query

from zalpro_api.api.deps import OwnerUser, SessionDep, SettingsDep
from zalpro_api.schemas.stats import TrainerStatOut
from zalpro_api.services import stats as stats_service
from zalpro_api.services.subscriptions import gym_zone

router = APIRouter(prefix="/stats", tags=["stats"])

DEFAULT_STATS_DAYS = 7
MAX_STATS_DAYS = 365


@router.get("/trainers", response_model=list[TrainerStatOut])
async def trainer_stats(
    actor: OwnerUser,
    session: SessionDep,
    settings: SettingsDep,
    days: Annotated[int, Query(ge=1, le=MAX_STATS_DAYS)] = DEFAULT_STATS_DAYS,
) -> list[TrainerStatOut]:
    return await stats_service.trainer_stats(session, days, gym_zone(settings))
