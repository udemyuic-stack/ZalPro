import datetime
import uuid
from collections.abc import AsyncIterator, Awaitable, Callable
from typing import Any

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import ChallengeStep, User, UserChallenge

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

STEPS = "/v1/game/challenge-steps"
SESSIONS = "/v1/game/sessions"
CHALLENGES = "/v1/game/challenges"

SEED = [
    ("pullup", 20, 20, "arms"),
    ("pushup", 10, 15, "chest"),
    ("squat", 20, 15, "legs"),
    ("pullup", 30, 30, "arms"),
    ("pushup", 25, 30, "chest"),
    ("squat", 50, 30, "legs"),
    ("pullup", 50, 50, "arms"),
    ("pushup", 50, 50, "chest"),
    ("squat", 100, 50, "legs"),
    ("pullup", 100, 100, "arms"),
    ("pushup", 100, 100, "chest"),
    ("squat", 200, 100, "legs"),
]
NEW_STEP = {"exercise": "pushup", "target": 5, "coins": 7, "muscle": "chest"}


@pytest_asyncio.fixture(autouse=True)
async def restore_ladder(db_session: AsyncSession) -> AsyncIterator[None]:
    rows = list((await db_session.scalars(select(ChallengeStep))).all())
    snapshot = [
        {
            "id": row.id,
            "position": row.position,
            "exercise": row.exercise,
            "target": row.target,
            "coins": row.coins,
            "muscle": row.muscle,
        }
        for row in rows
    ]
    yield
    await db_session.rollback()
    await db_session.execute(delete(ChallengeStep))
    for values in snapshot:
        db_session.add(ChallengeStep(**values))
    await db_session.commit()


def session_payload(exercise: str, reps: int) -> dict[str, Any]:
    started = datetime.datetime.now(datetime.UTC) - datetime.timedelta(seconds=150)
    return {
        "id": str(uuid.uuid4()),
        "exercise": exercise,
        "reps": reps,
        "duration_s": 120,
        "visibility_pct": 95,
        "started_at": started.isoformat(),
    }


async def test_seed_matches_original_ladder(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    response = await client.get(STEPS, headers=auth_headers(owner))
    assert response.status_code == 200
    rows = response.json()
    assert [(row["exercise"], row["target"], row["coins"], row["muscle"]) for row in rows] == SEED
    assert [row["position"] for row in rows] == list(range(12))


@pytest.mark.parametrize("role", ["user", "admin", "barmen"])
async def test_non_owner_is_denied_everywhere(
    role: str, client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role)
    headers = auth_headers(actor)
    owner = await make_user("owner")
    first = (await client.get(STEPS, headers=auth_headers(owner))).json()[0]["id"]
    assert (await client.get(STEPS, headers=headers)).status_code == 403
    assert (await client.post(STEPS, json=NEW_STEP, headers=headers)).status_code == 403
    assert (
        await client.patch(f"{STEPS}/{first}", json={"target": 99}, headers=headers)
    ).status_code == 403
    assert (await client.delete(f"{STEPS}/{first}", headers=headers)).status_code == 403
    count = len((await client.get(STEPS, headers=auth_headers(owner))).json())
    assert count == 12


async def test_anonymous_is_unauthorized(client: AsyncClient) -> None:
    assert (await client.get(STEPS)).status_code == 401
    assert (await client.post(STEPS, json=NEW_STEP)).status_code == 401
    assert (await client.patch(f"{STEPS}/x", json={"target": 9})).status_code == 401
    assert (await client.delete(f"{STEPS}/x")).status_code == 401


async def test_create_appends_next_position(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    headers = auth_headers(owner)
    created = await client.post(STEPS, json=NEW_STEP, headers=headers)
    assert created.status_code == 201
    body = created.json()
    assert (body["position"], body["exercise"], body["target"], body["coins"]) == (
        12,
        "pushup",
        5,
        7,
    )
    listed = (await client.get(STEPS, headers=headers)).json()
    assert [row["position"] for row in listed] == list(range(13))
    user = await make_user()
    state = (await client.get(CHALLENGES, headers=auth_headers(user))).json()
    assert len(state["steps"]) == 13


@pytest.mark.parametrize(
    "change",
    [
        {"target": 0},
        {"target": -1},
        {"coins": -1},
        {"exercise": "teleport"},
        {"exercise": ""},
        {"muscle": "back"},
        {"extra": 1},
    ],
)
async def test_create_rejects_invalid_input(
    change: dict[str, Any],
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    headers = auth_headers(owner)
    response = await client.post(STEPS, json={**NEW_STEP, **change}, headers=headers)
    assert response.status_code in {400, 422}
    assert len((await client.get(STEPS, headers=headers)).json()) == 12


async def test_patch_changes_fields_and_rejects_bad_values(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    headers = auth_headers(owner)
    first = (await client.get(STEPS, headers=headers)).json()[0]
    patched = await client.patch(
        f"{STEPS}/{first['id']}", json={"target": 3, "coins": 9}, headers=headers
    )
    assert patched.status_code == 200
    assert (patched.json()["target"], patched.json()["coins"]) == (3, 9)
    assert patched.json()["position"] == 0
    assert (
        await client.patch(f"{STEPS}/{first['id']}", json={"target": None}, headers=headers)
    ).status_code == 422
    assert (
        await client.patch(f"{STEPS}/{first['id']}", json={"exercise": "teleport"}, headers=headers)
    ).status_code == 400
    assert (
        await client.patch(f"{STEPS}/{first['id']}", json={"position": 5}, headers=headers)
    ).status_code == 422
    assert (
        await client.patch(f"{STEPS}/missing", json={"target": 3}, headers=headers)
    ).status_code == 404


async def test_patched_target_is_used_by_sessions(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    first = (await client.get(STEPS, headers=auth_headers(owner))).json()[0]
    await client.patch(
        f"{STEPS}/{first['id']}", json={"target": 5, "coins": 11}, headers=auth_headers(owner)
    )
    member = await make_user()
    headers = auth_headers(member)
    result = await client.post(SESSIONS, json=session_payload("pullup", 5), headers=headers)
    challenge = result.json()["challenge"]
    assert (challenge["completed"], challenge["coins"]) == (True, 11)


async def test_delete_rules(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    headers = auth_headers(owner)
    steps = (await client.get(STEPS, headers=headers)).json()
    assert (await client.delete(f"{STEPS}/{steps[3]['id']}", headers=headers)).status_code == 409
    assert (await client.delete(f"{STEPS}/missing", headers=headers)).status_code == 404
    last = steps[-1]["id"]
    member = await make_user()
    db_session.add(UserChallenge(user_id=member.id, step=11))
    await db_session.commit()
    assert (await client.delete(f"{STEPS}/{last}", headers=headers)).status_code == 409
    await db_session.execute(update(UserChallenge).values(step=10))
    await db_session.commit()
    assert (await client.delete(f"{STEPS}/{last}", headers=headers)).status_code == 204
    assert len((await client.get(STEPS, headers=headers)).json()) == 11


async def test_finished_user_sees_new_step_as_current(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    member = await make_user()
    db_session.add(UserChallenge(user_id=member.id, step=12))
    await db_session.commit()
    before = (await client.get(CHALLENGES, headers=auth_headers(member))).json()
    assert before["finished"] is True
    await client.post(STEPS, json=NEW_STEP, headers=auth_headers(owner))
    after = (await client.get(CHALLENGES, headers=auth_headers(member))).json()
    assert after["finished"] is False
    assert after["steps"][12]["state"] == "current"
