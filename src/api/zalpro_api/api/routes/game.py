from typing import Annotated, Literal

from fastapi import APIRouter, Query, Response

from zalpro_api.api.deps import CurrentUser, SessionDep, SettingsDep
from zalpro_api.schemas.game import (
    CatalogOut,
    ChallengesOut,
    GameLeaderboardOut,
    GameMeOut,
    SessionIn,
    SessionOut,
)
from zalpro_api.services import challenges as challenge_service
from zalpro_api.services import game as game_service
from zalpro_api.services.subscriptions import gym_zone

router = APIRouter(prefix="/game", tags=["game"])


@router.get("/catalog", response_model=CatalogOut)
async def read_catalog(actor: CurrentUser) -> CatalogOut:
    return game_service.catalog()


@router.post("/sessions", response_model=SessionOut)
async def submit_session(
    body: SessionIn, actor: CurrentUser, session: SessionDep, settings: SettingsDep
) -> SessionOut:
    return await game_service.submit(session, actor, body, gym_zone(settings))


@router.post("/sessions/{session_id}/void", status_code=204)
async def void_session(session_id: str, actor: CurrentUser, session: SessionDep) -> Response:
    await game_service.void(session, actor, session_id)
    return Response(status_code=204)


@router.get("/me", response_model=GameMeOut)
async def read_me(actor: CurrentUser, session: SessionDep, settings: SettingsDep) -> GameMeOut:
    return await game_service.me(session, actor, gym_zone(settings))


@router.get("/leaderboard", response_model=GameLeaderboardOut)
async def read_leaderboard(
    actor: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
    period: Annotated[Literal["day", "week", "month", "year", "all"], Query()] = "week",
    exercise: Annotated[str | None, Query(max_length=40)] = None,
) -> GameLeaderboardOut:
    return await game_service.leaderboard(session, actor, gym_zone(settings), period, exercise)


@router.get("/challenges", response_model=ChallengesOut)
async def read_challenges(actor: CurrentUser, session: SessionDep) -> ChallengesOut:
    return await challenge_service.read(session, actor.id)
