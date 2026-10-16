import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Order, Product, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
ProductFactory = Callable[..., Awaitable[Product]]
OrderFactory = Callable[..., Awaitable[Order]]
GymFactory = Callable[..., Awaitable[Any]]

URL = "/v1/orders"
WINDOW = {"from": "2026-01-01", "to": "2026-12-31"}


def utc(*parts: int) -> datetime:
    return datetime(*parts, tzinfo=UTC)


async def stock_of(session: AsyncSession, product_id: str) -> Product:
    product = await session.scalar(
        select(Product).where(Product.id == product_id).execution_options(populate_existing=True)
    )
    assert product is not None
    return product


async def order_of(session: AsyncSession, order_id: str) -> Order:
    order = await session.scalar(
        select(Order).where(Order.id == order_id).execution_options(populate_existing=True)
    )
    assert order is not None
    return order


async def test_create_derives_everything_from_server_state(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    trainer = await make_user("admin", gym_id=gym.id)
    user = await make_user(trainer_id=trainer.id)
    product = await make_product(name="Shaker", category="Anjomlar", price=45000, currency="USD")

    response = await client.post(
        URL, headers=auth_headers(user), json={"product_id": product.id, "qty": 3, "color": "red"}
    )

    assert response.status_code == 201
    body = response.json()
    assert body["client_id"] == user.id
    assert body["client_name"] == user.name
    assert body["client_phone"] == user.phone
    assert body["trainer_id"] == trainer.id
    assert body["gym_id"] == gym.id
    assert body["product_name"] == "Shaker"
    assert body["category"] == "Anjomlar"
    assert body["price"] == 45000
    assert body["currency"] == "USD"
    assert body["total"] == 135000
    assert body["status"] == "new"
    assert body["color"] == "red"
    assert body["size"] == ""
    assert body["given_by"] == ""
    assert body["given_at"] is None
    assert set(body) == {
        "id", "client_id", "client_name", "client_phone", "trainer_id", "gym_id", "product_id",
        "product_name", "category", "size", "color", "price", "currency", "qty", "status",
        "created_at", "updated_at", "given_by", "given_at", "total",
    }  # fmt: skip


async def test_trainerless_client_and_gymless_trainer_get_empty_ids(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product()
    alone = await make_user()
    trainer = await make_user("admin")
    pupil = await make_user(trainer_id=trainer.id)
    payload = {"product_id": product.id, "qty": 1}

    first = (await client.post(URL, headers=auth_headers(alone), json=payload)).json()
    second = (await client.post(URL, headers=auth_headers(pupil), json=payload)).json()

    assert (first["trainer_id"], first["gym_id"]) == ("", "")
    assert (second["trainer_id"], second["gym_id"]) == (trainer.id, "")


async def test_any_role_can_order_and_anonymous_cannot(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product()
    payload = {"product_id": product.id, "qty": 1}

    for role in ("owner", "admin", "barmen", "user"):
        actor = await make_user(role)
        response = await client.post(URL, headers=auth_headers(actor), json=payload)
        assert response.status_code == 201

    assert (await client.post(URL, json=payload)).status_code == 401


@pytest.mark.parametrize("extra", ["price", "status", "client_id", "currency", "trainer_id"])
async def test_server_owned_fields_in_body_are_rejected(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    extra: str,
) -> None:
    user = await make_user()
    product = await make_product()

    response = await client.post(
        URL, headers=auth_headers(user), json={"product_id": product.id, "qty": 1, extra: 1}
    )

    assert response.status_code == 422


@pytest.mark.parametrize("qty", [0, -1, 21, "2", 1.5, None])
async def test_qty_must_be_between_1_and_20(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    qty: Any,
) -> None:
    user = await make_user()
    product = await make_product()

    response = await client.post(
        URL, headers=auth_headers(user), json={"product_id": product.id, "qty": qty}
    )

    assert response.status_code == 422


@pytest.mark.parametrize("qty", [1, 20])
async def test_qty_bounds_are_accepted_without_stock_check(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    qty: int,
) -> None:
    user = await make_user()
    product = await make_product(stock=0)

    response = await client.post(
        URL, headers=auth_headers(user), json={"product_id": product.id, "qty": qty}
    )

    assert response.status_code == 201


async def test_missing_product_is_404_and_inactive_is_409(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    user = await make_user()
    inactive = await make_product(active=False)

    missing = await client.post(URL, headers=auth_headers(user), json={"product_id": "x", "qty": 1})
    off = await client.post(
        URL, headers=auth_headers(user), json={"product_id": inactive.id, "qty": 1}
    )

    assert missing.status_code == 404
    assert off.status_code == 409
    assert off.json()["detail"]["code"] == "product_inactive"


@pytest.mark.parametrize(
    ("product_sizes", "size", "expected"),
    [
        (["S", "M"], None, 422),
        (["S", "M"], "", 422),
        (["S", "M"], "XL", 422),
        (["S", "M"], "M", 201),
        ([], "M", 422),
        ([], None, 201),
        ([], "", 201),
        (["S"], "S" * 21, 422),
    ],
)
async def test_size_rules(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    product_sizes: list[str],
    size: str | None,
    expected: int,
) -> None:
    user = await make_user()
    product = await make_product(sizes=product_sizes, size_stock={s: 1 for s in product_sizes})
    payload: dict[str, Any] = {"product_id": product.id, "qty": 1}
    if size is not None:
        payload["size"] = size

    response = await client.post(URL, headers=auth_headers(user), json=payload)

    assert response.status_code == expected
    if expected == 422:
        assert response.json()["detail"]["code"] == "validation_error"


async def test_color_longer_than_30_is_rejected(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    user = await make_user()
    product = await make_product()

    response = await client.post(
        URL,
        headers=auth_headers(user),
        json={"product_id": product.id, "qty": 1, "color": "c" * 31},
    )

    assert response.status_code == 422


@pytest.fixture
async def shop(
    make_user: UserFactory, make_gym: GymFactory, make_order: OrderFactory
) -> dict[str, Any]:
    gym = await make_gym()
    other_gym = await make_gym()
    owner = await make_user("owner")
    trainer = await make_user("admin", gym_id=gym.id)
    other_admin = await make_user("admin", gym_id=gym.id)
    barmen = await make_user("barmen", gym_id=gym.id)
    other_barmen = await make_user("barmen", gym_id=other_gym.id)
    free_barmen = await make_user("barmen")
    client = await make_user(trainer_id=trainer.id)
    stranger = await make_user()
    order = await make_order(client.id, trainer_id=trainer.id, gym_id=gym.id)
    return {
        "owner": owner,
        "trainer": trainer,
        "other_admin": other_admin,
        "barmen": barmen,
        "other_barmen": other_barmen,
        "free_barmen": free_barmen,
        "client": client,
        "stranger": stranger,
        "order": order,
    }


READ_MATRIX = [
    ("owner", 200),
    ("trainer", 200),
    ("other_admin", 403),
    ("barmen", 200),
    ("other_barmen", 403),
    ("free_barmen", 403),
    ("client", 200),
    ("stranger", 403),
]


@pytest.mark.parametrize(("who", "expected"), READ_MATRIX)
async def test_read_permission_matrix(
    client: AsyncClient, shop: dict[str, Any], auth_headers: HeadersFactory, who: str, expected: int
) -> None:
    response = await client.get(f"{URL}/{shop['order'].id}", headers=auth_headers(shop[who]))

    assert response.status_code == expected


async def test_read_missing_is_404_and_anonymous_401(
    client: AsyncClient, shop: dict[str, Any], auth_headers: HeadersFactory
) -> None:
    missing = await client.get(f"{URL}/nope", headers=auth_headers(shop["owner"]))
    anonymous = await client.get(f"{URL}/{shop['order'].id}")

    assert missing.status_code == 404
    assert anonymous.status_code == 401


STATUS_MATRIX = [
    ("owner", "given", 200),
    ("owner", "canceled", 200),
    ("trainer", "given", 200),
    ("trainer", "canceled", 200),
    ("other_admin", "given", 403),
    ("other_admin", "canceled", 403),
    ("barmen", "given", 200),
    ("barmen", "canceled", 200),
    ("other_barmen", "given", 403),
    ("other_barmen", "canceled", 403),
    ("free_barmen", "given", 403),
    ("free_barmen", "canceled", 403),
    ("client", "given", 403),
    ("client", "canceled", 200),
    ("stranger", "given", 403),
    ("stranger", "canceled", 403),
]


@pytest.mark.parametrize(("who", "status", "expected"), STATUS_MATRIX)
async def test_status_permission_matrix(
    client: AsyncClient,
    shop: dict[str, Any],
    make_product: ProductFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
    who: str,
    status: str,
    expected: int,
) -> None:
    product = await make_product(stock=5)
    shop["order"].product_id = product.id
    db_session.add(shop["order"])
    await db_session.commit()

    response = await client.patch(
        f"{URL}/{shop['order'].id}/status", headers=auth_headers(shop[who]), json={"status": status}
    )

    assert response.status_code == expected
    if expected == 403:
        assert (await order_of(db_session, shop["order"].id)).status == "new"


async def test_status_anonymous_and_missing_order(
    client: AsyncClient, shop: dict[str, Any], auth_headers: HeadersFactory
) -> None:
    anonymous = await client.patch(f"{URL}/{shop['order'].id}/status", json={"status": "given"})
    missing = await client.patch(
        f"{URL}/nope/status", headers=auth_headers(shop["owner"]), json={"status": "given"}
    )

    assert anonymous.status_code == 401
    assert missing.status_code == 404


@pytest.mark.parametrize("status", ["new", "other", "", None])
async def test_status_target_must_be_given_or_canceled(
    client: AsyncClient, shop: dict[str, Any], auth_headers: HeadersFactory, status: Any
) -> None:
    response = await client.patch(
        f"{URL}/{shop['order'].id}/status",
        headers=auth_headers(shop["owner"]),
        json={"status": status},
    )

    assert response.status_code == 422


async def test_status_body_rejects_extra_fields(
    client: AsyncClient, shop: dict[str, Any], auth_headers: HeadersFactory
) -> None:
    response = await client.patch(
        f"{URL}/{shop['order'].id}/status",
        headers=auth_headers(shop["owner"]),
        json={"status": "given", "price": 1},
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    ("first", "second"),
    [("given", "given"), ("given", "canceled"), ("canceled", "given"), ("canceled", "canceled")],
)
async def test_only_new_orders_can_change_status(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
    first: str,
    second: str,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(stock=10)
    order = await make_order(user.id, product_id=product.id, qty=2)
    url = f"{URL}/{order.id}/status"

    assert (
        await client.patch(url, headers=auth_headers(owner), json={"status": first})
    ).status_code == 200
    again = await client.patch(url, headers=auth_headers(owner), json={"status": second})

    assert again.status_code == 409
    assert again.json()["detail"]["code"] == "invalid_status_transition"
    expected_stock = 8 if first == "given" else 10
    assert (await stock_of(db_session, product.id)).stock == expected_stock


async def test_given_without_sizes_decrements_stock_and_stamps_order(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    barmen = await make_user("barmen", gym_id=gym.id)
    user = await make_user()
    product = await make_product(stock=7)
    order = await make_order(user.id, product_id=product.id, qty=3, gym_id=gym.id)

    response = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(barmen), json={"status": "given"}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "given"
    assert body["given_by"] == barmen.id
    assert body["given_at"] is not None
    assert body["updated_at"] is not None
    assert (await stock_of(db_session, product.id)).stock == 4


async def test_given_with_sizes_decrements_only_that_size_and_sums_stock(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(sizes=["S", "M"], size_stock={"S": 4, "M": 6}, stock=10)
    order = await make_order(user.id, product_id=product.id, qty=3, size="M")

    response = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
    )

    assert response.status_code == 200
    refreshed = await stock_of(db_session, product.id)
    assert refreshed.size_stock == {"S": 4, "M": 3}
    assert refreshed.stock == 7


async def test_exact_stock_can_be_taken_down_to_zero(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(stock=2)
    order = await make_order(user.id, product_id=product.id, qty=2)

    response = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
    )

    assert response.status_code == 200
    assert (await stock_of(db_session, product.id)).stock == 0


@pytest.mark.parametrize("sized", [False, True])
async def test_insufficient_stock_changes_nothing(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
    sized: bool,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    if sized:
        product = await make_product(sizes=["S", "M"], size_stock={"S": 1, "M": 9}, stock=10)
        order = await make_order(user.id, product_id=product.id, qty=2, size="S")
    else:
        product = await make_product(stock=1)
        order = await make_order(user.id, product_id=product.id, qty=2)

    response = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
    )

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "insufficient_stock"
    refreshed = await stock_of(db_session, product.id)
    assert refreshed.stock == (10 if sized else 1)
    assert refreshed.size_stock == ({"S": 1, "M": 9} if sized else {})
    stored = await order_of(db_session, order.id)
    assert stored.status == "new"
    assert stored.given_at is None
    assert stored.given_by == ""


async def test_sized_order_for_size_missing_from_product_is_insufficient(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(sizes=["S"], size_stock={"S": 5}, stock=5)
    order = await make_order(user.id, product_id=product.id, qty=1, size="XL")

    response = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
    )

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "insufficient_stock"


async def test_deleted_product_blocks_given_but_allows_cancel(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    order = await make_order(user.id, product_id="deleted")

    given = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
    )
    canceled = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "canceled"}
    )

    assert given.status_code == 409
    assert given.json()["detail"]["code"] == "product_missing"
    assert canceled.status_code == 200
    assert (await order_of(db_session, order.id)).status == "canceled"


async def test_cancel_does_not_touch_stock(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    user = await make_user()
    product = await make_product(stock=5)
    order = await make_order(user.id, product_id=product.id, qty=2)

    response = await client.patch(
        f"{URL}/{order.id}/status", headers=auth_headers(user), json={"status": "canceled"}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "canceled"
    assert body["updated_at"] is not None
    assert body["given_at"] is None
    assert (await stock_of(db_session, product.id)).stock == 5


async def test_parallel_given_on_same_order_succeeds_exactly_once(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(stock=10)
    order = await make_order(user.id, product_id=product.id, qty=4)

    responses = await asyncio.gather(
        *(
            client.patch(
                f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
            )
            for _ in range(2)
        )
    )

    assert sorted(response.status_code for response in responses) == [200, 409]
    loser = next(response for response in responses if response.status_code == 409)
    assert loser.json()["detail"]["code"] == "invalid_status_transition"
    assert (await stock_of(db_session, product.id)).stock == 6


async def test_parallel_given_on_different_orders_never_oversells(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product(stock=5)
    orders = [await make_order(user.id, product_id=product.id, qty=3) for _ in range(2)]

    responses = await asyncio.gather(
        *(
            client.patch(
                f"{URL}/{order.id}/status", headers=auth_headers(owner), json={"status": "given"}
            )
            for order in orders
        )
    )

    assert sorted(response.status_code for response in responses) == [200, 409]
    assert (await stock_of(db_session, product.id)).stock == 2


async def test_delete_is_owner_only(
    client: AsyncClient,
    shop: dict[str, Any],
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    url = f"{URL}/{shop['order'].id}"

    for who in ("trainer", "barmen", "client", "stranger"):
        assert (await client.delete(url, headers=auth_headers(shop[who]))).status_code == 403
    assert (await client.delete(url)).status_code == 401
    assert (await client.delete(url, headers=auth_headers(shop["owner"]))).status_code == 204
    assert (await client.delete(url, headers=auth_headers(shop["owner"]))).status_code == 404
    count = await db_session.scalar(select(func.count()).select_from(Order))
    assert count == 0


async def test_orders_survive_deleted_client_and_product(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    product = await make_product()
    created = await client.post(
        URL, headers=auth_headers(user), json={"product_id": product.id, "qty": 1}
    )
    order_id = created.json()["id"]
    await db_session.delete(product)
    await db_session.delete(user)
    await db_session.commit()

    response = await client.get(f"{URL}/{order_id}", headers=auth_headers(owner))

    assert response.status_code == 200
    assert response.json()["client_name"] == user.name


async def test_list_scopes_by_role(
    client: AsyncClient,
    shop: dict[str, Any],
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    other_client = await make_user()
    foreign = await make_order(other_client.id, trainer_id="t", gym_id="elsewhere")
    mine = shop["order"].id
    expectations = {
        "owner": {mine, foreign.id},
        "trainer": {mine},
        "other_admin": set(),
        "barmen": {mine},
        "other_barmen": set(),
        "free_barmen": set(),
        "client": {mine},
        "stranger": set(),
    }

    for who, expected in expectations.items():
        response = await client.get(URL, headers=auth_headers(shop[who]), params=WINDOW)
        assert response.status_code == 200, who
        assert {item["id"] for item in response.json()} == expected, who
    assert (await client.get(URL, params=WINDOW)).status_code == 401


async def test_gymless_barmen_does_not_see_gymless_orders(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    barmen = await make_user("barmen")
    user = await make_user()
    await make_order(user.id, gym_id="")

    response = await client.get(URL, headers=auth_headers(barmen), params=WINDOW)

    assert response.json() == []


async def test_list_filters_by_status_newest_first_and_validates(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    old = await make_order(user.id, status="given", created_at=utc(2026, 10, 1))
    new = await make_order(user.id, status="new", created_at=utc(2026, 10, 3))
    mid = await make_order(user.id, status="canceled", created_at=utc(2026, 10, 2))

    everything = await client.get(URL, headers=auth_headers(owner), params=WINDOW)
    given = await client.get(URL, headers=auth_headers(owner), params={**WINDOW, "status": "given"})
    bad = await client.get(URL, headers=auth_headers(owner), params={**WINDOW, "status": "x"})

    assert [item["id"] for item in everything.json()] == [new.id, mid.id, old.id]
    assert [item["id"] for item in given.json()] == [old.id]
    assert bad.status_code == 422


async def test_list_window_uses_gym_local_days(
    client: AsyncClient,
    make_user: UserFactory,
    make_order: OrderFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    user = await make_user()
    inside = await make_order(user.id, created_at=utc(2026, 10, 9, 19, 0))
    await make_order(user.id, created_at=utc(2026, 10, 9, 18, 59, 59))
    last = await make_order(user.id, created_at=utc(2026, 10, 10, 18, 59, 59))
    await make_order(user.id, created_at=utc(2026, 10, 10, 19, 0))

    response = await client.get(
        URL, headers=auth_headers(owner), params={"from": "2026-10-10", "to": "2026-10-10"}
    )

    assert {item["id"] for item in response.json()} == {inside.id, last.id}


@pytest.mark.parametrize(
    "params",
    [
        {"from": "2026-10-10", "to": "2026-10-09"},
        {"from": "2025-01-01", "to": "2026-12-31"},
        {"from": "bad", "to": "2026-10-09"},
        {"to": "2026-10-09"},
    ],
)
async def test_list_rejects_bad_windows(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    params: dict[str, str],
) -> None:
    owner = await make_user("owner")

    response = await client.get(URL, headers=auth_headers(owner), params=params)

    assert response.status_code == 422
