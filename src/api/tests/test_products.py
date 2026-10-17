import asyncio
from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Product, User

UserFactory = Callable[..., Awaitable[User]]
ProductFactory = Callable[..., Awaitable[Product]]
HeadersFactory = Callable[[User], dict[str, str]]

READ_ROLES = ["user", "barmen", "admin", "owner"]
WRITE_ROLES = ["barmen", "admin", "owner"]
VALID = {"category": "Forma", "name": "Futbolka", "price": 150000, "cost_price": 90000}
URL = "/v1/products"


async def product_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Product)) or 0


async def stored(db_session: AsyncSession, product_id: str) -> Product:
    db_session.expire_all()
    return await db_session.get(Product, product_id)


@pytest.mark.parametrize("role", READ_ROLES)
async def test_every_signed_in_role_reads_list_and_one(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    product = await make_product(name="Kepka")
    actor = await make_user(role=role)

    listing = await client.get(URL, headers=auth_headers(actor))
    single = await client.get(f"{URL}/{product.id}", headers=auth_headers(actor))

    assert listing.status_code == 200
    assert [item["id"] for item in listing.json()] == [product.id]
    assert single.status_code == 200
    assert single.json()["name"] == "Kepka"
    assert single.json()["price"] == 100000
    assert single.json()["stock"] == 10


@pytest.mark.parametrize("role", READ_ROLES)
async def test_cost_price_visibility_by_role_in_list_and_single(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    product = await make_product(cost_price=60000)
    actor = await make_user(role=role)
    expected = None if role == "user" else 60000

    listing = await client.get(URL, headers=auth_headers(actor))
    single = await client.get(f"{URL}/{product.id}", headers=auth_headers(actor))

    assert listing.json()[0]["cost_price"] == expected
    assert single.json()["cost_price"] == expected


async def test_anonymous_cannot_read(client: AsyncClient, make_product: ProductFactory) -> None:
    product = await make_product()

    assert (await client.get(URL)).status_code == 401
    assert (await client.get(f"{URL}/{product.id}")).status_code == 401


async def test_list_orders_by_category_order_then_name(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    await make_product(category="Boshqa", name="A")
    await make_product(category="Protein", name="Z")
    await make_product(category="Protein", name="B")
    await make_product(category="Forma", name="M")
    await make_product(category="Anjomlar", name="K")
    actor = await make_user(role="user")

    response = await client.get(URL, headers=auth_headers(actor))

    assert [(item["category"], item["name"]) for item in response.json()] == [
        ("Forma", "M"),
        ("Anjomlar", "K"),
        ("Protein", "B"),
        ("Protein", "Z"),
        ("Boshqa", "A"),
    ]


async def test_read_missing_product_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="user")

    response = await client.get(f"{URL}/missing", headers=auth_headers(actor))

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "not_found"


@pytest.mark.parametrize("role", WRITE_ROLES)
async def test_shop_writers_create_product(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post(
        URL, json={**VALID, "stock": 5, "currency": "USD"}, headers=auth_headers(actor)
    )

    assert response.status_code == 201
    body = response.json()
    assert body["cost_price"] == 90000
    assert body["stock"] == 5
    assert body["currency"] == "USD"
    assert body["active"] is True
    assert body["size_stock"] == {}
    assert (await stored(db_session, body["id"])).name == "Futbolka"


async def test_create_without_stock_defaults_to_zero(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.post(URL, json=VALID, headers=auth_headers(actor))

    assert response.status_code == 201
    assert response.json()["stock"] == 0


async def test_user_cannot_write(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    product = await make_product()
    actor = await make_user(role="user")
    headers = auth_headers(actor)

    post = await client.post(URL, json=VALID, headers=headers)
    patch = await client.patch(f"{URL}/{product.id}", json={"name": "X"}, headers=headers)
    delete = await client.delete(f"{URL}/{product.id}", headers=headers)

    assert [post.status_code, patch.status_code, delete.status_code] == [403, 403, 403]
    assert await product_count(db_session) == 1
    assert (await stored(db_session, product.id)).name == "Product"


async def test_anonymous_cannot_write(
    client: AsyncClient, make_product: ProductFactory, db_session: AsyncSession
) -> None:
    product = await make_product()

    post = await client.post(URL, json=VALID)
    patch = await client.patch(f"{URL}/{product.id}", json={"name": "X"})
    delete = await client.delete(f"{URL}/{product.id}")

    assert [post.status_code, patch.status_code, delete.status_code] == [401, 401, 401]
    assert await product_count(db_session) == 1


async def test_create_with_sizes_computes_stock_as_sum(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="barmen")
    body = {**VALID, "sizes": ["S", "M", "L"], "size_stock": {"S": 2, "M": 3}}

    response = await client.post(URL, json=body, headers=auth_headers(actor))

    assert response.status_code == 201
    assert response.json()["stock"] == 5
    assert response.json()["size_stock"] == {"S": 2, "M": 3}


async def test_create_with_sizes_and_no_size_stock_has_zero_stock(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="barmen")

    response = await client.post(URL, json={**VALID, "sizes": ["S"]}, headers=auth_headers(actor))

    assert response.status_code == 201
    assert response.json()["stock"] == 0


@pytest.mark.parametrize(
    "extra",
    [
        {"sizes": ["S"], "size_stock": {"XL": 1}},
        {"sizes": ["S"], "stock": 5},
        {"sizes": ["S"], "size_stock": {"S": 1}, "stock": 1},
        {"size_stock": {"S": 1}},
        {"sizes": ["S", "S"]},
        {"colors": ["red", "red"]},
        {"sizes": ["S"], "size_stock": {"S": -1}},
        {"sizes": ["S"], "size_stock": {"S": 1.5}},
        {"sizes": ["S"], "size_stock": {"S": True}},
        {"sizes": ["S"], "size_stock": {"S": "1"}},
        {"stock": -1},
        {"stock": 2147483648},
        {"stock": True},
    ],
)
async def test_invalid_stock_combinations_return_422(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    extra: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")

    response = await client.post(URL, json={**VALID, **extra}, headers=auth_headers(actor))

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await product_count(db_session) == 0


@pytest.mark.parametrize(
    "extra",
    [
        {"category": "Nomalum"},
        {"category": ""},
        {"name": ""},
        {"name": "   "},
        {"name": "x" * 121},
        {"note": "x" * 501},
        {"name_ru": "x" * 121},
        {"note_en": "x" * 501},
        {"image": "https://img.example/a.png"},
        {"image": ""},
        {"images": ["https://img.example/a.png"]},
        {"images": []},
        {"image_keys": ["images/products/x/y.jpg"]},
        {"image_urls": ["https://img.example/a.png"]},
        {"sizes": [""]},
        {"price": -1},
        {"price": 2147483648},
        {"price": 1.5},
        {"price": "100"},
        {"price": True},
        {"cost_price": -1},
        {"cost_price": 2147483648},
        {"currency": "EUR"},
        {"active": "yes"},
        {"unknown": 1},
        {"id": "custom"},
    ],
)
async def test_field_validation_rejects_bad_values(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    extra: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")

    response = await client.post(URL, json={**VALID, **extra}, headers=auth_headers(actor))

    assert response.status_code == 422
    assert await product_count(db_session) == 0


@pytest.mark.parametrize("missing", ["category", "name", "price"])
async def test_required_fields_are_enforced(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, missing: str
) -> None:
    actor = await make_user(role="admin")
    body = {key: value for key, value in VALID.items() if key != missing}

    response = await client.post(URL, json=body, headers=auth_headers(actor))

    assert response.status_code == 422


async def test_boundary_values_are_accepted(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")
    body = {
        **VALID,
        "name": "x" * 120,
        "note": "n" * 500,
        "price": 2147483647,
        "cost_price": 0,
        "category": "L-Arginin",
    }

    response = await client.post(URL, json=body, headers=auth_headers(actor))

    assert response.status_code == 201


@pytest.mark.parametrize("role", WRITE_ROLES)
async def test_shop_writers_patch_partially(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    product = await make_product(name="Eski", note="izoh", price=100000, stock=10)
    actor = await make_user(role=role)

    response = await client.patch(
        f"{URL}/{product.id}", json={"name": "Yangi", "active": False}, headers=auth_headers(actor)
    )

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Yangi"
    assert body["active"] is False
    assert body["note"] == "izoh"
    assert body["price"] == 100000
    assert body["stock"] == 10
    assert (await stored(db_session, product.id)).name == "Yangi"


async def test_patch_hides_cost_price_never_for_writers(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product()
    actor = await make_user(role="barmen")

    response = await client.patch(
        f"{URL}/{product.id}", json={"cost_price": 7}, headers=auth_headers(actor)
    )

    assert response.json()["cost_price"] == 7


async def test_patch_missing_product_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.patch(f"{URL}/missing", json={"name": "X"}, headers=auth_headers(actor))

    assert response.status_code == 404


async def test_patch_size_stock_recomputes_stock(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(sizes=["S", "M"], size_stock={"S": 1, "M": 1}, stock=2)
    actor = await make_user(role="admin")

    response = await client.patch(
        f"{URL}/{product.id}", json={"size_stock": {"S": 4, "M": 6}}, headers=auth_headers(actor)
    )

    assert response.status_code == 200
    assert response.json()["stock"] == 10


async def test_patch_adding_size_keeps_consistent_sum(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(sizes=["S"], size_stock={"S": 3}, stock=3)
    actor = await make_user(role="admin")

    response = await client.patch(
        f"{URL}/{product.id}",
        json={"sizes": ["S", "M"], "size_stock": {"S": 3, "M": 2}},
        headers=auth_headers(actor),
    )

    assert response.status_code == 200
    assert response.json()["stock"] == 5


async def test_patch_sizes_dropping_key_used_by_size_stock_returns_422(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    product = await make_product(sizes=["S", "M"], size_stock={"S": 1, "M": 1}, stock=2)
    actor = await make_user(role="admin")

    response = await client.patch(
        f"{URL}/{product.id}", json={"sizes": ["S"]}, headers=auth_headers(actor)
    )

    assert response.status_code == 422
    assert (await stored(db_session, product.id)).sizes == ["S", "M"]


async def test_patch_adding_sizes_to_plain_product_sets_stock_from_size_stock(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(stock=10)
    actor = await make_user(role="admin")

    response = await client.patch(
        f"{URL}/{product.id}",
        json={"sizes": ["S"], "size_stock": {"S": 4}},
        headers=auth_headers(actor),
    )

    assert response.status_code == 200
    assert response.json()["stock"] == 4


async def test_patch_clearing_sizes_requires_clearing_size_stock(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(sizes=["S"], size_stock={"S": 3}, stock=3)
    actor = await make_user(role="admin")
    headers = auth_headers(actor)

    rejected = await client.patch(f"{URL}/{product.id}", json={"sizes": []}, headers=headers)
    accepted = await client.patch(
        f"{URL}/{product.id}", json={"sizes": [], "size_stock": {}, "stock": 7}, headers=headers
    )

    assert rejected.status_code == 422
    assert accepted.status_code == 200
    assert accepted.json()["stock"] == 7


async def test_patch_stock_on_plain_product_is_allowed(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(stock=10)
    actor = await make_user(role="admin")

    response = await client.patch(
        f"{URL}/{product.id}", json={"stock": 3}, headers=auth_headers(actor)
    )

    assert response.json()["stock"] == 3


async def test_patch_stock_on_sized_product_returns_422(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(sizes=["S"], size_stock={"S": 3}, stock=3)
    actor = await make_user(role="admin")

    response = await client.patch(
        f"{URL}/{product.id}", json={"stock": 99}, headers=auth_headers(actor)
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "body",
    [
        {"unknown": 1},
        {"id": "x"},
        {"name": None},
        {"price": None},
        {"category": "Nomalum"},
        {"price": -5},
        {"currency": "EUR"},
        {"name": ""},
    ],
)
async def test_patch_rejects_invalid_bodies(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    body: dict[str, Any],
) -> None:
    product = await make_product(name="Asl", price=100000)
    actor = await make_user(role="admin")

    response = await client.patch(f"{URL}/{product.id}", json=body, headers=auth_headers(actor))

    assert response.status_code == 422
    fresh = await stored(db_session, product.id)
    assert (fresh.name, fresh.price) == ("Asl", 100000)


@pytest.mark.parametrize("role", WRITE_ROLES)
async def test_shop_writers_delete_product(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    product = await make_product()
    actor = await make_user(role=role)

    response = await client.delete(f"{URL}/{product.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert await product_count(db_session) == 0


async def test_delete_missing_product_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.delete(f"{URL}/missing", headers=auth_headers(actor))

    assert response.status_code == 404


async def test_patch_waits_for_row_lock_and_applies_after_release(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    product = await make_product(stock=10)
    actor = await make_user(role="owner")
    await db_session.execute(select(Product).where(Product.id == product.id).with_for_update())

    patch = asyncio.create_task(
        client.patch(
            f"{URL}/{product.id}", json={"name": product.name}, headers=auth_headers(actor)
        )
    )
    await asyncio.sleep(0.3)
    assert not patch.done()
    await db_session.commit()
    response = await asyncio.wait_for(patch, timeout=5)

    assert response.status_code == 200
    assert response.json()["name"] == product.name


@pytest.mark.parametrize(
    "extra",
    [{"image": "https://img.example/a.png"}, {"images": ["https://img.example/a.png"]}],
)
async def test_patch_rejects_image_urls_and_keeps_legacy_columns(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    extra: dict[str, Any],
) -> None:
    product = await make_product(image="legacy", images=["legacy"])
    actor = await make_user(role="admin")

    response = await client.patch(f"{URL}/{product.id}", json=extra, headers=auth_headers(actor))

    assert response.status_code == 422
    row = await stored(db_session, product.id)
    assert (row.image, row.images) == ("legacy", ["legacy"])


async def test_product_out_has_image_urls_and_no_url_fields(
    client: AsyncClient,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(image="https://legacy/a.png", images=["https://legacy/b.png"])
    actor = await make_user(role="user")

    response = await client.get(f"{URL}/{product.id}", headers=auth_headers(actor))

    body = response.json()
    assert body["image_urls"] == []
    assert "image" not in body
    assert "images" not in body
    assert "https://legacy" not in response.text
