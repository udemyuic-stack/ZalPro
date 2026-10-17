from fastapi import APIRouter

from zalpro_api.api.deps import CurrentUser, SessionDep, SettingsDep
from zalpro_api.schemas.leaderboard import LeaderboardOut
from zalpro_api.services import leaderboard as leaderboard_service
from zalpro_api.services.subscriptions import gym_zone

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])


@router.get("", response_model=LeaderboardOut)
async def read_leaderboard(
    actor: CurrentUser, session: SessionDep, settings: SettingsDep
) -> LeaderboardOut:
    return await leaderboard_service.leaderboard(session, actor, gym_zone(settings))
