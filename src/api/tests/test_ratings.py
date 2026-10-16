from collections.abc import Awaitable, Callable

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Rating, Trainer, User

UserFactory = Callable[..., Awaitable[User]]
TrainerFactory = Callable[..., Awaitable[Trainer]]
HeadersFactory = Callable[[User], dict[str, str]]


@pytest.fixture
async def owner(make_user: UserFactory) -> User:
    return await make_user(role="owner")


@pytest.fixture
async def trainer(make_user: UserFactory, make_trainer: TrainerFactory) -> User:
    user = await make_user(role="admin")
    await make_trainer(user)
    return user


async def test_owner_saves_rating(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/ratings/{trainer.id}",
        json={"stars": 4, "comment": "Yaxshi"},
        headers=auth_headers(owner),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["trainer_id"] == trainer.id
    assert body["stars"] == 4
    assert body["comment"] == "Yaxshi"
    assert body["updated_at"]


async def test_second_put_replaces_rating_and_keeps_single_row(
    client: AsyncClient,
    owner: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    await client.put(
        f"/v1/ratings/{trainer.id}", json={"stars": 2, "comment": "a"}, headers=auth_headers(owner)
    )

    response = await client.put(
        f"/v1/ratings/{trainer.id}", json={"stars": 5}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["stars"] == 5
    assert response.json()["comment"] == ""
    assert await db_session.scalar(select(func.count()).select_from(Rating)) == 1


async def test_owner_lists_ratings(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    await client.put(f"/v1/ratings/{trainer.id}", json={"stars": 3}, headers=auth_headers(owner))

    response = await client.get("/v1/ratings", headers=auth_headers(owner))

    assert response.status_code == 200
    assert [item["trainer_id"] for item in response.json()] == [trainer.id]


async def test_owner_deletes_rating(
    client: AsyncClient,
    owner: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    await client.put(f"/v1/ratings/{trainer.id}", json={"stars": 3}, headers=auth_headers(owner))

    response = await client.delete(f"/v1/ratings/{trainer.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert await db_session.scalar(select(func.count()).select_from(Rating)) == 0


@pytest.mark.parametrize("stars", [0, 6, -1])
async def test_stars_out_of_range_rejected(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory, stars: int
) -> None:
    response = await client.put(
        f"/v1/ratings/{trainer.id}", json={"stars": stars}, headers=auth_headers(owner)
    )

    assert response.status_code == 422


async def test_non_integer_stars_rejected(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/ratings/{trainer.id}", json={"stars": 4.5}, headers=auth_headers(owner)
    )

    assert response.status_code == 422


async def test_long_comment_rejected(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/ratings/{trainer.id}",
        json={"stars": 3, "comment": "x" * 501},
        headers=auth_headers(owner),
    )

    assert response.status_code == 422


async def test_comment_of_500_chars_accepted(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/ratings/{trainer.id}",
        json={"stars": 3, "comment": "x" * 500},
        headers=auth_headers(owner),
    )

    assert response.status_code == 200


async def test_unknown_fields_rejected(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/ratings/{trainer.id}",
        json={"stars": 3, "updated_at": "2030-01-01T00:00:00Z"},
        headers=auth_headers(owner),
    )

    assert response.status_code == 422


async def test_rating_unknown_trainer_returns_404(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        "/v1/ratings/missing", json={"stars": 3}, headers=auth_headers(owner)
    )

    assert response.status_code == 404


@pytest.mark.parametrize("role", ["admin", "user", "barmen"])
async def test_non_owner_cannot_use_ratings(
    client: AsyncClient,
    trainer: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    actor = trainer if role == "admin" else await make_user(role=role)
    headers = auth_headers(actor)

    assert (await client.get("/v1/ratings", headers=headers)).status_code == 403
    assert (
        await client.put(f"/v1/ratings/{trainer.id}", json={"stars": 5}, headers=headers)
    ).status_code == 403
    assert (await client.delete(f"/v1/ratings/{trainer.id}", headers=headers)).status_code == 403


async def test_trainer_cannot_see_own_rating(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    await client.put(f"/v1/ratings/{trainer.id}", json={"stars": 1}, headers=auth_headers(owner))

    response = await client.get("/v1/ratings", headers=auth_headers(trainer))

    assert response.status_code == 403


async def test_ratings_require_authentication(client: AsyncClient, trainer: User) -> None:
    assert (await client.get("/v1/ratings")).status_code == 401
    assert (await client.put(f"/v1/ratings/{trainer.id}", json={"stars": 3})).status_code == 401
    assert (await client.delete(f"/v1/ratings/{trainer.id}")).status_code == 401


async def test_deleting_user_removes_rating(
    client: AsyncClient,
    owner: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    await client.put(f"/v1/ratings/{trainer.id}", json={"stars": 3}, headers=auth_headers(owner))

    response = await client.delete(f"/v1/users/{trainer.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert await db_session.scalar(select(func.count()).select_from(Rating)) == 0
