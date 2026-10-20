import asyncio
import datetime
import uuid
from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Gym, RepSession, Trainer, User
from zalpro_api.services.game import (
    EXERCISES,
    STREAK_BONUSES,
    level_for,
    reward,
    streak_length,
)

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
GymFactory = Callable[..., Awaitable[Gym]]

SESSIONS = "/v1/game/sessions"
ME = "/v1/game/me"
BOARD = "/v1/game/leaderboard"


def payload(
    exercise: str = "squat",
    reps: int = 10,
    duration_s: int = 30,
    visibility_pct: int = 95,
    ended_ago_s: int = 30,
    **extra: Any,
) -> dict[str, Any]:
    started = datetime.datetime.now(datetime.UTC) - datetime.timedelta(
        seconds=duration_s + ended_ago_s
    )
    return {
        "id": str(uuid.uuid4()),
        "exercise": exercise,
        "reps": reps,
        "duration_s": duration_s,
        "visibility_pct": visibility_pct,
        "started_at": started.isoformat(),
        **extra,
    }


def test_reward_follows_exercise_xp() -> None:
    assert reward(EXERCISES["squat"], 10, 0) == 40
    assert reward(EXERCISES["pushup"], 10, 0) == 80
    assert reward(EXERCISES["pullup"], 10, 0) == 200
    assert reward(EXERCISES["lunge"], 10, 0) == 40
    assert reward(EXERCISES["auto"], 10, 0) == 40


def test_reward_reduces_over_daily_cap() -> None:
    assert reward(EXERCISES["squat"], 20, 560) == 40 + 8
    assert reward(EXERCISES["pullup"], 10, 600) == 40
    assert reward(EXERCISES["squat"], 1, 600) == 0


def test_levels() -> None:
    assert [level_for(x) for x in (0, 499, 500, 1500, 11999, 12000, 99999)] == [1, 1, 2, 3, 5, 6, 6]


def test_streak_length() -> None:
    today = datetime.date(2026, 3, 10)
    days = {today, today - datetime.timedelta(days=1), today - datetime.timedelta(days=2)}
    assert streak_length(days, today) == 3
    assert streak_length(days - {today}, today) == 2
    assert streak_length({today - datetime.timedelta(days=2)}, today) == 0
    assert streak_length(set(), today) == 0


