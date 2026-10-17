from collections.abc import Awaitable, Callable
from copy import deepcopy
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Plan, User

UserFactory = Callable[..., Awaitable[User]]
PlanFactory = Callable[..., Awaitable[Plan]]
HeadersFactory = Callable[[User], dict[str, str]]

ITEM = {"name": "Oatmeal", "grams": 80, "kcal": 300, "protein": 10}
MEAL = {"time": "08:00", "title": "Breakfast", "items": [ITEM]}
VALID_PLAN = {
    "title": "Mass gain",
    "note": "Drink water",
    "forbidden": ["sugar", "soda"],
    "meals": [MEAL],
    "week": {"1": [MEAL], "7": [{"time": "20:00", "title": "Dinner", "items": []}]},
    "photos": {"1": "https://i/day1.png", "3": "https://i/day3.png"},
}
READ_ROLES = ["user", "barmen", "admin", "owner"]
NON_STAFF_ROLES = ["user", "barmen"]
STAFF_ROLES = ["admin", "owner"]


async def plan_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Plan)) or 0


def with_field(field: str, value: Any) -> dict[str, Any]:
    payload = deepcopy(VALID_PLAN)
    payload[field] = value
    return payload


@pytest.mark.parametrize("role", READ_ROLES)
async def test_every_signed_in_role_lists_plans_sorted_by_title_then_id(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    await make_plan(id="b", title="Slim")
    await make_plan(id="c", title="Mass")
    await make_plan(id="a", title="Mass")
    actor = await make_user(role=role)

    response = await client.get("/v1/plans", headers=auth_headers(actor))

    assert response.status_code == 200
    assert [(plan["title"], plan["id"]) for plan in response.json()] == [
        ("Mass", "a"),
        ("Mass", "c"),
        ("Slim", "b"),
    ]


@pytest.mark.parametrize("role", READ_ROLES)
async def test_every_signed_in_role_reads_one_plan(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    plan = await make_plan(
        title="Cut",
        note="n",
        forbidden=["bread"],
        meals=[MEAL],
        week={"2": [MEAL]},
        photos={"2": "p"},
    )
    actor = await make_user(role=role)

    response = await client.get(f"/v1/plans/{plan.id}", headers=auth_headers(actor))

    assert response.status_code == 200
    assert response.json() == {
        "id": plan.id,
        "title": "Cut",
        "note": "n",
        "forbidden": ["bread"],
        "meals": [MEAL],
        "week": {"2": [MEAL]},
        "photos": {"2": "p"},
    }


async def test_plan_with_database_defaults_reads_as_empty_collections(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
) -> None:
    plan = await make_plan(title="Bare")
    actor = await make_user()

    response = await client.get(f"/v1/plans/{plan.id}", headers=auth_headers(actor))

    body = response.json()
    assert body["note"] == ""
    assert body["forbidden"] == []
    assert body["meals"] == []
    assert body["week"] == {}
    assert body["photos"] == {}


async def test_plan_read_endpoints_require_authentication(
    client: AsyncClient, make_plan: PlanFactory
) -> None:
    plan = await make_plan()

    listed = await client.get("/v1/plans")
    read = await client.get(f"/v1/plans/{plan.id}")

    assert listed.status_code == read.status_code == 401


async def test_plan_write_endpoints_require_authentication(
    client: AsyncClient, make_plan: PlanFactory, db_session: AsyncSession
) -> None:
    plan = await make_plan()

    created = await client.post("/v1/plans", json=VALID_PLAN)
    updated = await client.put(f"/v1/plans/{plan.id}", json=VALID_PLAN)
    deleted = await client.delete(f"/v1/plans/{plan.id}")

    assert created.status_code == updated.status_code == deleted.status_code == 401
    assert await plan_count(db_session) == 1


async def test_read_unknown_plan_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user()

    response = await client.get("/v1/plans/missing", headers=auth_headers(actor))

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "not_found"


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_creates_plan_and_json_round_trips(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/plans", json=VALID_PLAN, headers=auth_headers(actor))

    assert response.status_code == 201
    body = response.json()
    assert body["id"]
    assert {key: body[key] for key in VALID_PLAN} == VALID_PLAN
    fetched = await client.get(f"/v1/plans/{body['id']}", headers=auth_headers(actor))
    assert fetched.json() == body
    stored = await db_session.get(Plan, body["id"])
    assert stored is not None
    assert stored.meals == [MEAL]
    assert stored.week["7"][0]["title"] == "Dinner"
    assert stored.photos == VALID_PLAN["photos"]
    assert stored.forbidden == ["sugar", "soda"]


async def test_create_plan_with_only_title_defaults_rest(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.post("/v1/plans", json={"title": "Lean"}, headers=auth_headers(actor))

    assert response.status_code == 201
    body = response.json()
    assert body["note"] == ""
    assert body["forbidden"] == []
    assert body["meals"] == []
    assert body["week"] == {}
    assert body["photos"] == {}


async def test_meal_item_rejects_image_url(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    payload = {
        "title": "T",
        "meals": [{"items": [{"name": "Nut", "kcal": 60, "image": "https://i/o.png"}]}],
    }

    response = await client.post("/v1/plans", json=payload, headers=auth_headers(actor))

    assert response.status_code == 422
    assert await plan_count(db_session) == 0


async def test_legacy_meal_item_image_is_not_returned(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
) -> None:
    legacy = {"time": "09:00", "title": "Snack", "items": [{"name": "Nut", "image": "https://i/o"}]}
    plan = await make_plan(meals=[legacy], week={"2": [legacy]})
    actor = await make_user(role="user")

    response = await client.get(f"/v1/plans/{plan.id}", headers=auth_headers(actor))

    assert response.status_code == 200
    expected = {
        "time": "09:00",
        "title": "Snack",
        "items": [{"name": "Nut", "grams": 0, "kcal": 0, "protein": 0}],
    }
    assert response.json()["meals"] == [expected]
    assert response.json()["week"] == {"2": [expected]}
    assert "https://i/o" not in response.text


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_create_plan(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/plans", json=VALID_PLAN, headers=auth_headers(actor))

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await plan_count(db_session) == 0


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_gets_403_before_validation_error(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/plans", json={"title": ""}, headers=auth_headers(actor))

    assert response.status_code == 403


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_replaces_plan_fully(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    plan = await make_plan(
        title="Old",
        note="old note",
        forbidden=["x"],
        meals=[MEAL],
        week={"1": [MEAL]},
        photos={"1": "p"},
    )
    plan_id = plan.id

    response = await client.put(
        f"/v1/plans/{plan_id}", json={"title": "New"}, headers=auth_headers(actor)
    )

    assert response.status_code == 200
    assert response.json() == {
        "id": plan_id,
        "title": "New",
        "note": "",
        "forbidden": [],
        "meals": [],
        "week": {},
        "photos": {},
    }
    db_session.expire_all()
    stored = await db_session.get(Plan, plan_id)
    assert stored is not None
    assert (stored.title, stored.note, stored.forbidden) == ("New", "", [])
    assert (stored.meals, stored.week, stored.photos) == ([], {}, {})


async def test_update_replaces_nested_json(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    plan = await make_plan(meals=[MEAL], week={"1": [MEAL]}, photos={"1": "p"})
    plan_id = plan.id

    response = await client.put(
        f"/v1/plans/{plan_id}", json=VALID_PLAN, headers=auth_headers(actor)
    )

    assert response.status_code == 200
    db_session.expire_all()
    stored = await db_session.get(Plan, plan_id)
    assert stored is not None
    assert set(stored.week) == {"1", "7"}
    assert stored.photos == VALID_PLAN["photos"]


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_update_plan(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    plan = await make_plan(title="Old")
    plan_id = plan.id

    response = await client.put(
        f"/v1/plans/{plan_id}", json=VALID_PLAN, headers=auth_headers(actor)
    )

    assert response.status_code == 403
    db_session.expire_all()
    stored = await db_session.get(Plan, plan_id)
    assert stored is not None
    assert stored.title == "Old"


async def test_update_unknown_plan_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.put("/v1/plans/missing", json=VALID_PLAN, headers=auth_headers(actor))

    assert response.status_code == 404


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_deletes_plan(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    plan = await make_plan()

    response = await client.delete(f"/v1/plans/{plan.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert response.content == b""
    assert await plan_count(db_session) == 0
    follow_up = await client.get(f"/v1/plans/{plan.id}", headers=auth_headers(actor))
    assert follow_up.status_code == 404


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_delete_plan(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    plan = await make_plan()

    response = await client.delete(f"/v1/plans/{plan.id}", headers=auth_headers(actor))

    assert response.status_code == 403
    assert await plan_count(db_session) == 1


async def test_delete_unknown_plan_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="owner")

    response = await client.delete("/v1/plans/missing", headers=auth_headers(actor))

    assert response.status_code == 404


async def test_deleting_plan_leaves_user_plan_id_untouched(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    plan = await make_plan()
    member = await make_user(plan_id=plan.id)
    member_id = member.id
    plan_id = plan.id

    response = await client.delete(f"/v1/plans/{plan_id}", headers=auth_headers(owner))

    assert response.status_code == 204
    db_session.expire_all()
    stored = await db_session.get(User, member_id)
    assert stored is not None
    assert stored.plan_id == plan_id


def meals_of(count: int) -> list[dict[str, Any]]:
    return [{"time": "08:00", "title": "M", "items": []} for _ in range(count)]


def item_with(**overrides: Any) -> dict[str, Any]:
    return {"name": "x", "grams": 1, "kcal": 1, "protein": 1, **overrides}


def meal_with_item(item: dict[str, Any]) -> list[dict[str, Any]]:
    return [{"time": "08:00", "title": "M", "items": [item]}]


INVALID_PLANS: list[dict[str, Any]] = [
    {},
    {"title": ""},
    {"title": "   "},
    {"title": "t" * 121},
    {"title": "ok", "note": "n" * 5001},
    {"title": "ok", "forbidden": ["f"] * 51},
    {"title": "ok", "forbidden": ["f" * 81]},
    {"title": "ok", "forbidden": "sugar"},
    {"title": "ok", "meals": meals_of(21)},
    {"title": "ok", "meals": {"1": []}},
    {"title": "ok", "meals": [{"time": "t" * 11, "title": "M", "items": []}]},
    {"title": "ok", "meals": [{"time": "08:00", "title": "m" * 61, "items": []}]},
    {"title": "ok", "meals": [{"time": "08:00", "title": "M", "items": [item_with()] * 51}]},
    {"title": "ok", "meals": [{"time": "08:00", "title": "M", "items": [], "extra": 1}]},
    {"title": "ok", "meals": meal_with_item(item_with(name="n" * 81))},
    {"title": "ok", "meals": meal_with_item(item_with(grams=-1))},
    {"title": "ok", "meals": meal_with_item(item_with(kcal=-1))},
    {"title": "ok", "meals": meal_with_item(item_with(protein=-0.5))},
    {"title": "ok", "meals": meal_with_item(item_with(grams="lots"))},
    {"title": "ok", "meals": meal_with_item(item_with(image="https://i/o.png"))},
    {"title": "ok", "meals": meal_with_item(item_with(extra=1))},
    {"title": "ok", "meals": meal_with_item({"grams": 1})},
    {"title": "ok", "week": {"0": []}},
    {"title": "ok", "week": {"8": []}},
    {"title": "ok", "week": {"mon": []}},
    {"title": "ok", "week": {"1": meals_of(21)}},
    {"title": "ok", "week": {"1": meal_with_item(item_with(kcal=-1))}},
    {"title": "ok", "week": []},
    {"title": "ok", "photos": {"0": "p"}},
    {"title": "ok", "photos": {"8": "p"}},
    {"title": "ok", "photos": {"x": "p"}},
    {"title": "ok", "photos": {"1": "p" * 501}},
    {"title": "ok", "photos": {"1": 5}},
    {"title": "ok", "id": "custom"},
    {"title": "ok", "unknown": 1},
]


@pytest.mark.parametrize("payload", INVALID_PLANS)
async def test_create_plan_rejects_invalid_payload(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")

    response = await client.post("/v1/plans", json=payload, headers=auth_headers(actor))

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await plan_count(db_session) == 0


@pytest.mark.parametrize("payload", INVALID_PLANS)
async def test_update_plan_rejects_invalid_payload(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")
    plan = await make_plan()

    response = await client.put(f"/v1/plans/{plan.id}", json=payload, headers=auth_headers(actor))

    assert response.status_code == 422


async def test_rejected_update_leaves_plan_unchanged(
    client: AsyncClient,
    make_user: UserFactory,
    make_plan: PlanFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    plan = await make_plan(title="Keep", meals=[MEAL])
    plan_id = plan.id

    response = await client.put(
        f"/v1/plans/{plan_id}",
        json=with_field("week", {"9": []}),
        headers=auth_headers(actor),
    )

    assert response.status_code == 422
    db_session.expire_all()
    stored = await db_session.get(Plan, plan_id)
    assert stored is not None
    assert (stored.title, stored.meals) == ("Keep", [MEAL])


async def test_plan_accepts_values_at_exact_limits(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")
    full_meal = {
        "time": "t" * 10,
        "title": "m" * 60,
        "items": [item_with(name="n" * 80)] * 50,
    }
    payload = {
        "title": "t" * 120,
        "note": "n" * 5000,
        "forbidden": ["f" * 80] * 50,
        "meals": [full_meal] * 20,
        "week": {str(day): [full_meal] * 20 for day in range(1, 8)},
        "photos": {str(day): "p" * 500 for day in range(1, 8)},
    }

    response = await client.post("/v1/plans", json=payload, headers=auth_headers(actor))

    assert response.status_code == 201
    body = response.json()
    assert len(body["meals"]) == 20
    assert sorted(body["week"]) == [str(day) for day in range(1, 8)]
    assert len(body["photos"]) == 7
