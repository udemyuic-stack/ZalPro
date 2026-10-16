from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Food, User

UserFactory = Callable[..., Awaitable[User]]
FoodFactory = Callable[..., Awaitable[Food]]
HeadersFactory = Callable[[User], dict[str, str]]

VALID_FOOD = {
    "name": "Chicken",
    "kcal": 165,
    "protein": 31,
    "fat": 3.6,
    "carbs": 0,
    "image": "https://img.example/chicken.png",
}
READ_ROLES = ["user", "barmen", "admin", "owner"]
NON_STAFF_ROLES = ["user", "barmen"]
STAFF_ROLES = ["admin", "owner"]


async def food_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Food)) or 0


@pytest.mark.parametrize("role", READ_ROLES)
async def test_every_signed_in_role_lists_foods_sorted_by_name_then_id(
    client: AsyncClient,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    await make_food(id="b", name="Rice")
    await make_food(id="c", name="Apple")
    await make_food(id="a", name="Apple")
    actor = await make_user(role=role)

    response = await client.get("/v1/foods", headers=auth_headers(actor))

    assert response.status_code == 200
    assert [(food["name"], food["id"]) for food in response.json()] == [
        ("Apple", "a"),
        ("Apple", "c"),
        ("Rice", "b"),
    ]


@pytest.mark.parametrize("role", READ_ROLES)
async def test_every_signed_in_role_reads_one_food(
    client: AsyncClient,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    food = await make_food(name="Rice", kcal=130.0, protein=2.7, fat=0.3, carbs=28.0, image="u")
    actor = await make_user(role=role)

    response = await client.get(f"/v1/foods/{food.id}", headers=auth_headers(actor))

    assert response.status_code == 200
    assert response.json() == {
        "id": food.id,
        "name": "Rice",
        "kcal": 130.0,
        "protein": 2.7,
        "fat": 0.3,
        "carbs": 28.0,
        "image": "u",
    }


async def test_food_read_endpoints_require_authentication(
    client: AsyncClient, make_food: FoodFactory
) -> None:
    food = await make_food()

    listed = await client.get("/v1/foods")
    read = await client.get(f"/v1/foods/{food.id}")

    assert listed.status_code == read.status_code == 401


async def test_food_write_endpoints_require_authentication(
    client: AsyncClient, make_food: FoodFactory, db_session: AsyncSession
) -> None:
    food = await make_food()

    created = await client.post("/v1/foods", json=VALID_FOOD)
    updated = await client.put(f"/v1/foods/{food.id}", json=VALID_FOOD)
    deleted = await client.delete(f"/v1/foods/{food.id}")

    assert created.status_code == updated.status_code == deleted.status_code == 401
    assert await food_count(db_session) == 1


async def test_read_unknown_food_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user()

    response = await client.get("/v1/foods/missing", headers=auth_headers(actor))

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "not_found"


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_creates_food(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/foods", json=VALID_FOOD, headers=auth_headers(actor))

    assert response.status_code == 201
    body = response.json()
    assert body["id"]
    assert {key: body[key] for key in VALID_FOOD} == VALID_FOOD
    stored = await db_session.get(Food, body["id"])
    assert stored is not None
    assert stored.name == "Chicken"
    assert stored.protein == 31


async def test_create_food_with_only_name_defaults_numbers_and_image(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.post("/v1/foods", json={"name": "Water"}, headers=auth_headers(actor))

    assert response.status_code == 201
    body = response.json()
    assert body["kcal"] == body["protein"] == body["fat"] == body["carbs"] == 0
    assert body["image"] == ""


async def test_create_food_strips_name_whitespace(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.post("/v1/foods", json={"name": "  Egg  "}, headers=auth_headers(actor))

    assert response.json()["name"] == "Egg"


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_create_food(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/foods", json=VALID_FOOD, headers=auth_headers(actor))

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await food_count(db_session) == 0


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_gets_403_before_validation_error(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/foods", json={"name": ""}, headers=auth_headers(actor))

    assert response.status_code == 403


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_replaces_food_fully(
    client: AsyncClient,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    food = await make_food(name="Old", kcal=100.0, protein=9.0, fat=8.0, carbs=7.0, image="old")
    food_id = food.id

    response = await client.put(
        f"/v1/foods/{food_id}", json={"name": "New", "kcal": 5}, headers=auth_headers(actor)
    )

    assert response.status_code == 200
    assert response.json() == {
        "id": food_id,
        "name": "New",
        "kcal": 5,
        "protein": 0,
        "fat": 0,
        "carbs": 0,
        "image": "",
    }
    db_session.expire_all()
    stored = await db_session.get(Food, food_id)
    assert stored is not None
    assert (stored.name, stored.kcal, stored.protein, stored.image) == ("New", 5, 0, "")


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_update_food(
    client: AsyncClient,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    food = await make_food(name="Old")
    food_id = food.id

    response = await client.put(
        f"/v1/foods/{food_id}", json=VALID_FOOD, headers=auth_headers(actor)
    )

    assert response.status_code == 403
    db_session.expire_all()
    stored = await db_session.get(Food, food_id)
    assert stored is not None
    assert stored.name == "Old"


async def test_update_unknown_food_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.put("/v1/foods/missing", json=VALID_FOOD, headers=auth_headers(actor))

    assert response.status_code == 404


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_deletes_food(
    client: AsyncClient,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    food = await make_food()

    response = await client.delete(f"/v1/foods/{food.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert response.content == b""
    assert await food_count(db_session) == 0
    follow_up = await client.get(f"/v1/foods/{food.id}", headers=auth_headers(actor))
    assert follow_up.status_code == 404


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_delete_food(
    client: AsyncClient,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    food = await make_food()

    response = await client.delete(f"/v1/foods/{food.id}", headers=auth_headers(actor))

    assert response.status_code == 403
    assert await food_count(db_session) == 1


async def test_delete_unknown_food_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="owner")

    response = await client.delete("/v1/foods/missing", headers=auth_headers(actor))

    assert response.status_code == 404


INVALID_FOODS = [
    {},
    {"name": ""},
    {"name": "   "},
    {"name": "n" * 81},
    {"name": "ok", "kcal": -1},
    {"name": "ok", "protein": -0.1},
    {"name": "ok", "fat": -1},
    {"name": "ok", "carbs": -1},
    {"name": "ok", "kcal": "many"},
    {"name": "ok", "image": "i" * 501},
    {"name": "ok", "id": "custom"},
    {"name": "ok", "unknown": 1},
]


@pytest.mark.parametrize("payload", INVALID_FOODS)
async def test_create_food_rejects_invalid_payload(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")

    response = await client.post("/v1/foods", json=payload, headers=auth_headers(actor))

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await food_count(db_session) == 0


@pytest.mark.parametrize("payload", INVALID_FOODS)
async def test_update_food_rejects_invalid_payload(
    client: AsyncClient,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()

    response = await client.put(f"/v1/foods/{food.id}", json=payload, headers=auth_headers(actor))

    assert response.status_code == 422


async def test_food_accepts_values_at_exact_limits(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")
    payload = {"name": "n" * 80, "kcal": 0, "protein": 0, "fat": 0, "carbs": 0, "image": "i" * 500}

    response = await client.post("/v1/foods", json=payload, headers=auth_headers(actor))

    assert response.status_code == 201
