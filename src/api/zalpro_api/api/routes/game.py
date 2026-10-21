from typing import Annotated, Literal

from fastapi import APIRouter, Query, Response

from zalpro_api.api.deps import CurrentUser, OwnerUser, SessionDep, SettingsDep
from zalpro_api.schemas.challenge_step import (
    ChallengeStepAdminOut,
    ChallengeStepIn,
    ChallengeStepPatch,
)
from zalpro_api.schemas.game import (
    CatalogOut,
    ChallengesOut,
    GameLeaderboardOut,
    GameMeOut,
    SessionIn,
    SessionOut,
)
from zalpro_api.services import challenge_steps as challenge_steps_service
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


@router.get("/challenge-steps", response_model=list[ChallengeStepAdminOut])
async def list_challenge_steps(
    actor: OwnerUser, session: SessionDep
) -> list[ChallengeStepAdminOut]:
    return await challenge_steps_service.list_steps(session)


@router.post("/challenge-steps", response_model=ChallengeStepAdminOut, status_code=201)
async def create_challenge_step(
    body: ChallengeStepIn, actor: OwnerUser, session: SessionDep
) -> ChallengeStepAdminOut:
    return await challenge_steps_service.create(session, body, game_service.EXERCISES)


@router.patch("/challenge-steps/{step_id}", response_model=ChallengeStepAdminOut)
async def update_challenge_step(
    step_id: str, body: ChallengeStepPatch, actor: OwnerUser, session: SessionDep
) -> ChallengeStepAdminOut:
    return await challenge_steps_service.update(session, step_id, body, game_service.EXERCISES)


@router.delete("/challenge-steps/{step_id}", status_code=204)
async def delete_challenge_step(step_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    await challenge_steps_service.delete(session, step_id)
    return Response(status_code=204)
