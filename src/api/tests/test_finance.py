from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient

from zalpro_api.models import Order, Product, Subscription, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
SubscriptionFactory = Callable[..., Awaitable[Subscription]]
ProductFactory = Callable[..., Awaitable[Product]]
OrderFactory = Callable[..., Awaitable[Order]]

URL = "/v1/finance/monthly"


def utc(*parts: int) -> datetime:
    return datetime(*parts, tzinfo=UTC)


async def report(client: AsyncClient, owner: User, headers: HeadersFactory, month: str) -> dict:
    response = await client.get(URL, headers=headers(owner), params={"month": month})
    assert response.status_code == 200
    return response.json()


async def test_report_has_the_documented_shape_and_is_empty_without_data(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")

    body = await report(client, owner, auth_headers, "2026-10")

    assert body == {
        "month": "2026-10",
        "subs_count": 0,
        "subs_sums": {},
        "orders_count": 0,
        "shop_sums": {},
        "profit": {},
        "no_cost_orders": 0,
        "trainers": [],
    }


async def test_hand_calculated_month_matches_the_dart_report(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    first = await make_user()
    second = await make_user()
    await make_subscription(first.id, price=450000, paid_date=utc(2026, 10, 5, 10))
    await make_subscription(first.id, price=300000, paid_date=utc(2026, 10, 20))
    await make_subscription(second.id, price=70, currency="USD", paid_date=utc(2026, 10, 7))
    await make_subscription(second.id, price=60, currency="USD", paid_date=utc(2026, 10, 25))
    await make_subscription(second.id, price=999, paid_date=utc(2026, 9, 5))
    await make_subscription(second.id, price=888, paid_date=utc(2026, 11, 5))

    body = await report(client, owner, auth_headers, "2026-10")

    assert body["subs_count"] == 4
    assert body["subs_sums"] == {"UZS": 750000, "USD": 130}


@pytest.mark.parametrize(
    ("paid_at", "month", "counted"),
    [
        (utc(2026, 9, 30, 19, 0), "2026-10", True),
        (utc(2026, 9, 30, 18, 59, 59), "2026-10", False),
        (utc(2026, 9, 30, 18, 59, 59), "2026-09", True),
        (utc(2026, 10, 31, 18, 59, 59), "2026-10", True),
        (utc(2026, 10, 31, 19, 0), "2026-10", False),
        (utc(2026, 10, 31, 19, 0), "2026-11", True),
        (utc(2026, 12, 31, 18, 59), "2026-12", True),
        (utc(2026, 12, 31, 19, 0), "2026-12", False),
        (utc(2026, 12, 31, 19, 0), "2027-01", True),
    ],
)
async def test_month_boundaries_follow_the_gym_timezone(
    paid_at: datetime,
    month: str,
    counted: bool,
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_subscription(student.id, paid_date=paid_at, price=100)

    body = await report(client, owner, auth_headers, month)

    assert body["subs_count"] == (1 if counted else 0)
    assert body["subs_sums"] == ({"UZS": 100} if counted else {})


async def test_missing_paid_date_falls_back_to_created_at_then_start_date_is_ignored(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_subscription(
        student.id, start_date=utc(2026, 8, 1), created_at=utc(2026, 10, 3), price=100
    )
    await make_subscription(
        student.id,
        start_date=utc(2026, 10, 1),
        created_at=utc(2026, 8, 3),
        paid_date=utc(2026, 8, 4),
        price=7,
    )

    october = await report(client, owner, auth_headers, "2026-10")
    august = await report(client, owner, auth_headers, "2026-08")

    assert october["subs_sums"] == {"UZS": 100}
    assert august["subs_sums"] == {"UZS": 7}
    assert august["subs_count"] == 1


async def test_paid_date_wins_over_created_at(
    client: AsyncClient,
    make_user: UserFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_subscription(
        student.id, created_at=utc(2026, 10, 3), paid_date=utc(2026, 7, 3), price=5
    )

    assert (await report(client, owner, auth_headers, "2026-10"))["subs_count"] == 0
    assert (await report(client, owner, auth_headers, "2026-07"))["subs_count"] == 1


@pytest.mark.parametrize("role", ["admin", "barmen", "user"])
async def test_only_the_owner_gets_the_report(
    role: str, client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role)

    response = await client.get(URL, headers=auth_headers(actor), params={"month": "2026-10"})

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"


async def test_anonymous_report_is_401(client: AsyncClient) -> None:
    response = await client.get(URL, params={"month": "2026-10"})

    assert response.status_code == 401


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"month": "2026-13"},
        {"month": "2026-00"},
        {"month": "2026-1"},
        {"month": "202610"},
        {"month": "abc"},
        {"month": "1999-12"},
        {"month": "2101-01"},
        {"month": "2026-10-01"},
        {"month": "2026-10", "extra": "1"},
    ],
)
async def test_invalid_month_is_422(
    params: dict[str, str],
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")

    response = await client.get(URL, headers=auth_headers(owner), params=params)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


async def test_shop_part_sums_profit_and_counts_per_currency(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    uzs = await make_product(price=100000, cost_price=60000)
    usd = await make_product(price=50, currency="USD", cost_price=30)
    await make_order(
        user.id, product_id=uzs.id, qty=2, price=100000, given_at=utc(2026, 10, 5), status="given"
    )
    await make_order(
        user.id, product_id=uzs.id, qty=1, price=90000, given_at=utc(2026, 10, 6), status="given"
    )
    await make_order(
        user.id,
        product_id=usd.id,
        qty=3,
        price=50,
        currency="USD",
        given_at=utc(2026, 10, 7),
        status="given",
    )

    body = await report(client, owner, auth_headers, "2026-10")

    assert body["orders_count"] == 3
    assert body["shop_sums"] == {"UZS": 290000, "USD": 150}
    assert body["profit"] == {"UZS": 110000, "USD": 60}
    assert body["no_cost_orders"] == 0
    assert body["subs_count"] == 0


async def test_profit_uses_order_price_and_current_cost_price(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(price=999999, cost_price=70)
    await make_order(
        user.id, product_id=product.id, qty=2, price=100, given_at=utc(2026, 10, 5), status="given"
    )

    body = await report(client, owner, auth_headers, "2026-10")

    assert body["shop_sums"] == {"UZS": 200}
    assert body["profit"] == {"UZS": 60}


async def test_zero_cost_and_deleted_products_are_counted_but_not_in_profit(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    free = await make_product(cost_price=0)
    paid = await make_product(cost_price=40)
    when = utc(2026, 10, 5)
    await make_order(user.id, product_id=free.id, price=100, qty=1, given_at=when, status="given")
    await make_order(user.id, product_id="gone", price=100, qty=1, given_at=when, status="given")
    await make_order(user.id, product_id=paid.id, price=100, qty=1, given_at=when, status="given")

    body = await report(client, owner, auth_headers, "2026-10")

    assert body["orders_count"] == 3
    assert body["shop_sums"] == {"UZS": 300}
    assert body["profit"] == {"UZS": 60}
    assert body["no_cost_orders"] == 2


async def test_only_given_orders_count(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product()
    when = utc(2026, 10, 5)
    await make_order(user.id, product_id=product.id, created_at=when, status="new")
    await make_order(user.id, product_id=product.id, created_at=when, status="canceled")

    body = await report(client, owner, auth_headers, "2026-10")

    assert body["orders_count"] == 0
    assert body["shop_sums"] == {}
    assert body["profit"] == {}


async def test_given_order_without_given_at_falls_back_to_created_at(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(cost_price=10)
    await make_order(
        user.id, product_id=product.id, price=100, created_at=utc(2026, 9, 20), status="given"
    )
    await make_order(
        user.id,
        product_id=product.id,
        price=100,
        created_at=utc(2026, 9, 20),
        given_at=utc(2026, 10, 2),
        status="given",
    )

    october = await report(client, owner, auth_headers, "2026-10")
    september = await report(client, owner, auth_headers, "2026-09")

    assert october["orders_count"] == 1
    assert september["orders_count"] == 1


@pytest.mark.parametrize(
    ("sold_at", "month", "counted"),
    [
        (utc(2026, 9, 30, 19, 0), "2026-10", True),
        (utc(2026, 9, 30, 18, 59, 59), "2026-10", False),
        (utc(2026, 9, 30, 18, 59, 59), "2026-09", True),
        (utc(2026, 10, 31, 18, 59, 59), "2026-10", True),
        (utc(2026, 10, 31, 19, 0), "2026-10", False),
        (utc(2026, 10, 31, 19, 0), "2026-11", True),
        (utc(2026, 12, 31, 19, 0), "2026-12", False),
        (utc(2026, 12, 31, 19, 0), "2027-01", True),
    ],
)
async def test_shop_month_boundaries_follow_gym_timezone(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
    sold_at: datetime,
    month: str,
    counted: bool,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(cost_price=10)
    await make_order(user.id, product_id=product.id, price=100, given_at=sold_at, status="given")

    body = await report(client, owner, auth_headers, month)

    assert body["orders_count"] == (1 if counted else 0)
    assert body["profit"] == ({"UZS": 90} if counted else {})
