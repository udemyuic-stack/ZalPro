from collections.abc import Awaitable, Callable

import pytest
from httpx import AsyncClient

from zalpro_api.models import Gym, Trainer, User

UserFactory = Callable[..., Awaitable[User]]
TrainerFactory = Callable[..., Awaitable[Trainer]]
GymFactory = Callable[..., Awaitable[Gym]]
HeadersFactory = Callable[[User], dict[str, str]]


@pytest.fixture
async def owner(make_user: UserFactory) -> User:
    return await make_user(role="owner")


@pytest.fixture
async def trainer(make_user: UserFactory, make_trainer: TrainerFactory) -> User:
    user = await make_user(role="admin")
    await make_trainer(user)
    return user


@pytest.fixture
async def barmen(make_user: UserFactory) -> User:
    return await make_user(role="barmen")


@pytest.fixture
async def student(make_user: UserFactory, trainer: User) -> User:
    return await make_user(role="user", trainer_id=trainer.id)


@pytest.fixture
async def stranger(make_user: UserFactory) -> User:
    return await make_user(role="user")


async def list_ids(
    client: AsyncClient, actor: User, headers: HeadersFactory, params: dict | list
) -> set[str]:
    response = await client.get("/v1/users", params=params, headers=headers(actor))
    assert response.status_code == 200
    return {item["id"] for item in response.json()}


async def test_owner_filters_by_single_role(
    client: AsyncClient,
    owner: User,
    trainer: User,
    barmen: User,
    student: User,
    stranger: User,
    auth_headers: HeadersFactory,
) -> None:
    ids = await list_ids(client, owner, auth_headers, {"role": "user"})
    assert ids == {student.id, stranger.id}


async def test_owner_filters_by_multiple_roles(
    client: AsyncClient,
    owner: User,
    trainer: User,
    barmen: User,
    student: User,
    auth_headers: HeadersFactory,
) -> None:
    ids = await list_ids(client, owner, auth_headers, [("role", "admin"), ("role", "barmen")])
    assert ids == {trainer.id, barmen.id}


async def test_unknown_role_is_rejected(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get("/v1/users", params={"role": "boss"}, headers=auth_headers(owner))
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


async def test_owner_filters_by_trainer_id(
    client: AsyncClient,
    owner: User,
    trainer: User,
    student: User,
    stranger: User,
    auth_headers: HeadersFactory,
) -> None:
    ids = await list_ids(client, owner, auth_headers, {"trainer_id": trainer.id})
    assert ids == {student.id}


async def test_owner_filters_by_gym_id(
    client: AsyncClient,
    owner: User,
    make_gym: GymFactory,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    other_gym = await make_gym()
    inside = await make_user(role="user", gym_id=gym.id)
    await make_user(role="user", gym_id=other_gym.id)
    ids = await list_ids(client, owner, auth_headers, {"gym_id": gym.id})
    assert ids == {inside.id}


async def test_filters_combine_with_and(
    client: AsyncClient,
    owner: User,
    trainer: User,
    student: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    await make_user(role="barmen", trainer_id=trainer.id)
    ids = await list_ids(client, owner, auth_headers, {"role": "user", "trainer_id": trainer.id})
    assert ids == {student.id}


async def test_trainer_sees_only_own_students_even_with_role_filter(
    client: AsyncClient,
    trainer: User,
    student: User,
    stranger: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user(role="admin")
    await make_trainer(other)
    await make_user(role="user", trainer_id=other.id)
    ids = await list_ids(client, trainer, auth_headers, {"role": "user"})
    assert ids == {student.id}


async def test_trainer_cannot_list_other_trainers_students_via_trainer_id(
    client: AsyncClient,
    trainer: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user(role="admin")
    await make_trainer(other)
    await make_user(role="user", trainer_id=other.id)
    ids = await list_ids(client, trainer, auth_headers, {"trainer_id": other.id})
    assert ids == set()


async def test_barmen_sees_only_staff_directory(
    client: AsyncClient,
    owner: User,
    trainer: User,
    barmen: User,
    student: User,
    stranger: User,
    auth_headers: HeadersFactory,
) -> None:
    ids = await list_ids(client, barmen, auth_headers, {})
    assert ids == {owner.id, trainer.id, barmen.id}


async def test_barmen_cannot_list_students_with_role_filter(
    client: AsyncClient, barmen: User, student: User, auth_headers: HeadersFactory
) -> None:
    ids = await list_ids(client, barmen, auth_headers, {"role": "user"})
    assert ids == set()


async def test_barmen_staff_role_filter_works(
    client: AsyncClient, owner: User, barmen: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    ids = await list_ids(client, barmen, auth_headers, {"role": "admin"})
    assert ids == {trainer.id}


async def test_student_still_cannot_list(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get("/v1/users", headers=auth_headers(student))
    assert response.status_code == 403


async def test_limit_500_allows_large_pages(
    client: AsyncClient,
    owner: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    for _ in range(120):
        await make_user(role="user")
    response = await client.get("/v1/users", params={"limit": 500}, headers=auth_headers(owner))
    assert response.status_code == 200
    assert len(response.json()) == 121
