from collections.abc import Awaitable, Callable

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import PushToken, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

URL = "/v1/users/me/push-tokens"


async def stored(db_session: AsyncSession) -> list[PushToken]:
    statement = select(PushToken).execution_options(populate_existing=True)
    return list((await db_session.scalars(statement)).all())


@pytest.mark.parametrize("role", ["user", "admin", "owner", "barmen"])
async def test_every_role_registers_own_token(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post(
        URL, json={"token": "abc", "platform": "android"}, headers=auth_headers(actor)
    )

    assert response.status_code == 204
    rows = await stored(db_session)
    assert [(row.user_id, row.token, row.platform) for row in rows] == [
        (actor.id, "abc", "android")
    ]


async def test_registering_same_token_twice_is_idempotent(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user()
    body = {"token": "abc", "platform": "web"}

    first = await client.post(URL, json=body, headers=auth_headers(actor))
    second = await client.post(URL, json=body, headers=auth_headers(actor))

    assert first.status_code == second.status_code == 204
    assert len(await stored(db_session)) == 1


async def test_token_moves_to_new_account_on_same_device(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    first = await make_user()
    second = await make_user()
    body = {"token": "device-1", "platform": "android"}

    await client.post(URL, json=body, headers=auth_headers(first))
    await client.post(URL, json=body, headers=auth_headers(second))

    rows = await stored(db_session)
    assert [row.user_id for row in rows] == [second.id]


async def test_delete_removes_own_token(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user()
    await client.post(URL, json={"token": "abc", "platform": "ios"}, headers=auth_headers(actor))

    response = await client.delete(f"{URL}/abc", headers=auth_headers(actor))

    assert response.status_code == 204
    assert await stored(db_session) == []


async def test_user_cannot_delete_another_users_token(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner_of_token = await make_user()
    other = await make_user()
    await client.post(
        URL, json={"token": "abc", "platform": "ios"}, headers=auth_headers(owner_of_token)
    )

    response = await client.delete(f"{URL}/abc", headers=auth_headers(other))

    assert response.status_code == 204
    assert len(await stored(db_session)) == 1


async def test_delete_unknown_token_is_idempotent(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user()

    response = await client.delete(f"{URL}/missing", headers=auth_headers(actor))

    assert response.status_code == 204


@pytest.mark.parametrize(
    "body",
    [
        {"token": "", "platform": "android"},
        {"token": "x" * 4097, "platform": "android"},
        {"token": "abc", "platform": "windows"},
        {"token": "abc"},
        {"token": "abc", "platform": "android", "user_id": "x"},
    ],
)
async def test_invalid_body_is_rejected(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    body: dict[str, str],
) -> None:
    actor = await make_user()

    response = await client.post(URL, json=body, headers=auth_headers(actor))

    assert response.status_code == 422


async def test_anonymous_cannot_register(client: AsyncClient) -> None:
    response = await client.post(URL, json={"token": "abc", "platform": "android"})

    assert response.status_code == 401


async def test_deleting_user_cascades_tokens(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    member = await make_user()
    await client.post(
        URL, json={"token": "abc", "platform": "android"}, headers=auth_headers(member)
    )

    response = await client.delete(f"/v1/users/{member.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    count = await db_session.scalar(select(func.count()).select_from(PushToken))
    assert count == 0
