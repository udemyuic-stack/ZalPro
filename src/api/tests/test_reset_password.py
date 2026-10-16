from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import TEST_PASSWORD
from tests.test_legacy_password import HASH, SALT
from zalpro_api.models import User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

NEW_PASSWORD = "brand-new-pass1"


async def login(client: AsyncClient, phone: str, password: str) -> Any:
    return await client.post("/v1/auth/login", json={"phone": phone, "password": password})


async def test_owner_resets_password(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")
    member = await make_user()

    response = await client.post(
        f"/v1/users/{member.id}/reset-password",
        json={"new_password": NEW_PASSWORD},
        headers=auth_headers(owner),
    )

    assert response.status_code == 204
    assert (await login(client, member.phone, NEW_PASSWORD)).status_code == 200
    assert (await login(client, member.phone, TEST_PASSWORD)).status_code == 401


async def test_reset_revokes_refresh_tokens(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")
    member = await make_user()
    tokens = (await login(client, member.phone, TEST_PASSWORD)).json()

    await client.post(
        f"/v1/users/{member.id}/reset-password",
        json={"new_password": NEW_PASSWORD},
        headers=auth_headers(owner),
    )

    refreshed = await client.post(
        "/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refreshed.status_code == 401


async def test_reset_clears_legacy_hash(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    member = await make_user(legacy_hash=HASH, legacy_salt=SALT, legacy_algo="scrypt")

    await client.post(
        f"/v1/users/{member.id}/reset-password",
        json={"new_password": NEW_PASSWORD},
        headers=auth_headers(owner),
    )

    await db_session.refresh(member)
    assert member.legacy_hash is None
    assert member.legacy_algo is None


@pytest.mark.parametrize("role", ["admin", "barmen", "user"])
async def test_non_owner_cannot_reset(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    actor = await make_user(role=role)
    member = await make_user()

    response = await client.post(
        f"/v1/users/{member.id}/reset-password",
        json={"new_password": NEW_PASSWORD},
        headers=auth_headers(actor),
    )

    assert response.status_code == 403
    assert (await login(client, member.phone, TEST_PASSWORD)).status_code == 200


async def test_unknown_user_is_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.post(
        "/v1/users/missing/reset-password",
        json={"new_password": NEW_PASSWORD},
        headers=auth_headers(owner),
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    "body", [{"new_password": "short"}, {}, {"new_password": NEW_PASSWORD, "x": 1}]
)
async def test_invalid_body_is_rejected(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    body: dict[str, Any],
) -> None:
    owner = await make_user(role="owner")
    member = await make_user()

    response = await client.post(
        f"/v1/users/{member.id}/reset-password", json=body, headers=auth_headers(owner)
    )

    assert response.status_code == 422


async def test_anonymous_cannot_reset(client: AsyncClient, make_user: UserFactory) -> None:
    member = await make_user()

    response = await client.post(
        f"/v1/users/{member.id}/reset-password", json={"new_password": NEW_PASSWORD}
    )

    assert response.status_code == 401
