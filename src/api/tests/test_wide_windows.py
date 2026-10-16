from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient

from zalpro_api.models import Gym, Order, Subscription, User
from zalpro_api.models import Reminder as ReminderModel

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
SubscriptionFactory = Callable[..., Awaitable[Subscription]]
OrderFactory = Callable[..., Awaitable[Order]]
GymFactory = Callable[..., Awaitable[Gym]]


def utc(*parts: int) -> datetime:
    return datetime(*parts, tzinfo=UTC)


async def add_reminder(db_session, client_id: str, trainer_id: str, sent_at: datetime) -> None:
    db_session.add(
        ReminderModel(
            client_id=client_id,
            client_name="C",
            trainer_id=trainer_id,
            sent_by=trainer_id,
            sent_at=sent_at,
            days_left=3,
        )
    )
    await db_session.commit()


async def test_owner_lists_all_orders_without_a_window(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    old = await make_order(user.id, created_at=utc(2019, 1, 1))
    new = await make_order(user.id, created_at=utc(2026, 10, 1))

    response = await client.get("/v1/orders", headers=auth_headers(owner))

    assert response.status_code == 200
    assert {item["id"] for item in response.json()} == {old.id, new.id}


async def test_owner_lists_all_reminders_without_a_window(
    client: AsyncClient,
    make_user: UserFactory,
    db_session,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    await add_reminder(db_session, "a", "t", utc(2019, 1, 1))
    await add_reminder(db_session, "b", "t", utc(2026, 10, 1))

    response = await client.get("/v1/reminders", headers=auth_headers(owner))

    assert response.status_code == 200
    assert len(response.json()) == 2


async def test_owner_lists_all_subscriptions_without_a_window(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    await make_subscription(user.id, paid_date=utc(2018, 1, 1))
    await make_subscription(user.id, paid_date=utc(2026, 10, 1))

    response = await client.get("/v1/subscriptions", headers=auth_headers(owner))

    assert response.status_code == 200
    assert len(response.json()) == 2


@pytest.mark.parametrize("url", ["/v1/orders", "/v1/reminders"])
@pytest.mark.parametrize("params", [{"from": "2026-10-01"}, {"to": "2026-10-01"}])
async def test_owner_with_a_half_window_is_still_422(
    url: str,
    params: dict[str, str],
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")

    response = await client.get(url, headers=auth_headers(owner), params=params)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


@pytest.mark.parametrize("url", ["/v1/orders", "/v1/reminders"])
@pytest.mark.parametrize("role", ["admin", "barmen", "user"])
async def test_non_owner_without_a_window_is_422(
    url: str,
    role: str,
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role)

    response = await client.get(url, headers=auth_headers(actor))

    assert response.status_code == 422
    body = response.json()["detail"]
    assert body["code"] == "validation_error"
    assert {item["field"] for item in body["errors"]} == {"query.from", "query.to"}


async def test_non_owner_keeps_the_400_day_cap(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    trainer = await make_user("admin")

    response = await client.get(
        "/v1/reminders",
        headers=auth_headers(trainer),
        params={"from": "2025-01-01", "to": "2026-12-31"},
    )

    assert response.status_code == 422


async def test_subscriptions_stay_owner_only(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    trainer = await make_user("admin")

    response = await client.get("/v1/subscriptions", headers=auth_headers(trainer))

    assert response.status_code == 403


async def test_finance_gym_filter_and_trainer_breakdown(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_subscription: SubscriptionFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    gym_a = await make_gym()
    gym_b = await make_gym()
    trainer_a = await make_user("admin", gym_id=gym_a.id)
    trainer_b = await make_user("admin", gym_id=gym_b.id)
    in_a = await make_user(trainer_id=trainer_a.id)
    in_a_two = await make_user(trainer_id=trainer_a.id)
    in_b = await make_user(trainer_id=trainer_b.id)
    loose = await make_user()
    when = utc(2026, 10, 5)
    await make_subscription(in_a.id, price=100, paid_date=when)
    await make_subscription(in_a_two.id, price=50, paid_date=when)
    await make_subscription(in_a.id, price=7, currency="USD", paid_date=when)
    await make_subscription(in_b.id, price=900, paid_date=when)
    await make_subscription(loose.id, price=11, paid_date=when)
    await make_subscription(in_a.id, price=999, paid_date=utc(2026, 9, 5))
    await make_order(in_a.id, gym_id=gym_a.id, status="given", given_at=when, price=30)
    await make_order(in_b.id, gym_id=gym_b.id, status="given", given_at=when, price=40)
    headers = auth_headers(owner)

    everything = await client.get(
        "/v1/finance/monthly", headers=headers, params={"month": "2026-10"}
    )
    only_a = await client.get(
        "/v1/finance/monthly", headers=headers, params={"month": "2026-10", "gym_id": gym_a.id}
    )
    no_gym = await client.get(
        "/v1/finance/monthly", headers=headers, params={"month": "2026-10", "gym_id": ""}
    )

    assert everything.json()["subs_count"] == 5
    assert everything.json()["orders_count"] == 2
    assert {item["trainer_id"] for item in everything.json()["trainers"]} == {
        trainer_a.id,
        trainer_b.id,
        "",
    }
    assert everything.json()["trainers"][0]["trainer_id"] == trainer_b.id
    body = only_a.json()
    assert body["subs_count"] == 3
    assert body["subs_sums"] == {"UZS": 150, "USD": 7}
    assert body["orders_count"] == 1
    assert body["shop_sums"] == {"UZS": 30}
    assert body["trainers"] == [
        {
            "trainer_id": trainer_a.id,
            "name": trainer_a.name,
            "clients": 2,
            "subs_count": 3,
            "subs_sums": {"UZS": 150, "USD": 7},
        }
    ]
    assert no_gym.json()["subs_count"] == 1
    assert no_gym.json()["trainers"] == [
        {"trainer_id": "", "name": "", "clients": 1, "subs_count": 1, "subs_sums": {"UZS": 11}}
    ]


async def test_finance_gym_filter_stays_owner_only(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    trainer = await make_user("admin")

    response = await client.get(
        "/v1/finance/monthly",
        headers=auth_headers(trainer),
        params={"month": "2026-10", "gym_id": "x"},
    )

    assert response.status_code == 403
