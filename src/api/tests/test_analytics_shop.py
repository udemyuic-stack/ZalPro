from collections.abc import Awaitable, Callable
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Order, Product, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
ProductFactory = Callable[..., Awaitable[Product]]
OrderFactory = Callable[..., Awaitable[Order]]

URL = "/v1/analytics/shop"
WINDOW = {"from": "2026-10-01", "to": "2026-10-31"}


def utc(*parts: int) -> datetime:
    return datetime(*parts, tzinfo=UTC)


async def fetch(
    client: AsyncClient, actor: User, headers: HeadersFactory, params: dict | None = None
) -> dict:
    response = await client.get(URL, headers=headers(actor), params=params or WINDOW)
    assert response.status_code == 200, response.text
    return response.json()


async def test_given_order_snapshots_the_cost_price(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    buyer = await make_user()
    product = await make_product(stock=5, cost_price=60000)
    order = await make_order(buyer.id, product_id=product.id)

    response = await client.patch(
        f"/v1/orders/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
    )
    product.cost_price = 90000
    await db_session.commit()
    await db_session.refresh(order)

    assert response.status_code == 200
    assert order.cost_price == 60000


async def test_empty_window_has_the_documented_shape(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")

    body = await fetch(client, owner, auth_headers)

    assert body == {
        "from": "2026-10-01",
        "to": "2026-10-31",
        "totals": {},
        "top_products": [],
        "by_weekday": [],
    }


async def test_totals_profit_and_only_given_orders_count(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    buyer = await make_user()
    given = {"status": "given", "given_at": utc(2026, 10, 5, 10)}
    await make_order(buyer.id, price=100, qty=2, cost_price=60, **given)
    await make_order(buyer.id, price=50, qty=1, cost_price=0, **given)
    await make_order(buyer.id, price=50, qty=1, **given)
    await make_order(buyer.id, price=30, qty=1, currency="USD", cost_price=10, **given)
    await make_order(buyer.id, price=999, status="new")
    await make_order(buyer.id, price=999, status="canceled", given_at=utc(2026, 10, 6))

    body = await fetch(client, owner, auth_headers)

    assert body["totals"]["UZS"] == {
        "orders": 3,
        "units": 4,
        "revenue": 300,
        "profit": 80,
        "no_cost_orders": 2,
    }
    assert body["totals"]["USD"] == {
        "orders": 1,
        "units": 1,
        "revenue": 30,
        "profit": 20,
        "no_cost_orders": 0,
    }


async def test_top_products_are_ranked_and_capped_at_ten(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    buyer = await make_user()
    given = {"status": "given", "given_at": utc(2026, 10, 5, 10), "cost_price": 0}
    await make_order(buyer.id, product_id="b", product_name="B", qty=3, price=10, **given)
    await make_order(buyer.id, product_id="a", product_name="A", qty=3, price=20, **given)
    await make_order(buyer.id, product_id="c", product_name="C", qty=1, price=500, **given)
    for index in range(10):
        await make_order(
            buyer.id, product_id=f"x{index}", product_name=f"X{index}", qty=1, price=1, **given
        )

    body = await fetch(client, owner, auth_headers)

    names = [row["name"] for row in body["top_products"]]
    assert len(names) == 10
    assert names[:3] == ["A", "B", "C"]


async def test_deleted_product_still_shows_by_order_name(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    buyer = await make_user()
    await make_order(
        buyer.id,
        product_id="gone",
        product_name="Eski forma",
        status="given",
        given_at=utc(2026, 10, 5),
    )

    body = await fetch(client, owner, auth_headers)

    assert body["top_products"][0]["name"] == "Eski forma"


async def test_weekday_uses_gym_timezone_and_fills_all_seven_days(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    buyer = await make_user()
    await make_order(
        buyer.id, price=40, status="given", given_at=utc(2026, 10, 4, 23, 30), cost_price=0
    )

    body = await fetch(client, owner, auth_headers)

    rows = body["by_weekday"]
    assert [row["weekday"] for row in rows] == list(range(7))
    assert {row["weekday"]: row["revenue"] for row in rows} == {
        0: 40,
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
        6: 0,
    }


@pytest.mark.parametrize(
    ("given_at", "counted"),
    [
        (utc(2026, 9, 30, 18, 59), False),
        (utc(2026, 9, 30, 19, 0), True),
        (utc(2026, 10, 31, 18, 59), True),
        (utc(2026, 10, 31, 19, 0), False),
    ],
)
async def test_window_edges_follow_the_gym_timezone(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
    given_at: datetime,
    counted: bool,
) -> None:
    owner = await make_user("owner")
    buyer = await make_user()
    await make_order(buyer.id, status="given", given_at=given_at)

    body = await fetch(client, owner, auth_headers)

    assert bool(body["totals"]) is counted


@pytest.mark.parametrize(
    "params",
    [
        {"from": "2026-10-31", "to": "2026-10-01"},
        {"from": "2025-01-01", "to": "2026-10-31"},
        {"from": "nope", "to": "2026-10-31"},
        {"from": "2026-10-01"},
        {},
    ],
)
async def test_bad_window_is_rejected(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, params: dict
) -> None:
    owner = await make_user("owner")

    response = await client.get(URL, headers=auth_headers(owner), params=params)

    assert response.status_code == 422


async def test_admin_sees_only_own_orders_and_others_are_forbidden(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    admin = await make_user("admin")
    other = await make_user("admin")
    buyer = await make_user()
    given = {"status": "given", "given_at": utc(2026, 10, 5), "cost_price": 0}
    await make_order(buyer.id, trainer_id=admin.id, price=10, **given)
    await make_order(buyer.id, trainer_id=other.id, price=777, **given)

    body = await fetch(client, admin, auth_headers)
    forbidden = [
        await client.get(URL, headers=auth_headers(await make_user(role)), params=WINDOW)
        for role in ("barmen", "user")
    ]
    anonymous = await client.get(URL, params=WINDOW)

    assert body["totals"]["UZS"]["revenue"] == 10
    assert [r.status_code for r in forbidden] == [403, 403]
    assert anonymous.status_code == 401


async def test_trainer_and_trainerless_buyers_count_alike(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    trainer = await make_user("admin")
    with_trainer = await make_user(trainer_id=trainer.id)
    without = await make_user()
    given = {"status": "given", "given_at": utc(2026, 10, 5), "price": 10}
    await make_order(with_trainer.id, **given)
    await make_order(without.id, **given)

    body = await fetch(client, owner, auth_headers)

    assert body["totals"]["UZS"]["orders"] == 2


async def test_response_has_no_personal_data(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    buyer = await make_user()
    await make_order(
        buyer.id,
        client_name="Secret Name",
        client_phone="998901112233",
        status="given",
        given_at=utc(2026, 10, 5),
    )

    response = await client.get(URL, headers=auth_headers(owner), params=WINDOW)

    assert "Secret Name" not in response.text
    assert "998901112233" not in response.text
    assert buyer.id not in response.text
