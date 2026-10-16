from collections.abc import Awaitable, Callable
from datetime import timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.security import create_access_token
from zalpro_api.models import User

PASSWORD = "password123"
NEW_PASSWORD = "newpassword456"
PHONE = "998901234567"

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]


async def register(
    client: AsyncClient,
    phone: str = PHONE,
    password: str = PASSWORD,
    name: str = "Ali",
) -> dict[str, Any]:
    response = await client.post(
        "/v1/auth/register", json={"name": name, "phone": phone, "password": password}
    )
    assert response.status_code == 201
    return response.json()


async def login(client: AsyncClient, phone: str, password: str) -> Any:
    return await client.post("/v1/auth/login", json={"phone": phone, "password": password})


def bearer(tokens: dict[str, Any]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def refresh(client: AsyncClient, token: str) -> Any:
    return await client.post("/v1/auth/refresh", json={"refresh_token": token})


async def user_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(User)) or 0


async def test_register_returns_tokens_and_creates_user_role(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    response = await client.post(
        "/v1/auth/register", json={"name": "Ali", "phone": PHONE, "password": PASSWORD}
    )

    assert response.status_code == 201
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["token_type"] == "bearer"
    me = await client.get("/v1/users/me", headers=bearer(body))
    assert me.status_code == 200
    assert me.json()["role"] == "user"
    assert me.json()["name"] == "Ali"


async def test_register_rejects_role_field_and_creates_no_user(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    response = await client.post(
        "/v1/auth/register",
        json={"name": "Ali", "phone": PHONE, "password": PASSWORD, "role": "owner"},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await user_count(db_session) == 0


async def test_register_rejects_gym_id_field(client: AsyncClient, db_session: AsyncSession) -> None:
    response = await client.post(
        "/v1/auth/register",
        json={"name": "Ali", "phone": PHONE, "password": PASSWORD, "gym_id": "x"},
    )

    assert response.status_code == 422
    assert await user_count(db_session) == 0


async def test_register_rejects_duplicate_phone_with_different_formatting(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    await register(client, phone="90 123 45 67")

    response = await client.post(
        "/v1/auth/register", json={"name": "Vali", "phone": "998901234567", "password": PASSWORD}
    )

    assert response.status_code == 409
    assert await user_count(db_session) == 1


async def test_register_rejects_duplicate_phone_with_plus_and_dashes(
    client: AsyncClient,
) -> None:
    await register(client, phone="998901234567")

    response = await client.post(
        "/v1/auth/register",
        json={"name": "Vali", "phone": "+998 (90) 123-45-67", "password": PASSWORD},
    )

    assert response.status_code == 409


async def test_register_rejects_phone_of_existing_user(
    client: AsyncClient, make_user: UserFactory
) -> None:
    existing = await make_user()

    response = await client.post(
        "/v1/auth/register",
        json={"name": "Vali", "phone": existing.phone, "password": PASSWORD},
    )

    assert response.status_code == 409


async def test_register_normalizes_phone(client: AsyncClient) -> None:
    tokens = await register(client, phone="90 123 45 67")

    response = await client.get("/v1/users/me", headers=bearer(tokens))

    assert response.json()["phone"] == "998901234567"


async def test_register_strips_formatting_from_full_phone(client: AsyncClient) -> None:
    tokens = await register(client, phone="+998 90 123-45-67")

    response = await client.get("/v1/users/me", headers=bearer(tokens))

    assert response.json()["phone"] == "998901234567"


async def test_register_rejects_short_password(
    client: AsyncClient, db_session: AsyncSession
) -> None:
    response = await client.post(
        "/v1/auth/register", json={"name": "Ali", "phone": PHONE, "password": "short12"}
    )

    assert response.status_code == 422
    assert await user_count(db_session) == 0


async def test_register_accepts_password_of_exactly_eight_characters(client: AsyncClient) -> None:
    response = await client.post(
        "/v1/auth/register", json={"name": "Ali", "phone": PHONE, "password": "12345678"}
    )

    assert response.status_code == 201


@pytest.mark.parametrize(
    "payload",
    [
        {"phone": PHONE, "password": PASSWORD},
        {"name": "Ali", "password": PASSWORD},
        {"name": "Ali", "phone": PHONE},
        {"name": "", "phone": PHONE, "password": PASSWORD},
        {"name": "Ali", "phone": "123", "password": PASSWORD},
    ],
)
async def test_register_rejects_invalid_payload(
    client: AsyncClient, payload: dict[str, str]
) -> None:
    response = await client.post("/v1/auth/register", json=payload)

    assert response.status_code == 422


async def test_login_returns_tokens_for_valid_credentials(client: AsyncClient) -> None:
    await register(client)

    response = await login(client, PHONE, PASSWORD)

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["expires_in"] > 0


async def test_login_accepts_differently_formatted_phone(client: AsyncClient) -> None:
    await register(client)

    response = await login(client, "90 123 45 67", PASSWORD)

    assert response.status_code == 200


async def test_login_rejects_wrong_password(client: AsyncClient) -> None:
    await register(client)

    response = await login(client, PHONE, "wrong-password")

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_credentials"


async def test_login_rejects_unknown_phone(client: AsyncClient) -> None:
    response = await login(client, "998900000000", PASSWORD)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_credentials"


async def test_login_gives_identical_body_for_wrong_password_and_unknown_phone(
    client: AsyncClient,
) -> None:
    await register(client)

    wrong_password = await login(client, PHONE, "wrong-password")
    unknown_phone = await login(client, "998900000000", "wrong-password")

    assert wrong_password.status_code == unknown_phone.status_code == 401
    assert wrong_password.json() == unknown_phone.json()


async def test_login_rejects_unknown_field(client: AsyncClient) -> None:
    response = await client.post(
        "/v1/auth/login", json={"phone": PHONE, "password": PASSWORD, "role": "owner"}
    )

    assert response.status_code == 422


async def test_refresh_rotates_token_pair(client: AsyncClient) -> None:
    tokens = await register(client)

    response = await refresh(client, tokens["refresh_token"])

    assert response.status_code == 200
    rotated = response.json()
    assert rotated["refresh_token"] != tokens["refresh_token"]
    me = await client.get("/v1/users/me", headers=bearer(rotated))
    assert me.status_code == 200
    again = await refresh(client, rotated["refresh_token"])
    assert again.status_code == 200


async def test_refresh_rejects_old_token_after_rotation(client: AsyncClient) -> None:
    tokens = await register(client)
    await refresh(client, tokens["refresh_token"])

    response = await refresh(client, tokens["refresh_token"])

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_refresh_token"


async def test_refresh_rejects_reused_token_even_after_new_one_was_used(
    client: AsyncClient,
) -> None:
    tokens = await register(client)
    first = (await refresh(client, tokens["refresh_token"])).json()
    await refresh(client, first["refresh_token"])

    reused = await refresh(client, tokens["refresh_token"])

    assert reused.status_code == 401


async def test_refresh_rejects_unknown_token(client: AsyncClient) -> None:
    response = await refresh(client, "not-a-real-refresh-token")

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_refresh_token"


async def test_expired_access_token_returns_token_expired(
    client: AsyncClient, make_user: UserFactory, settings: Settings
) -> None:
    user = await make_user()
    token = create_access_token(user.id, settings, lifetime=timedelta(hours=-1))

    response = await client.get("/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "token_expired"


async def test_missing_authorization_header_returns_401(client: AsyncClient) -> None:
    response = await client.get("/v1/users/me")

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "unauthorized"


async def test_garbage_bearer_token_returns_401(client: AsyncClient) -> None:
    response = await client.get("/v1/users/me", headers={"Authorization": "Bearer garbage"})

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_non_bearer_scheme_returns_401(client: AsyncClient) -> None:
    response = await client.get("/v1/users/me", headers={"Authorization": "Basic abc"})

    assert response.status_code == 401


async def test_token_signed_with_other_secret_returns_401(
    client: AsyncClient, make_user: UserFactory, settings: Settings
) -> None:
    user = await make_user()
    forged_settings = settings.model_copy(update={"jwt_secret": "x" * 40})
    token = create_access_token(user.id, forged_settings)

    response = await client.get("/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_token_of_deleted_user_returns_401(client: AsyncClient, settings: Settings) -> None:
    token = create_access_token("missing-user-id", settings)

    response = await client.get("/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401


async def test_change_password_rejects_wrong_current_password(client: AsyncClient) -> None:
    tokens = await register(client)

    response = await client.post(
        "/v1/auth/change-password",
        json={"current_password": "wrong-password", "new_password": NEW_PASSWORD},
        headers=bearer(tokens),
    )

    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "wrong_password"
    assert (await login(client, PHONE, PASSWORD)).status_code == 200


async def test_change_password_requires_authentication(client: AsyncClient) -> None:
    response = await client.post(
        "/v1/auth/change-password",
        json={"current_password": PASSWORD, "new_password": NEW_PASSWORD},
    )

    assert response.status_code == 401


async def test_change_password_rejects_short_new_password(client: AsyncClient) -> None:
    tokens = await register(client)

    response = await client.post(
        "/v1/auth/change-password",
        json={"current_password": PASSWORD, "new_password": "short"},
        headers=bearer(tokens),
    )

    assert response.status_code == 422


async def test_change_password_succeeds_and_revokes_refresh_tokens(client: AsyncClient) -> None:
    tokens = await register(client)
    second_session = (await login(client, PHONE, PASSWORD)).json()

    response = await client.post(
        "/v1/auth/change-password",
        json={"current_password": PASSWORD, "new_password": NEW_PASSWORD},
        headers=bearer(tokens),
    )

    assert response.status_code == 204
    assert response.content == b""
    assert (await refresh(client, tokens["refresh_token"])).status_code == 401
    assert (await refresh(client, second_session["refresh_token"])).status_code == 401


async def test_login_uses_new_password_after_change(client: AsyncClient) -> None:
    tokens = await register(client)
    await client.post(
        "/v1/auth/change-password",
        json={"current_password": PASSWORD, "new_password": NEW_PASSWORD},
        headers=bearer(tokens),
    )

    assert (await login(client, PHONE, NEW_PASSWORD)).status_code == 200
    assert (await login(client, PHONE, PASSWORD)).status_code == 401


async def test_logout_revokes_refresh_token(client: AsyncClient) -> None:
    tokens = await register(client)

    response = await client.post(
        "/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers=bearer(tokens),
    )

    assert response.status_code == 204
    assert (await refresh(client, tokens["refresh_token"])).status_code == 401


async def test_logout_requires_authentication(client: AsyncClient) -> None:
    tokens = await register(client)

    response = await client.post("/v1/auth/logout", json={"refresh_token": tokens["refresh_token"]})

    assert response.status_code == 401
    assert (await refresh(client, tokens["refresh_token"])).status_code == 200


async def test_logout_does_not_revoke_other_users_refresh_token(client: AsyncClient) -> None:
    first = await register(client, phone="998901111111")
    second = await register(client, phone="998902222222")

    response = await client.post(
        "/v1/auth/logout",
        json={"refresh_token": second["refresh_token"]},
        headers=bearer(first),
    )

    assert response.status_code == 204
    assert (await refresh(client, second["refresh_token"])).status_code == 200


async def test_logout_keeps_other_sessions_of_same_user(client: AsyncClient) -> None:
    tokens = await register(client)
    other = (await login(client, PHONE, PASSWORD)).json()

    await client.post(
        "/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers=bearer(tokens),
    )

    assert (await refresh(client, other["refresh_token"])).status_code == 200


async def test_password_hash_never_appears_in_responses(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")
    registered = await client.post(
        "/v1/auth/register", json={"name": "Ali", "phone": PHONE, "password": PASSWORD}
    )
    tokens = registered.json()
    logged_in = await login(client, PHONE, PASSWORD)
    me = await client.get("/v1/users/me", headers=bearer(tokens))
    listing = await client.get("/v1/users", headers=auth_headers(owner))
    detail = await client.get(f"/v1/users/{owner.id}", headers=auth_headers(owner))

    assert listing.status_code == 200
    assert len(listing.json()) == 2
    for response in (registered, logged_in, me, listing, detail):
        assert "password_hash" not in response.text
        assert "argon2" not in response.text
        assert PASSWORD not in response.text


async def test_password_hash_absent_from_error_responses(client: AsyncClient) -> None:
    await register(client)

    wrong_password = await login(client, PHONE, "wrong-password")
    duplicate = await client.post(
        "/v1/auth/register", json={"name": "Ali", "phone": PHONE, "password": PASSWORD}
    )

    for response in (wrong_password, duplicate):
        assert "password_hash" not in response.text
        assert "argon2" not in response.text


async def test_openapi_lists_all_v1_paths(client: AsyncClient) -> None:
    response = await client.get("/openapi.json")

    assert response.status_code == 200
    paths = response.json()["paths"]
    expected = [
        "/v1/auth/register",
        "/v1/auth/login",
        "/v1/auth/refresh",
        "/v1/auth/logout",
        "/v1/auth/change-password",
        "/v1/users/me",
        "/v1/users",
        "/v1/users/{user_id}",
        "/v1/users/{user_id}/role",
        "/v1/users/{user_id}/gym",
        "/v1/users/{user_id}/trainer",
        "/v1/gyms",
        "/v1/gyms/{gym_id}",
        "/v1/trainers",
        "/v1/trainers/{trainer_id}",
    ]
    for path in expected:
        assert path in paths


async def test_health_returns_ok(client: AsyncClient) -> None:
    response = await client.get("/health")

    assert response.status_code == 200


async def test_unknown_route_uses_error_shape(client: AsyncClient) -> None:
    response = await client.get("/v1/does-not-exist")

    assert response.status_code == 404
    assert set(response.json()["detail"]) >= {"code", "message"}
