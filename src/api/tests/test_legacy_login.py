from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import UserFactory
from tests.test_legacy_password import HASH, PASSWORD, SALT, SALT_SEPARATOR, SIGNER_KEY
from zalpro_api.core.config import Settings
from zalpro_api.core.security import verify_password
from zalpro_api.models import RefreshToken, User


@pytest.fixture
def legacy_enabled(settings: Settings, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "legacy_scrypt_signer_key", SIGNER_KEY)
    monkeypatch.setattr(settings, "legacy_scrypt_salt_separator", SALT_SEPARATOR)
    monkeypatch.setattr(settings, "legacy_scrypt_rounds", 8)
    monkeypatch.setattr(settings, "legacy_scrypt_mem_cost", 14)


async def make_legacy(make_user: UserFactory) -> User:
    return await make_user(legacy_hash=HASH, legacy_salt=SALT, legacy_algo="scrypt")


async def attempt(client: AsyncClient, phone: str, password: str) -> Any:
    return await client.post("/v1/auth/login", json={"phone": phone, "password": password})


async def test_legacy_password_logs_in_and_rehashes(
    client: AsyncClient, make_user: UserFactory, db_session: AsyncSession, legacy_enabled: None
) -> None:
    user = await make_legacy(make_user)
    response = await attempt(client, user.phone, PASSWORD)
    assert response.status_code == 200
    await db_session.refresh(user)
    assert user.legacy_hash is None
    assert user.legacy_salt is None
    assert user.legacy_algo is None
    assert await verify_password(user.password_hash, PASSWORD)


async def test_second_login_uses_argon2_only(
    client: AsyncClient, make_user: UserFactory, legacy_enabled: None
) -> None:
    user = await make_legacy(make_user)
    assert (await attempt(client, user.phone, PASSWORD)).status_code == 200
    assert (await attempt(client, user.phone, PASSWORD)).status_code == 200


async def test_wrong_password_keeps_legacy_columns(
    client: AsyncClient, make_user: UserFactory, db_session: AsyncSession, legacy_enabled: None
) -> None:
    user = await make_legacy(make_user)
    response = await attempt(client, user.phone, "wrong-password")
    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_credentials"
    await db_session.refresh(user)
    assert user.legacy_hash == HASH


async def test_legacy_login_disabled_without_settings(
    client: AsyncClient, make_user: UserFactory
) -> None:
    user = await make_legacy(make_user)
    response = await attempt(client, user.phone, PASSWORD)
    assert response.status_code == 401


async def test_legacy_login_issues_usable_tokens(
    client: AsyncClient, make_user: UserFactory, legacy_enabled: None
) -> None:
    user = await make_legacy(make_user)
    tokens = (await attempt(client, user.phone, PASSWORD)).json()
    me = await client.get(
        "/v1/users/me", headers={"Authorization": f"Bearer {tokens['access_token']}"}
    )
    assert me.status_code == 200
    assert me.json()["id"] == user.id


async def test_legacy_login_stores_refresh_token(
    client: AsyncClient, make_user: UserFactory, db_session: AsyncSession, legacy_enabled: None
) -> None:
    user = await make_legacy(make_user)
    await attempt(client, user.phone, PASSWORD)
    count = await db_session.scalar(
        select(func.count()).select_from(RefreshToken).where(RefreshToken.user_id == user.id)
    )
    assert count == 1
