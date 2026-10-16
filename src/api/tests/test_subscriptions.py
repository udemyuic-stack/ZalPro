from collections.abc import Awaitable, Callable
from datetime import UTC, date, datetime
from typing import Any
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Gym, Membership, Subscription, User
from zalpro_api.services import subscriptions as subscriptions_service
from zalpro_api.services.subscriptions import add_months, compute_expiry

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
SubscriptionFactory = Callable[..., Awaitable[Subscription]]
GymFactory = Callable[..., Awaitable[Gym]]

ZONE = ZoneInfo("Asia/Tashkent")


def local_midnight(year: int, month: int, day: int) -> datetime:
    return datetime(year, month, day, tzinfo=ZONE)


def payload(**fields: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "start_date": "2026-01-15T00:00:00+05:00",
        "months": 1,
        "days": 0,
        "price": 450000,
        "currency": "UZS",
    }
    return {**body, **fields}


def collection(user: User) -> str:
    return f"/v1/users/{user.id}/subscriptions"


async def count_rows(db_session: AsyncSession, model: type) -> int:
    return await db_session.scalar(select(func.count()).select_from(model)) or 0


@pytest.mark.parametrize(
    ("start", "months", "expected"),
    [
        (date(2026, 1, 15), 1, date(2026, 2, 15)),
        (date(2026, 1, 15), 3, date(2026, 4, 15)),
        (date(2026, 1, 15), 12, date(2027, 1, 15)),
        (date(2026, 1, 15), 24, date(2028, 1, 15)),
        (date(2026, 11, 15), 3, date(2027, 2, 15)),
        (date(2026, 12, 15), 1, date(2027, 1, 15)),
        (date(2026, 1, 31), 1, date(2026, 3, 3)),
        (date(2024, 1, 31), 1, date(2024, 3, 2)),
        (date(2026, 8, 30), 6, date(2027, 3, 2)),
        (date(2023, 8, 30), 6, date(2024, 3, 1)),
        (date(2026, 12, 31), 2, date(2027, 3, 3)),
        (date(2023, 12, 31), 2, date(2024, 3, 2)),
        (date(2024, 2, 29), 24, date(2026, 3, 1)),
        (date(2026, 1, 29), 1, date(2026, 3, 1)),
        (date(2024, 1, 29), 1, date(2024, 2, 29)),
        (date(2026, 3, 31), 1, date(2026, 5, 1)),
    ],
)
def test_add_months_follows_the_dart_overflow_rule(
    start: date, months: int, expected: date
) -> None:
    assert add_months(start, months) == expected


@pytest.mark.parametrize(
    ("start", "days", "expected"),
    [
        (date(2026, 1, 15), 1, date(2026, 1, 15)),
        (date(2026, 1, 15), 5, date(2026, 1, 19)),
        (date(2026, 10, 30), 5, date(2026, 11, 3)),
        (date(2026, 12, 20), 31, date(2027, 1, 19)),
        (date(2024, 2, 27), 3, date(2024, 2, 29)),
    ],
)
def test_daily_expiry_includes_the_start_day(start: date, days: int, expected: date) -> None:
    start_at = datetime(start.year, start.month, start.day, 9, 30, tzinfo=ZONE)
    result = compute_expiry(start_at, 0, days, ZONE)
    assert result == local_midnight(expected.year, expected.month, expected.day)


def test_monthly_expiry_is_local_midnight_in_the_gym_timezone() -> None:
    start = datetime(2026, 1, 15, 13, 45, tzinfo=ZONE)
    result = compute_expiry(start, 1, 0, ZONE)
    assert result == datetime(2026, 2, 14, 19, 0, tzinfo=UTC)
    assert result.astimezone(ZONE).hour == 0