async def test_submit_gives_xp_but_no_session_coins(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    user = await make_user()
    response = await client.post(SESSIONS, json=payload(), headers=auth_headers(user))
    assert response.status_code == 200
    body = response.json()
    assert (body["status"], body["coins"], body["xp"]) == ("valid", 0, 40)
    assert (body["total_xp"], body["level"]) == (40, 1)
    pushup = await client.post(
        SESSIONS,
        json=payload("pushup", reps=5, duration_s=60),
        headers=auth_headers(user),
    )
    assert pushup.json()["xp"] == 40
    me = (await client.get(ME, headers=auth_headers(user))).json()
    assert (me["coins"], me["xp"], me["sessions_total"]) == (0, 80, 2)
    assert me["best_sets"] == {"squat": 10, "pushup": 5}
    assert me["next_level_xp"] == 500


async def test_submit_is_idempotent(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    user = await make_user()
    body = payload()
    first = await client.post(SESSIONS, json=body, headers=auth_headers(user))
    second = await client.post(SESSIONS, json=body, headers=auth_headers(user))
    assert second.status_code == 200
    assert second.json() == first.json()
    assert (await client.get(ME, headers=auth_headers(user))).json()["xp"] == 40


async def test_session_id_of_other_user_conflicts(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    first, second = await make_user(), await make_user()
    body = payload()
    await client.post(SESSIONS, json=body, headers=auth_headers(first))
    response = await client.post(SESSIONS, json=body, headers=auth_headers(second))
    assert response.status_code == 409


@pytest.mark.parametrize(
    "fields",
    [
        {"reps": 150, "duration_s": 600},
        {"reps": 20, "duration_s": 10},
        {"reps": 60, "duration_s": 60},
        {"visibility_pct": 50},
        {"ended_ago_s": 3600},
        {"ended_ago_s": -3600},
    ],
)
async def test_suspicious_session_is_flagged_without_xp(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    fields: dict[str, Any],
) -> None:
    user = await make_user()
    response = await client.post(SESSIONS, json=payload(**fields), headers=auth_headers(user))
    assert response.status_code == 200
    assert (response.json()["status"], response.json()["xp"]) == ("flagged", 0)
    assert (await client.get(ME, headers=auth_headers(user))).json()["xp"] == 0


@pytest.mark.parametrize(
    "fields",
    [
        {"exercise": "dance"},
        {"reps": 0},
        {"duration_s": 0},
        {"visibility_pct": 101},
        {"id": "not-a-uuid"},
        {"coins": 999},
    ],
)
async def test_invalid_payload_is_rejected(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    fields: dict[str, Any],
) -> None:
    user = await make_user()
    response = await client.post(SESSIONS, json={**payload(), **fields}, headers=auth_headers(user))
    assert response.status_code in (409, 422)


async def test_only_students_earn(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    for role in ("admin", "owner", "barmen"):
        actor = await make_user(role)
        response = await client.post(SESSIONS, json=payload(), headers=auth_headers(actor))
        assert response.status_code == 403


async def test_requires_auth(client: AsyncClient) -> None:
    assert (await client.post(SESSIONS, json=payload())).status_code == 401
    assert (await client.get(BOARD)).status_code == 401


async def test_daily_cap_reduces_xp(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    user = await make_user()
    headers = auth_headers(user)
    for _ in range(3):
        await client.post(SESSIONS, json=payload(reps=50, duration_s=120), headers=headers)
    me = (await client.get(ME, headers=headers)).json()
    assert me["xp"] == 600
    over = await client.post(SESSIONS, json=payload(reps=10, duration_s=30), headers=headers)
    assert over.json()["xp"] == 8


async def test_streak_bonus_on_third_day(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    user = await make_user()
    now = datetime.datetime.now(datetime.UTC)
    for back in (1, 2):
        db_session.add(
            RepSession(
                id=uuid.uuid4().hex,
                user_id=user.id,
                exercise_key="pushup",
                reps=10,
                duration_s=30,
                visibility_pct=90,
                started_at=now - datetime.timedelta(days=back),
                coins=10,
                xp=40,
                status="valid",
            )
        )
    await db_session.commit()
    response = await client.post(SESSIONS, json=payload(), headers=auth_headers(user))
    body = response.json()
    assert body["streak_days"] == 3
    assert body["streak_bonus"] == STREAK_BONUSES[3]
    assert body["total_coins"] == STREAK_BONUSES[3]


async def test_leaderboard_ranks_by_xp_and_scopes_to_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym, other = await make_gym(), await make_gym()
    top = await make_user(gym_id=gym.id, name="Top")
    mid = await make_user(gym_id=gym.id, name="Mid")
    hidden = await make_user(gym_id=gym.id, name="Hidden", show_in_leaderboard=False)
    outsider = await make_user(gym_id=other.id, name="Outsider")
    for user, reps in ((top, 40), (mid, 10), (hidden, 40), (outsider, 40)):
        await client.post(
            SESSIONS, json=payload(reps=reps, duration_s=120), headers=auth_headers(user)
        )
    for period in ("day", "week", "month", "year", "all"):
        board = (
            await client.get(BOARD, params={"period": period}, headers=auth_headers(mid))
        ).json()
        assert [row["name"] for row in board["top"]] == ["Top", "Mid"]
        assert board["me"]["rank"] == 2
        assert board["top"][0]["xp"] == 160


async def test_leaderboard_by_exercise_ranks_reps(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    runner = await make_user(gym_id=gym.id, name="Squatter")
    presser = await make_user(gym_id=gym.id, name="Pusher")
    await client.post(
        SESSIONS,
        json=payload("squat", reps=40, duration_s=120),
        headers=auth_headers(runner),
    )
    await client.post(
        SESSIONS,
        json=payload("pushup", reps=30, duration_s=120),
        headers=auth_headers(presser),
    )
    board = (
        await client.get(BOARD, params={"exercise": "squat"}, headers=auth_headers(presser))
    ).json()
    assert [(row["name"], row["reps"]) for row in board["top"]] == [("Squatter", 40)]
    assert board["me"] is None
    bad = await client.get(BOARD, params={"exercise": "dance"}, headers=auth_headers(presser))
    assert bad.status_code == 409


async def test_flagged_and_trainerless_students_both_ranked_only_if_valid(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: Callable[..., Awaitable[Trainer]],
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    coach = await make_user("admin", gym_id=gym.id)
    await make_trainer(coach)
    with_trainer = await make_user(gym_id=gym.id, trainer_id=coach.id, name="WithCoach")
    alone = await make_user(gym_id=gym.id, name="Alone")
    cheater = await make_user(gym_id=gym.id, name="Cheater")
    await client.post(SESSIONS, json=payload(), headers=auth_headers(with_trainer))
    await client.post(SESSIONS, json=payload(), headers=auth_headers(alone))
    await client.post(
        SESSIONS, json=payload(reps=200, duration_s=60), headers=auth_headers(cheater)
    )
    board = (await client.get(BOARD, headers=auth_headers(alone))).json()
    assert sorted(row["name"] for row in board["top"]) == ["Alone", "WithCoach"]


async def test_void_removes_coins_and_ranking(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: Callable[..., Awaitable[Trainer]],
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    coach = await make_user("admin", gym_id=gym.id)
    await make_trainer(coach)
    student = await make_user(gym_id=gym.id, trainer_id=coach.id)
    stranger = await make_user(gym_id=gym.id)
    body = payload()
    await client.post(SESSIONS, json=body, headers=auth_headers(student))
    denied = await client.post(
        f"{SESSIONS}/{uuid.UUID(body['id']).hex}/void", headers=auth_headers(stranger)
    )
    assert denied.status_code == 403
    done = await client.post(
        f"{SESSIONS}/{uuid.UUID(body['id']).hex}/void", headers=auth_headers(coach)
    )
    assert done.status_code == 204
    me = (await client.get(ME, headers=auth_headers(student))).json()
    assert (me["coins"], me["xp"], me["sessions_total"]) == (0, 0, 0)
    board = (await client.get(BOARD, headers=auth_headers(student))).json()
    assert board["top"] == []
    missing = await client.post(f"{SESSIONS}/nope/void", headers=auth_headers(coach))
    assert missing.status_code == 404


async def test_catalog(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    user = await make_user()
    body = (await client.get("/v1/game/catalog", headers=auth_headers(user))).json()
    assert {row["key"] for row in body["exercises"]} == set(EXERCISES)
    assert body["levels"][0] == 0
    assert body["daily_xp_cap"] == 600


async def test_parallel_same_id_rewards_once(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    user = await make_user()
    body = payload(reps=20, duration_s=60)
    responses = await asyncio.gather(
        *(client.post(SESSIONS, json=body, headers=auth_headers(user)) for _ in range(5))
    )
    assert all(r.status_code in (200, 201) for r in responses)
    assert {r.json()["total_xp"] for r in responses} == {80}
    me = (await client.get("/v1/game/me", headers=auth_headers(user))).json()
    assert me["xp"] == 80
    assert me["sessions_total"] == 1


async def test_game_toggle_hides_from_board_but_keeps_recording(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    shown = await make_user(gym_id=gym.id, name="Shown")
    quiet = await make_user(gym_id=gym.id, name="Quiet")
    off = await client.put(
        "/v1/users/me/game", json={"enabled": False}, headers=auth_headers(quiet)
    )
    assert off.status_code == 200
    assert off.json()["game_enabled"] is False
    for user in (shown, quiet):
        await client.post(
            SESSIONS, json=payload(reps=10, duration_s=60), headers=auth_headers(user)
        )
    board = (await client.get(BOARD, params={"period": "all"}, headers=auth_headers(shown))).json()
    assert [row["name"] for row in board["top"]] == ["Shown"]
    me = (await client.get("/v1/game/me", headers=auth_headers(quiet))).json()
    assert me["xp"] == 40
    on = await client.put("/v1/users/me/game", json={"enabled": True}, headers=auth_headers(quiet))
    assert on.json()["game_enabled"] is True
    board = (await client.get(BOARD, params={"period": "all"}, headers=auth_headers(shown))).json()
    assert {row["name"] for row in board["top"]} == {"Shown", "Quiet"}


@pytest.mark.parametrize("value", ["yes", 1, 0, None, "", []])
async def test_game_toggle_rejects_non_bool(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, value: object
) -> None:
    me = await make_user()
    response = await client.put(
        "/v1/users/me/game", json={"enabled": value}, headers=auth_headers(me)
    )
    assert response.status_code == 422


CHALLENGES = "/v1/game/challenges"


async def test_challenge_chain_accumulates_and_pays_once(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    user = await make_user()
    headers = auth_headers(user)
    first = await client.post(
        SESSIONS, json=payload("pullup", reps=12, duration_s=120), headers=headers
    )
    assert first.json()["challenge"]["completed"] is False
    assert first.json()["challenge"]["progress"] == 12
    body = payload("pullup", reps=8, duration_s=120)
    second = await client.post(SESSIONS, json=body, headers=headers)
    result = second.json()["challenge"]
    assert (result["completed"], result["coins"], result["muscle"]) == (True, 20, "arms")
    assert second.json()["total_coins"] == 20
    replay = await client.post(SESSIONS, json=body, headers=headers)
    assert replay.json()["total_coins"] == 20
    state = (await client.get(CHALLENGES, headers=headers)).json()
    assert (state["step"], state["progress"]) == (1, 0)
    assert state["muscles"] == {"arms": 1, "chest": 0, "legs": 0}
    assert [row["state"] for row in state["steps"][:3]] == ["done", "current", "locked"]
    assert len(state["steps"]) == 12


async def test_challenge_ignores_wrong_exercise_and_flagged(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    user = await make_user()
    headers = auth_headers(user)
    wrong = await client.post(
        SESSIONS, json=payload("squat", reps=30, duration_s=120), headers=headers
    )
    assert wrong.json()["challenge"] is None
    flagged = await client.post(
        SESSIONS, json=payload("pullup", reps=20, duration_s=5), headers=headers
    )
    assert flagged.json()["status"] == "flagged"
    assert flagged.json()["challenge"] is None
    state = (await client.get(CHALLENGES, headers=headers)).json()
    assert (state["step"], state["progress"]) == (0, 0)


async def test_challenge_state_for_new_user_and_auth(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    user = await make_user()
    state = (await client.get(CHALLENGES, headers=auth_headers(user))).json()
    assert (state["step"], state["finished"]) == (0, False)
    assert (await client.get(CHALLENGES)).status_code == 401


async def test_void_reverses_challenge_coins(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: Callable[..., Awaitable[Trainer]],
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    coach = await make_user("admin", gym_id=gym.id)
    await make_trainer(coach)
    student = await make_user(gym_id=gym.id, trainer_id=coach.id)
    headers = auth_headers(student)
    body = payload("pullup", reps=20, duration_s=120)
    done = await client.post(SESSIONS, json=body, headers=headers)
    assert done.json()["total_coins"] == 20
    voided = await client.post(
        f"{SESSIONS}/{uuid.UUID(body['id']).hex}/void", headers=auth_headers(coach)
    )
    assert voided.status_code == 204
    me = (await client.get(ME, headers=headers)).json()
    assert me["coins"] == 0
    again = await client.post(
        f"{SESSIONS}/{uuid.UUID(body['id']).hex}/void", headers=auth_headers(coach)
    )
    assert again.status_code == 204
    assert (await client.get(ME, headers=headers)).json()["coins"] == 0
