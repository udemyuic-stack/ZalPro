import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta

import jwt
from httpx import AsyncClient
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.security import JWT_ALGORITHM, hash_refresh_token
from zalpro_api.models import RefreshToken, User

PASSWORD = "password123"

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]


async def login_tokens(client: AsyncClient, user: User) -> dict[str, str]:
    response = await client.post("/v1/auth/login", json={"phone": user.phone, "password": PASSWORD})
    assert response.status_code == 200
    return response.json()


async def test_refresh_rejects_token_past_expiry(
    client: AsyncClient, db_session: AsyncSession, make_user: UserFactory
) -> None:
    user = await make_user()
    tokens = await login_tokens(client, user)
    await db_session.execute(
        update(RefreshToken)
        .where(RefreshToken.token_hash == hash_refresh_token(tokens["refresh_token"]))
        .values(expires_at=datetime.now(UTC) - timedelta(seconds=1))
    )
    await db_session.commit()

    response = await client.post(
        "/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_refresh_token"


async def test_refresh_token_expiring_in_future_is_accepted(
    client: AsyncClient, db_session: AsyncSession, make_user: UserFactory
) -> None:
    user = await make_user()
    tokens = await login_tokens(client, user)
    await db_session.execute(
        update(RefreshToken)
        .where(RefreshToken.token_hash == hash_refresh_token(tokens["refresh_token"]))
        .values(expires_at=datetime.now(UTC) + timedelta(minutes=5))
    )
    await db_session.commit()

    response = await client.post(
        "/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )

    assert response.status_code == 200


async def test_concurrent_refresh_with_same_token_succeeds_only_once(
    client: AsyncClient, make_user: UserFactory
) -> None:
    user = await make_user()
    tokens = await login_tokens(client, user)
    payload = {"refresh_token": tokens["refresh_token"]}

    responses = await asyncio.gather(
        *(client.post("/v1/auth/refresh", json=payload) for _ in range(5))
    )

    statuses = sorted(response.status_code for response in responses)
    assert statuses == [200, 401, 401, 401, 401]


async def test_access_token_with_wrong_type_is_rejected(
    client: AsyncClient, settings: Settings, make_user: UserFactory
) -> None:
    user = await make_user()
    now = datetime.now(UTC)
    token = jwt.encode(
        {"sub": user.id, "typ": "refresh", "iat": now, "exp": now + timedelta(minutes=5)},
        settings.jwt_secret,
        algorithm=JWT_ALGORITHM,
    )

    response = await client.get("/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_access_token_without_type_is_rejected(
    client: AsyncClient, settings: Settings, make_user: UserFactory
) -> None:
    user = await make_user()
    now = datetime.now(UTC)
    token = jwt.encode(
        {"sub": user.id, "iat": now, "exp": now + timedelta(minutes=5)},
        settings.jwt_secret,
        algorithm=JWT_ALGORITHM,
    )

    response = await client.get("/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_access_token_signed_with_other_secret_is_rejected(
    client: AsyncClient, make_user: UserFactory
) -> None:
    user = await make_user()
    now = datetime.now(UTC)
    token = jwt.encode(
        {"sub": user.id, "typ": "access", "iat": now, "exp": now + timedelta(minutes=5)},
        "x" * 40,
        algorithm=JWT_ALGORITHM,
    )

    response = await client.get("/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_access_token_for_deleted_user_is_rejected(
    client: AsyncClient,
    db_session: AsyncSession,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    user = await make_user()
    headers = auth_headers(user)
    await db_session.delete(user)
    await db_session.commit()

    response = await client.get("/v1/users/me", headers=headers)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_list_users_is_ordered_by_creation(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    created = [await make_user() for _ in range(4)]

    response = await client.get("/v1/users", headers=auth_headers(owner))

    assert response.status_code == 200
    assert [item["id"] for item in response.json()] == [owner.id, *(user.id for user in created)]