def test_expiry_uses_the_local_day_not_the_utc_day() -> None:
    late_utc = datetime(2026, 1, 14, 20, 0, tzinfo=UTC)
    early_utc = datetime(2026, 1, 14, 18, 0, tzinfo=UTC)
    assert compute_expiry(late_utc, 1, 0, ZONE) == local_midnight(2026, 2, 15)
    assert compute_expiry(early_utc, 1, 0, ZONE) == local_midnight(2026, 2, 14)
    assert compute_expiry(late_utc, 0, 1, ZONE) == local_midnight(2026, 1, 15)


def test_expiry_in_utc_zone_is_utc_midnight() -> None:
    start = datetime(2026, 1, 31, 23, 0, tzinfo=UTC)
    assert compute_expiry(start, 1, 0, ZoneInfo("UTC")) == datetime(2026, 3, 3, tzinfo=UTC)


async def test_owner_creates_a_subscription_and_the_response_has_the_documented_shape(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    student = await make_user()

    response = await client.post(collection(student), headers=auth_headers(owner), json=payload())

    assert response.status_code == 201
    body = response.json()
    assert set(body) == {
        "id",
        "user_id",
        "start_date",
        "months",
        "days",
        "price",
        "currency",
        "paid_date",
        "created_at",
        "paid_at",
        "expires_at",
    }
    assert body["user_id"] == student.id
    assert body["paid_date"] is None
    assert body["paid_at"] == body["created_at"]
    assert datetime.fromisoformat(body["expires_at"]) == local_midnight(2026, 2, 15)


async def test_the_clients_own_trainer_creates_a_subscription(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    trainer = await make_user("admin")
    student = await make_user(trainer_id=trainer.id)

    response = await client.post(
        collection(student), headers=auth_headers(trainer), json=payload(months=3)
    )

    assert response.status_code == 201


@pytest.mark.parametrize("actor_kind", ["other_trainer", "barmen", "self", "other_user"])
async def test_unauthorized_actors_get_403_and_nothing_is_written(
    actor_kind: str,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    trainer = await make_user("admin")
    student = await make_user(trainer_id=trainer.id)
    actors = {
        "other_trainer": await make_user("admin"),
        "barmen": await make_user("barmen"),
        "self": student,
        "other_user": await make_user(),
    }

    response = await client.post(
        collection(student), headers=auth_headers(actors[actor_kind]), json=payload()
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await count_rows(db_session, Subscription) == 0
    assert await count_rows(db_session, Membership) == 0
    await db_session.refresh(student)
    assert student.subscription_expires_at is None


async def test_trainer_cannot_create_a_subscription_for_a_client_without_a_trainer(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    trainer = await make_user("admin")
    student = await make_user()

    response = await client.post(collection(student), headers=auth_headers(trainer), json=payload())

    assert response.status_code == 403


async def test_anonymous_post_is_401(client: AsyncClient, make_user: UserFactory) -> None:
    student = await make_user()

    response = await client.post(collection(student), json=payload())

    assert response.status_code == 401


@pytest.mark.parametrize(("role", "expected"), [("owner", 404), ("admin", 404), ("user", 403)])
async def test_missing_target_user(
    role: str,
    expected: int,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role)

    response = await client.post(
        "/v1/users/missing/subscriptions", headers=auth_headers(actor), json=payload()
    )

    assert response.status_code == expected


async def test_barmen_gets_403_for_a_missing_target(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    barmen = await make_user("barmen")

    response = await client.post(
        "/v1/users/missing/subscriptions", headers=auth_headers(barmen), json=payload()
    )

    assert response.status_code == 403


async def test_post_updates_the_profile_expiry_and_writes_the_membership_mirror(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()
    trainer = await make_user("admin", gym_id=gym.id)
    student = await make_user(trainer_id=trainer.id, name="Aziz Karimov")
    paid = "2026-01-10T10:00:00+05:00"

    response = await client.post(
        collection(student),
        headers=auth_headers(trainer),
        json=payload(months=0, days=5, price=70, currency="USD", paid_date=paid),
    )

    assert response.status_code == 201
    await db_session.refresh(student)
    assert student.subscription_expires_at == local_midnight(2026, 1, 19)
    membership = await db_session.get(Membership, student.id)
    assert membership is not None
    await db_session.refresh(membership)
    assert membership.name == "Aziz Karimov"
    assert membership.gym_id == gym.id
    assert (membership.months, membership.days) == (0, 5)
    assert (membership.price, membership.currency) == (70, "USD")
    assert membership.paid_date == datetime.fromisoformat(paid)
    assert membership.expires_at == local_midnight(2026, 1, 19)


@pytest.mark.parametrize("trainer_kind", ["none", "gymless"])
async def test_membership_gym_id_is_empty_without_a_trainer_or_a_trainer_gym(
    trainer_kind: str,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    trainer = await make_user("admin")
    student = await make_user(trainer_id=trainer.id if trainer_kind == "gymless" else None)

    response = await client.post(collection(student), headers=auth_headers(owner), json=payload())

    assert response.status_code == 201
    membership = await db_session.get(Membership, student.id)
    assert membership is not None
    assert membership.gym_id == ""


async def test_membership_without_paid_date_gets_a_server_timestamp(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    before = datetime.now(UTC)

    await client.post(collection(student), headers=auth_headers(owner), json=payload())

    membership = await db_session.get(Membership, student.id)
    assert membership is not None
    assert membership.paid_date >= before


async def test_second_subscription_overwrites_expiry_and_upserts_the_single_membership(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    first_gym = await make_gym()
    second_gym = await make_gym()
    trainer = await make_user("admin", gym_id=first_gym.id)
    owner = await make_user("owner")
    student = await make_user(trainer_id=trainer.id)
    headers = auth_headers(owner)

    await client.post(collection(student), headers=headers, json=payload(months=12))
    trainer.gym_id = second_gym.id
    await db_session.commit()
    await client.post(
        collection(student),
        headers=headers,
        json=payload(start_date="2025-01-01T00:00:00+05:00", months=1, price=1),
    )

    await db_session.refresh(student)
    assert student.subscription_expires_at == local_midnight(2025, 2, 1)
    assert await count_rows(db_session, Subscription) == 2
    assert await count_rows(db_session, Membership) == 1
    membership = await db_session.get(Membership, student.id)
    assert membership is not None
    await db_session.refresh(membership)
    assert membership.gym_id == second_gym.id
    assert membership.price == 1
    assert membership.expires_at == local_midnight(2025, 2, 1)


async def test_failure_after_the_subscription_insert_leaves_no_partial_state(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    owner = await make_user("owner")
    student = await make_user()

    async def failing_upsert(*args: Any, **kwargs: Any) -> None:
        raise RuntimeError("boom")

    monkeypatch.setattr(subscriptions_service, "upsert_membership", failing_upsert)

    with pytest.raises(RuntimeError):
        await client.post(collection(student), headers=auth_headers(owner), json=payload())

    assert await count_rows(db_session, Subscription) == 0
    assert await count_rows(db_session, Membership) == 0
    await db_session.refresh(student)
    assert student.subscription_expires_at is None


@pytest.mark.parametrize(
    "fields",
    [
        {"months": 1, "days": 5},
        {"months": 0, "days": 0},
        {"months": 25, "days": 0},
        {"months": 0, "days": 32},
        {"months": -1, "days": 0},
        {"price": -1},
        {"price": 2_147_483_648},
        {"price": 10.5},
        {"price": "100"},
        {"price": True},
        {"months": 1.0},
        {"currency": "EUR"},
        {"currency": "uzs"},
        {"start_date": "2026-01-15T00:00:00"},
        {"start_date": "2026-01-15"},
        {"start_date": "1999-12-31T00:00:00+05:00"},
        {"start_date": "2101-01-01T00:00:00+05:00"},
        {"paid_date": "2026-01-10T10:00:00"},
        {"paid_date": "1999-01-01T00:00:00+05:00"},
        {"created_at": "2026-01-01T00:00:00+00:00"},
        {"user_id": "x"},
        {"id": "x"},
        {"unknown": 1},
    ],
)
async def test_invalid_bodies_are_422_and_write_nothing(
    fields: dict[str, Any],
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    student = await make_user()

    response = await client.post(
        collection(student), headers=auth_headers(owner), json=payload(**fields)
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await count_rows(db_session, Subscription) == 0
    assert await count_rows(db_session, Membership) == 0


@pytest.mark.parametrize("missing", ["start_date", "price", "currency"])
async def test_required_fields_are_enforced(
    missing: str, client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    body = payload()
    del body[missing]

    response = await client.post(collection(student), headers=auth_headers(owner), json=body)

    assert response.status_code == 422


@pytest.mark.parametrize(
    ("fields", "status"),
    [
        ({"months": 24, "days": 0, "price": 0}, 201),
        ({"months": 0, "days": 31}, 201),
        ({"months": 0, "days": 1, "currency": "USD"}, 201),
    ],
)
async def test_boundary_values_are_accepted(
    fields: dict[str, Any],
    status: int,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()

    response = await client.post(
        collection(student), headers=auth_headers(owner), json=payload(**fields)
    )

    assert response.status_code == status


async def test_daily_subscription_of_one_day_expires_on_the_start_day(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    student = await make_user()

    response = await client.post(
        collection(student), headers=auth_headers(owner), json=payload(months=0, days=1)
    )

    assert datetime.fromisoformat(response.json()["expires_at"]) == local_midnight(2026, 1, 15)


async def test_post_overflowing_month_end_matches_the_documented_rule(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    student = await make_user()

    response = await client.post(
        collection(student),
        headers=auth_headers(owner),
        json=payload(start_date="2026-01-31T10:00:00+05:00", months=1),
    )

    assert datetime.fromisoformat(response.json()["expires_at"]) == local_midnight(2026, 3, 3)


@pytest.mark.parametrize("actor_kind", ["self", "trainer", "owner"])
async def test_allowed_actors_list_subscriptions_newest_start_first(
    actor_kind: str,
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    trainer = await make_user("admin")
    student = await make_user(trainer_id=trainer.id)
    actors = {"self": student, "trainer": trainer, "owner": await make_user("owner")}
    older = await make_subscription(student.id, start_date=datetime(2026, 1, 1, tzinfo=UTC))
    newer = await make_subscription(student.id, start_date=datetime(2026, 6, 1, tzinfo=UTC))

    response = await client.get(collection(student), headers=auth_headers(actors[actor_kind]))

    assert response.status_code == 200
    assert [item["id"] for item in response.json()] == [newer.id, older.id]
    assert all(item["user_id"] == student.id for item in response.json())


@pytest.mark.parametrize("actor_kind", ["other_trainer", "barmen", "other_user"])
async def test_other_actors_cannot_list_subscriptions(
    actor_kind: str,
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    trainer = await make_user("admin")
    student = await make_user(trainer_id=trainer.id)
    actors = {
        "other_trainer": await make_user("admin"),
        "barmen": await make_user("barmen"),
        "other_user": await make_user(),
    }
    await make_subscription(student.id)

    response = await client.get(collection(student), headers=auth_headers(actors[actor_kind]))

    assert response.status_code == 403


async def test_list_for_a_missing_user_is_404_and_anonymous_is_401(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    student = await make_user()

    missing = await client.get("/v1/users/missing/subscriptions", headers=auth_headers(owner))
    anonymous = await client.get(collection(student))

    assert missing.status_code == 404
    assert anonymous.status_code == 401


async def test_list_only_returns_the_requested_users_subscriptions(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    student = await make_user()
    other = await make_user()
    await make_subscription(other.id)

    response = await client.get(collection(student), headers=auth_headers(student))

    assert response.json() == []


async def test_subscriptions_have_no_update_or_delete_endpoints(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    subscription = await make_subscription(student.id)
    url = f"{collection(student)}/{subscription.id}"

    patch = await client.patch(url, headers=auth_headers(owner), json={"price": 1})
    delete = await client.delete(url, headers=auth_headers(owner))
    put = await client.put(collection(student), headers=auth_headers(owner), json=payload())

    assert {patch.status_code, delete.status_code, put.status_code} <= {404, 405}


async def window_ids(client: AsyncClient, headers: dict[str, str], start: str, end: str) -> list:
    response = await client.get(
        "/v1/subscriptions", headers=headers, params={"from": start, "to": end}
    )
    assert response.status_code == 200
    return [item["id"] for item in response.json()]


async def test_owner_lists_subscriptions_by_paid_at_window(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    first = await make_user()
    second = await make_user()
    inside = await make_subscription(
        first.id,
        start_date=datetime(2025, 1, 1, tzinfo=UTC),
        paid_date=datetime(2026, 3, 10, tzinfo=UTC),
    )
    fallback = await make_subscription(
        second.id,
        start_date=datetime(2025, 1, 1, tzinfo=UTC),
        created_at=datetime(2026, 3, 20, tzinfo=UTC),
    )
    outside = await make_subscription(
        first.id,
        start_date=datetime(2026, 3, 15, tzinfo=UTC),
        paid_date=datetime(2026, 5, 1, tzinfo=UTC),
        created_at=datetime(2026, 3, 15, tzinfo=UTC),
    )

    ids = await window_ids(
        client, auth_headers(owner), "2026-03-01T00:00:00+00:00", "2026-04-01T00:00:00+00:00"
    )

    assert ids == [fallback.id, inside.id]
    assert outside.id not in ids


async def test_window_is_inclusive_at_from_and_exclusive_at_to(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    at_from = await make_subscription(student.id, paid_date=datetime(2026, 3, 1, tzinfo=UTC))
    await make_subscription(student.id, paid_date=datetime(2026, 4, 1, tzinfo=UTC))

    ids = await window_ids(
        client, auth_headers(owner), "2026-03-01T00:00:00+00:00", "2026-04-01T00:00:00+00:00"
    )

    assert ids == [at_from.id]


async def test_window_items_carry_user_id_and_expiry(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_subscription(
        student.id,
        start_date=datetime(2026, 1, 14, 20, tzinfo=UTC),
        paid_date=datetime(2026, 3, 1, tzinfo=UTC),
    )

    response = await client.get(
        "/v1/subscriptions",
        headers=auth_headers(owner),
        params={"from": "2026-03-01T00:00:00+00:00", "to": "2026-04-01T00:00:00+00:00"},
    )

    item = response.json()[0]
    assert item["user_id"] == student.id
    assert datetime.fromisoformat(item["expires_at"]) == local_midnight(2026, 2, 15)


@pytest.mark.parametrize("role", ["admin", "barmen", "user"])
async def test_only_the_owner_can_list_the_window(
    role: str, client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role)

    response = await client.get(
        "/v1/subscriptions",
        headers=auth_headers(actor),
        params={"from": "2026-03-01T00:00:00+00:00", "to": "2026-04-01T00:00:00+00:00"},
    )

    assert response.status_code == 403


async def test_anonymous_window_is_401(client: AsyncClient) -> None:
    response = await client.get(
        "/v1/subscriptions",
        params={"from": "2026-03-01T00:00:00+00:00", "to": "2026-04-01T00:00:00+00:00"},
    )

    assert response.status_code == 401


@pytest.mark.parametrize(
    "params",
    [
        {"from": "2026-03-01T00:00:00+00:00"},
        {"from": "2026-03-01T00:00:00", "to": "2026-04-01T00:00:00"},
        {"from": "2026-04-01T00:00:00+00:00", "to": "2026-03-01T00:00:00+00:00"},
        {"from": "2026-03-01T00:00:00+00:00", "to": "2026-03-01T00:00:00+00:00"},
        {"from": "x", "to": "y"},
        {"from": "2026-03-01T00:00:00+00:00", "to": "2026-04-01T00:00:00+00:00", "extra": "1"},
    ],
)
async def test_invalid_window_is_422(
    params: dict[str, str],
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")

    response = await client.get("/v1/subscriptions", headers=auth_headers(owner), params=params)

    assert response.status_code == 422
