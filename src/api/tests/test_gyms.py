from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Gym, Trainer, User

UserFactory = Callable[..., Awaitable[User]]
GymFactory = Callable[..., Awaitable[Gym]]
TrainerFactory = Callable[..., Awaitable[Trainer]]
HeadersFactory = Callable[[User], dict[str, str]]

VALID_GYM = {
    "name": "Diamond",
    "address": "Tashkent",
    "country": "Uzbekistan",
    "region": "Tashkent",
    "district": "Yunusobod",
}
NON_OWNER_ROLES = ["user", "admin", "barmen"]


async def gym_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Gym)) or 0


@pytest.mark.parametrize("role", ["user", "admin", "barmen", "owner"])
async def test_every_signed_in_role_lists_gyms(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    await make_gym(name="B gym")
    await make_gym(name="A gym")
    actor = await make_user(role=role)

    response = await client.get("/v1/gyms", headers=auth_headers(actor))

    assert response.status_code == 200
    assert [gym["name"] for gym in response.json()] == ["A gym", "B gym"]


@pytest.mark.parametrize("role", ["user", "admin", "barmen", "owner"])
async def test_every_signed_in_role_reads_one_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    gym = await make_gym(name="Central", address="Street 1")
    actor = await make_user(role=role)

    response = await client.get(f"/v1/gyms/{gym.id}", headers=auth_headers(actor))

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == gym.id
    assert body["name"] == "Central"
    assert body["address"] == "Street 1"


async def test_gym_list_requires_authentication(client: AsyncClient) -> None:
    response = await client.get("/v1/gyms")

    assert response.status_code == 401


async def test_gym_read_requires_authentication(client: AsyncClient, make_gym: GymFactory) -> None:
    gym = await make_gym()

    response = await client.get(f"/v1/gyms/{gym.id}")

    assert response.status_code == 401


async def test_gym_write_endpoints_require_authentication(
    client: AsyncClient, make_gym: GymFactory
) -> None:
    gym = await make_gym()

    created = await client.post("/v1/gyms", json=VALID_GYM)
    updated = await client.put(f"/v1/gyms/{gym.id}", json=VALID_GYM)
    deleted = await client.delete(f"/v1/gyms/{gym.id}")

    assert created.status_code == updated.status_code == deleted.status_code == 401


async def test_read_unknown_gym_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user()

    response = await client.get("/v1/gyms/missing", headers=auth_headers(actor))

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "not_found"


async def test_owner_creates_gym(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")

    response = await client.post("/v1/gyms", json=VALID_GYM, headers=auth_headers(owner))

    assert response.status_code == 201
    body = response.json()
    assert body["id"]
    assert {key: body[key] for key in VALID_GYM} == VALID_GYM
    stored = await db_session.get(Gym, body["id"])
    assert stored is not None
    assert stored.name == "Diamond"


async def test_owner_creates_gym_with_only_name_and_defaults_rest(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.post("/v1/gyms", json={"name": "Solo"}, headers=auth_headers(owner))

    assert response.status_code == 201
    body = response.json()
    assert body["address"] == body["country"] == body["region"] == body["district"] == ""


@pytest.mark.parametrize("role", NON_OWNER_ROLES)
async def test_non_owner_cannot_create_gym(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/gyms", json=VALID_GYM, headers=auth_headers(actor))

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await gym_count(db_session) == 0


async def test_owner_updates_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym(name="Old")
    gym_id = gym.id

    response = await client.put(f"/v1/gyms/{gym_id}", json=VALID_GYM, headers=auth_headers(owner))

    assert response.status_code == 200
    assert response.json()["name"] == "Diamond"
    db_session.expire_all()
    stored = await db_session.get(Gym, gym_id)
    assert stored is not None
    assert stored.name == "Diamond"
    assert stored.district == "Yunusobod"


@pytest.mark.parametrize("role", NON_OWNER_ROLES)
async def test_non_owner_cannot_update_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    gym = await make_gym(name="Old")
    gym_id = gym.id

    response = await client.put(f"/v1/gyms/{gym_id}", json=VALID_GYM, headers=auth_headers(actor))

    assert response.status_code == 403
    db_session.expire_all()
    stored = await db_session.get(Gym, gym_id)
    assert stored is not None
    assert stored.name == "Old"


async def test_update_unknown_gym_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.put("/v1/gyms/missing", json=VALID_GYM, headers=auth_headers(owner))

    assert response.status_code == 404


async def test_owner_deletes_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()

    response = await client.delete(f"/v1/gyms/{gym.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert response.content == b""
    assert await gym_count(db_session) == 0
    follow_up = await client.get(f"/v1/gyms/{gym.id}", headers=auth_headers(owner))
    assert follow_up.status_code == 404


@pytest.mark.parametrize("role", NON_OWNER_ROLES)
async def test_non_owner_cannot_delete_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    gym = await make_gym()

    response = await client.delete(f"/v1/gyms/{gym.id}", headers=auth_headers(actor))

    assert response.status_code == 403
    assert await gym_count(db_session) == 1


async def test_delete_unknown_gym_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.delete("/v1/gyms/missing", headers=auth_headers(owner))

    assert response.status_code == 404


async def test_deleting_gym_clears_gym_id_of_users(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()
    member = await make_user(gym_id=gym.id)
    member_id = member.id
    gym_id = gym.id
    assert member.gym_id == gym_id

    response = await client.delete(f"/v1/gyms/{gym_id}", headers=auth_headers(owner))

    assert response.status_code == 204
    db_session.expire_all()
    stored = await db_session.get(User, member_id)
    assert stored is not None
    assert stored.gym_id is None


async def test_deleting_gym_clears_gym_id_of_trainers(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()
    coach = await make_user(role="admin", gym_id=gym.id)
    await make_trainer(coach)
    coach_id = coach.id

    await client.delete(f"/v1/gyms/{gym.id}", headers=auth_headers(owner))

    db_session.expire_all()
    stored = await db_session.get(Trainer, coach_id)
    assert stored is not None
    assert stored.gym_id is None


@pytest.mark.parametrize(
    "payload",
    [
        {"name": ""},
        {"name": "   "},
        {"name": "n" * 61},
        {"name": "ok", "address": "a" * 201},
        {"name": "ok", "country": "c" * 61},
        {"name": "ok", "region": "r" * 61},
        {"name": "ok", "district": "d" * 61},
        {},
    ],
)
async def test_create_gym_rejects_field_limit_violations(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    payload: dict[str, Any],
) -> None:
    owner = await make_user(role="owner")

    response = await client.post("/v1/gyms", json=payload, headers=auth_headers(owner))

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await gym_count(db_session) == 0


@pytest.mark.parametrize(
    "payload",
    [
        {"name": ""},
        {"name": "n" * 61},
        {"name": "ok", "address": "a" * 201},
        {"name": "ok", "country": "c" * 61},
        {"name": "ok", "region": "r" * 61},
        {"name": "ok", "district": "d" * 61},
    ],
)
async def test_update_gym_rejects_field_limit_violations(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()

    response = await client.put(f"/v1/gyms/{gym.id}", json=payload, headers=auth_headers(owner))

    assert response.status_code == 422


async def test_gym_accepts_values_at_exact_limits(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")
    payload = {
        "name": "n" * 60,
        "address": "a" * 200,
        "country": "c" * 60,
        "region": "r" * 60,
        "district": "d" * 60,
    }

    response = await client.post("/v1/gyms", json=payload, headers=auth_headers(owner))

    assert response.status_code == 201


async def test_create_gym_rejects_extra_field(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")

    response = await client.post(
        "/v1/gyms", json={**VALID_GYM, "id": "custom"}, headers=auth_headers(owner)
    )

    assert response.status_code == 422
    assert await gym_count(db_session) == 0


async def test_update_gym_rejects_extra_field(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()

    response = await client.put(
        f"/v1/gyms/{gym.id}", json={**VALID_GYM, "owner_id": "x"}, headers=auth_headers(owner)
    )

    assert response.status_code == 422
