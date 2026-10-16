from collections.abc import Awaitable, Callable

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Exercise, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

PAYLOAD = {"name": "Barbell row mine", "muscle": "back"}


@pytest.mark.parametrize("role", ["admin", "owner"])
async def test_staff_creates_override_with_base(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post(
        "/v1/exercises",
        json={**PAYLOAD, "base": "Barbell row"},
        headers=auth_headers(actor),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["base"] == "Barbell row"
    assert body["created_by"] == actor.id
    stored = await db_session.get(Exercise, body["id"])
    assert stored is not None
    assert stored.base == "Barbell row"


async def test_base_is_optional_on_create(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.post("/v1/exercises", json=PAYLOAD, headers=auth_headers(actor))

    assert response.status_code == 201
    assert response.json()["base"] == ""


async def test_base_longer_than_limit_is_rejected(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.post(
        "/v1/exercises", json={**PAYLOAD, "base": "x" * 81}, headers=auth_headers(actor)
    )

    assert response.status_code == 422


async def test_base_survives_update_and_cannot_be_changed(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")
    headers = auth_headers(actor)
    created = (
        await client.post("/v1/exercises", json={**PAYLOAD, "base": "Barbell row"}, headers=headers)
    ).json()

    kept = await client.put(
        f"/v1/exercises/{created['id']}", json={**PAYLOAD, "tip": "new"}, headers=headers
    )
    forged = await client.put(
        f"/v1/exercises/{created['id']}", json={**PAYLOAD, "base": "Other"}, headers=headers
    )

    assert kept.status_code == 200
    assert kept.json()["base"] == "Barbell row"
    assert forged.status_code == 422


@pytest.mark.parametrize("role", ["user", "barmen"])
async def test_non_staff_cannot_create_override(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    actor = await make_user(role=role)

    response = await client.post(
        "/v1/exercises", json={**PAYLOAD, "base": "Barbell row"}, headers=auth_headers(actor)
    )

    assert response.status_code == 403
