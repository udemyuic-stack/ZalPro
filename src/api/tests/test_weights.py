import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import User, Weight

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]


def url(user: User) -> str:
    return f"/v1/users/{user.id}/weights"


async def set_last_weigh_in(db_session: AsyncSession, user: User, age: timedelta) -> None:
    await db_session.execute(
        update(User).where(User.id == user.id).values(last_weigh_in=datetime.now(UTC) - age)
    )
    await db_session.commit()


async def weight_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Weight)) or 0


async def reload_user(db_session: AsyncSession, user: User) -> User:
    await db_session.refresh(user)
    return user


async def test_first_weigh_in_with_zero_weight_and_no_history_is_created(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user(weight=0.0)
    before = datetime.now(UTC)

    response = await client.post(url(student), headers=auth_headers(student), json={"weight": 72.5})

    assert response.status_code == 201
    body = response.json()
    assert set(body) == {"id", "date", "weight"}
    assert body["weight"] == 72.5
    refreshed = await reload_user(db_session, student)
    assert refreshed.weight == 72.5
    assert refreshed.last_weigh_in is not None
    assert refreshed.last_weigh_in >= before
    assert datetime.fromisoformat(body["date"]) == refreshed.last_weigh_in
    assert await weight_count(db_session) == 1


async def test_first_weigh_in_with_profile_weight_and_no_history_is_created(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user(weight=80.0)

    response = await client.post(url(student), headers=auth_headers(student), json={"weight": 79})

    assert response.status_code == 201


async def test_second_weigh_in_right_after_the_first_is_409(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    headers = auth_headers(student)
    first = await client.post(url(student), headers=headers, json={"weight": 70})
    stamped = (await reload_user(db_session, student)).last_weigh_in

    second = await client.post(url(student), headers=headers, json={"weight": 69})

    assert first.status_code == 201
    assert second.status_code == 409
    assert second.json()["detail"]["code"] == "weigh_in_too_soon"
    assert await weight_count(db_session) == 1
    refreshed = await reload_user(db_session, student)
    assert refreshed.weight == 70
    assert refreshed.last_weigh_in == stamped


async def test_weigh_in_5_days_23_hours_after_the_last_is_409_with_next_time(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user(weight=75.0)
    await set_last_weigh_in(db_session, student, timedelta(days=5, hours=23))
    stamped = (await reload_user(db_session, student)).last_weigh_in

    response = await client.post(url(student), headers=auth_headers(student), json={"weight": 74})

    assert response.status_code == 409
    detail = response.json()["detail"]
    assert detail["code"] == "weigh_in_too_soon"
    assert (stamped + timedelta(days=6)).isoformat() in detail["message"]
    assert await weight_count(db_session) == 0
    assert (await reload_user(db_session, student)).weight == 75.0


async def test_weigh_in_6_days_and_a_moment_after_the_last_is_201(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user(weight=75.0)
    await set_last_weigh_in(db_session, student, timedelta(days=6, seconds=5))

    response = await client.post(url(student), headers=auth_headers(student), json={"weight": 74})

    assert response.status_code == 201
    refreshed = await reload_user(db_session, student)
    assert refreshed.weight == 74
    assert refreshed.last_weigh_in > datetime.now(UTC) - timedelta(minutes=1)


async def test_weigh_in_long_after_the_last_is_201(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user(weight=90.0)
    await set_last_weigh_in(db_session, student, timedelta(days=8))

    response = await client.post(url(student), headers=auth_headers(student), json={"weight": 88})

    assert response.status_code == 201


async def test_patching_profile_weight_does_not_start_the_weekly_window(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user(weight=0.0)
    headers = auth_headers(student)

    patch = await client.patch(f"/v1/users/{student.id}", headers=headers, json={"weight": 65})
    post = await client.post(url(student), headers=headers, json={"weight": 64})

    assert patch.status_code == 200
    assert patch.json()["last_weigh_in"] is None
    assert post.status_code == 201


@pytest.mark.parametrize("who", ["trainer", "owner", "stranger", "barmen"])
async def test_nobody_but_the_user_can_post_a_weight(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    who: str,
) -> None:
    trainer = await make_user(role="admin")
    student = await make_user(trainer_id=trainer.id, weight=70.0)
    actors = {
        "trainer": trainer,
        "owner": await make_user(role="owner"),
        "stranger": await make_user(),
        "barmen": await make_user(role="barmen"),
    }

    response = await client.post(
        url(student), headers=auth_headers(actors[who]), json={"weight": 60}
    )

    assert response.status_code == 403
    assert await weight_count(db_session) == 0
    refreshed = await reload_user(db_session, student)
    assert refreshed.weight == 70.0
    assert refreshed.last_weigh_in is None


async def test_anonymous_cannot_post_a_weight(client: AsyncClient, make_user: UserFactory) -> None:
    student = await make_user()

    response = await client.post(url(student), json={"weight": 60})

    assert response.status_code == 401


@pytest.mark.parametrize("role", ["admin", "owner", "barmen"])
async def test_every_role_can_weigh_itself(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    actor = await make_user(role=role)

    response = await client.post(url(actor), headers=auth_headers(actor), json={"weight": 80})

    assert response.status_code == 201


async def test_posting_to_unknown_user_is_403_for_everyone_else(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.post(
        "/v1/users/missing/weights", headers=auth_headers(owner), json={"weight": 60}
    )

    assert response.status_code == 403


@pytest.mark.parametrize(
    "body",
    [
        {"weight": 0},
        {"weight": -1},
        {"weight": 500.1},
        {"weight": "heavy"},
        {"weight": None},
        {"weight": 70, "date": "2026-01-01"},
        {},
    ],
)
async def test_invalid_weight_is_422(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    body: dict[str, Any],
) -> None:
    student = await make_user()

    response = await client.post(url(student), headers=auth_headers(student), json=body)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await weight_count(db_session) == 0
    assert (await reload_user(db_session, student)).last_weigh_in is None


@pytest.mark.parametrize("value", [500, 0.1])
async def test_weight_boundaries_are_accepted(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, value: float
) -> None:
    student = await make_user()

    response = await client.post(
        url(student), headers=auth_headers(student), json={"weight": value}
    )

    assert response.status_code == 201
    assert response.json()["weight"] == value


async def test_non_json_number_literals_are_rejected(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    response = await client.post(
        url(student),
        headers={**auth_headers(student), "Content-Type": "application/json"},
        content='{"weight": NaN}',
    )

    assert response.status_code == 422


async def test_parallel_weigh_ins_yield_exactly_one_success(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user(weight=80.0)
    headers = auth_headers(student)

    results = await asyncio.gather(
        *(client.post(url(student), headers=headers, json={"weight": 70 + n}) for n in range(6))
    )

    assert sorted(r.status_code for r in results) == [201, 409, 409, 409, 409, 409]
    assert await weight_count(db_session) == 1
    winner = next(r for r in results if r.status_code == 201).json()
    assert (await reload_user(db_session, student)).weight == winner["weight"]


async def test_parallel_weigh_ins_after_the_window_still_yield_one_success(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user(weight=80.0)
    await set_last_weigh_in(db_session, student, timedelta(days=7))
    headers = auth_headers(student)

    results = await asyncio.gather(
        client.post(url(student), headers=headers, json={"weight": 71}),
        client.post(url(student), headers=headers, json={"weight": 72}),
    )

    assert sorted(r.status_code for r in results) == [201, 409]
    assert await weight_count(db_session) == 1


async def test_weigh_ins_of_different_users_do_not_block_each_other(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    first = await make_user()
    second = await make_user()

    results = await asyncio.gather(
        client.post(url(first), headers=auth_headers(first), json={"weight": 70}),
        client.post(url(second), headers=auth_headers(second), json={"weight": 60}),
    )

    assert [r.status_code for r in results] == [201, 201]
    assert await weight_count(db_session) == 2


@pytest.mark.parametrize("who", ["self", "trainer", "owner"])
async def test_allowed_roles_list_weights_in_date_order(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    who: str,
) -> None:
    trainer = await make_user(role="admin")
    owner = await make_user(role="owner")
    student = await make_user(trainer_id=trainer.id)
    now = datetime.now(UTC)
    for days_ago, value in ((1, 71.0), (10, 73.0), (5, 72.0)):
        db_session.add(
            Weight(user_id=student.id, date=now - timedelta(days=days_ago), weight=value)
        )
    await db_session.commit()
    actor = {"self": student, "trainer": trainer, "owner": owner}[who]

    response = await client.get(url(student), headers=auth_headers(actor))

    assert response.status_code == 200
    assert [item["weight"] for item in response.json()] == [73.0, 72.0, 71.0]
    assert set(response.json()[0]) == {"id", "date", "weight"}


async def test_list_is_empty_without_weights(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    response = await client.get(url(student), headers=auth_headers(student))

    assert response.status_code == 200
    assert response.json() == []


async def test_list_contains_only_the_requested_users_weights(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    first = await make_user()
    second = await make_user()
    await client.post(url(first), headers=auth_headers(first), json={"weight": 70})
    await client.post(url(second), headers=auth_headers(second), json={"weight": 60})

    response = await client.get(url(first), headers=auth_headers(first))

    assert [item["weight"] for item in response.json()] == [70.0]


@pytest.mark.parametrize("who", ["stranger", "other_trainer", "barmen"])
async def test_other_roles_cannot_list_weights(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, who: str
) -> None:
    trainer = await make_user(role="admin")
    student = await make_user(trainer_id=trainer.id)
    actors = {
        "stranger": await make_user(),
        "other_trainer": await make_user(role="admin"),
        "barmen": await make_user(role="barmen"),
    }

    response = await client.get(url(student), headers=auth_headers(actors[who]))

    assert response.status_code == 403


async def test_anonymous_cannot_list_weights(client: AsyncClient, make_user: UserFactory) -> None:
    student = await make_user()

    response = await client.get(url(student))

    assert response.status_code == 401


async def test_listing_unknown_user_weights_is_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.get("/v1/users/missing/weights", headers=auth_headers(owner))

    assert response.status_code == 404


async def test_list_limit_returns_most_recent_entries_in_ascending_order(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    now = datetime.now(UTC)
    for days_ago in range(5, 0, -1):
        db_session.add(
            Weight(user_id=student.id, date=now - timedelta(days=days_ago), weight=float(days_ago))
        )
    await db_session.commit()

    response = await client.get(url(student), headers=auth_headers(student), params={"limit": 2})

    assert [item["weight"] for item in response.json()] == [2.0, 1.0]


@pytest.mark.parametrize("limit", ["0", "-1", "501", "abc"])
async def test_list_limit_is_validated(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, limit: str
) -> None:
    student = await make_user()

    response = await client.get(
        url(student), headers=auth_headers(student), params={"limit": limit}
    )

    assert response.status_code == 422


async def test_list_limit_500_is_accepted(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    response = await client.get(url(student), headers=auth_headers(student), params={"limit": 500})

    assert response.status_code == 200


async def test_weights_are_removed_with_their_user(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    student = await make_user()
    await client.post(url(student), headers=auth_headers(student), json={"weight": 70})

    response = await client.delete(f"/v1/users/{student.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert await weight_count(db_session) == 0
