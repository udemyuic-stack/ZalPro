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


async def trainer_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Trainer)) or 0


async def reload_trainer(db_session: AsyncSession, trainer_id: str) -> Trainer:
    db_session.expire_all()
    trainer = await db_session.get(Trainer, trainer_id)
    assert trainer is not None
    return trainer


async def reload_user(db_session: AsyncSession, user_id: str) -> User:
    db_session.expire_all()
    user = await db_session.get(User, user_id)
    assert user is not None
    return user


async def test_trainer_list_requires_authentication(client: AsyncClient) -> None:
    response = await client.get("/v1/trainers")

    assert response.status_code == 401


@pytest.mark.parametrize("role", ["user", "admin", "barmen", "owner"])
async def test_every_signed_in_role_lists_trainers(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    coach_b = await make_user(role="admin", name="Bobur")
    coach_a = await make_user(role="admin", name="Anvar")
    await make_trainer(coach_b)
    await make_trainer(coach_a)
    actor = await make_user(role=role)

    response = await client.get("/v1/trainers", headers=auth_headers(actor))

    assert response.status_code == 200
    body = response.json()
    assert [item["name"] for item in body] == ["Anvar", "Bobur"]
    assert set(body[0]) == {"id", "name", "bio", "accepting", "gym_id"}


async def test_trainer_updates_own_entry(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    coach = await make_user(role="admin", name="Old name")
    await make_trainer(coach)
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}",
        json={"name": "New name", "bio": "Ten years", "accepting": False},
        headers=auth_headers(coach),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "New name"
    assert body["bio"] == "Ten years"
    assert body["accepting"] is False
    stored = await reload_trainer(db_session, coach_id)
    assert (stored.name, stored.bio, stored.accepting) == ("New name", "Ten years", False)


async def test_trainer_partial_update_keeps_other_fields(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach, name="Keep", bio="Keep bio")
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"accepting": False}, headers=auth_headers(coach)
    )

    assert response.status_code == 200
    stored = await reload_trainer(db_session, coach_id)
    assert (stored.name, stored.bio, stored.accepting) == ("Keep", "Keep bio", False)


async def test_trainer_can_clear_bio(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach, bio="something")

    response = await client.put(
        f"/v1/trainers/{coach.id}", json={"bio": ""}, headers=auth_headers(coach)
    )

    assert response.status_code == 200
    assert response.json()["bio"] == ""


async def test_other_trainer_cannot_update_entry(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    coach = await make_user(role="admin")
    intruder = await make_user(role="admin")
    await make_trainer(coach, name="Original")
    await make_trainer(intruder)
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"name": "Hacked"}, headers=auth_headers(intruder)
    )

    assert response.status_code == 403
    assert (await reload_trainer(db_session, coach_id)).name == "Original"


@pytest.mark.parametrize("role", ["user", "barmen"])
async def test_non_trainer_roles_cannot_update_entry(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach, name="Original")
    actor = await make_user(role=role)
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"name": "Hacked"}, headers=auth_headers(actor)
    )

    assert response.status_code == 403
    assert (await reload_trainer(db_session, coach_id)).name == "Original"


async def test_plain_user_cannot_update_entry_with_same_id(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    user = await make_user(role="user")
    await make_trainer(user)

    response = await client.put(
        f"/v1/trainers/{user.id}", json={"name": "Self"}, headers=auth_headers(user)
    )

    assert response.status_code == 403


async def test_trainer_update_requires_authentication(
    client: AsyncClient, make_user: UserFactory, make_trainer: TrainerFactory
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.put(f"/v1/trainers/{coach.id}", json={"name": "Anon"})

    assert response.status_code == 401


async def test_owner_cannot_change_trainer_name(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    coach = await make_user(role="admin")
    await make_trainer(coach, name="Original")
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"name": "Renamed"}, headers=auth_headers(owner)
    )

    assert response.status_code == 403
    assert (await reload_trainer(db_session, coach_id)).name == "Original"


@pytest.mark.parametrize("payload", [{"bio": "x"}, {"accepting": False}])
async def test_owner_cannot_change_other_trainer_fields(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    owner = await make_user(role="owner")
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.put(
        f"/v1/trainers/{coach.id}", json=payload, headers=auth_headers(owner)
    )

    assert response.status_code == 403


async def test_owner_cannot_mix_gym_id_with_name(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()
    coach = await make_user(role="admin")
    await make_trainer(coach, name="Original")
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}",
        json={"name": "Renamed", "gym_id": gym.id},
        headers=auth_headers(owner),
    )

    assert response.status_code == 403
    assert (await reload_trainer(db_session, coach_id)).gym_id is None
    assert (await reload_user(db_session, coach_id)).gym_id is None


async def test_owner_sets_gym_id_on_both_user_and_trainer(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()
    coach = await make_user(role="admin")
    await make_trainer(coach)
    coach_id = coach.id
    gym_id = gym.id

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"gym_id": gym_id}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["gym_id"] == gym_id
    db_session.expire_all()
    stored_user = await db_session.get(User, coach_id)
    stored_trainer = await db_session.get(Trainer, coach_id)
    assert stored_user is not None
    assert stored_trainer is not None
    assert stored_user.gym_id == gym_id
    assert stored_trainer.gym_id == gym_id


async def test_owner_clears_gym_id_on_both_user_and_trainer(
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

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"gym_id": None}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert (await reload_user(db_session, coach_id)).gym_id is None
    assert (await reload_trainer(db_session, coach_id)).gym_id is None


async def test_owner_gym_id_update_with_unknown_gym_returns_404(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    coach = await make_user(role="admin")
    await make_trainer(coach)
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"gym_id": "missing"}, headers=auth_headers(owner)
    )

    assert response.status_code == 404
    assert (await reload_user(db_session, coach_id)).gym_id is None
    assert (await reload_trainer(db_session, coach_id)).gym_id is None


async def test_owner_gym_id_update_for_missing_trainer_returns_404(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()

    response = await client.put(
        "/v1/trainers/missing", json={"gym_id": gym.id}, headers=auth_headers(owner)
    )

    assert response.status_code == 404


async def test_trainer_update_for_user_without_entry_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    coach = await make_user(role="admin")

    response = await client.put(
        f"/v1/trainers/{coach.id}", json={"name": "Ghost"}, headers=auth_headers(coach)
    )

    assert response.status_code == 404


async def test_trainer_gym_id_in_own_update_is_ignored(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    own_gym = await make_gym(name="Own")
    other_gym = await make_gym(name="Other")
    coach = await make_user(role="admin", gym_id=own_gym.id)
    await make_trainer(coach)
    coach_id = coach.id
    own_gym_id = own_gym.id

    response = await client.put(
        f"/v1/trainers/{coach_id}",
        json={"name": "Renamed", "gym_id": other_gym.id},
        headers=auth_headers(coach),
    )

    assert response.status_code == 200
    stored_trainer = await reload_trainer(db_session, coach_id)
    stored_user = await db_session.get(User, coach_id)
    assert stored_user is not None
    assert stored_trainer.name == "Renamed"
    assert stored_trainer.gym_id == stored_user.gym_id == own_gym_id


async def test_trainer_gym_id_in_own_update_is_ignored_when_user_has_no_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()
    coach = await make_user(role="admin")
    await make_trainer(coach)
    coach_id = coach.id

    response = await client.put(
        f"/v1/trainers/{coach_id}", json={"gym_id": gym.id}, headers=auth_headers(coach)
    )

    assert response.status_code == 200
    assert response.json()["gym_id"] is None
    assert (await reload_trainer(db_session, coach_id)).gym_id is None
    assert (await reload_user(db_session, coach_id)).gym_id is None


async def test_trainer_update_rejects_extra_field(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.put(
        f"/v1/trainers/{coach.id}", json={"id": "other"}, headers=auth_headers(coach)
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "payload",
    [
        {"name": "n" * 61},
        {"name": ""},
        {"bio": "b" * 301},
        {"name": None},
        {"bio": None},
        {"accepting": None},
    ],
)
async def test_trainer_update_rejects_invalid_values(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.put(
        f"/v1/trainers/{coach.id}", json=payload, headers=auth_headers(coach)
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


async def test_trainer_update_accepts_values_at_exact_limits(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.put(
        f"/v1/trainers/{coach.id}",
        json={"name": "n" * 60, "bio": "b" * 300},
        headers=auth_headers(coach),
    )

    assert response.status_code == 200


async def test_trainer_creates_own_entry_with_gym_from_user(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()
    coach = await make_user(role="admin", name="Coach", gym_id=gym.id)
    coach_id = coach.id
    gym_id = gym.id

    response = await client.post(
        f"/v1/trainers/{coach_id}",
        json={"name": "Public name", "bio": "Bio", "accepting": False},
        headers=auth_headers(coach),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["id"] == coach_id
    assert body["gym_id"] == gym_id
    stored = await reload_trainer(db_session, coach_id)
    assert (stored.name, stored.bio, stored.accepting, stored.gym_id) == (
        "Public name",
        "Bio",
        False,
        gym_id,
    )


async def test_trainer_create_defaults_name_from_user(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    coach = await make_user(role="admin", name="Coach Name")

    response = await client.post(f"/v1/trainers/{coach.id}", json={}, headers=auth_headers(coach))

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Coach Name"
    assert body["bio"] == ""
    assert body["accepting"] is True
    assert body["gym_id"] is None


async def test_owner_creates_trainer_entry_for_admin_user(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    gym = await make_gym()
    coach = await make_user(role="admin", gym_id=gym.id)
    coach_id = coach.id
    gym_id = gym.id

    response = await client.post(
        f"/v1/trainers/{coach_id}", json={"name": "By owner"}, headers=auth_headers(owner)
    )

    assert response.status_code == 201
    assert response.json()["gym_id"] == gym_id
    assert (await reload_trainer(db_session, coach_id)).name == "By owner"


async def test_trainer_create_rejects_gym_id_from_client(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()
    coach = await make_user(role="admin")

    response = await client.post(
        f"/v1/trainers/{coach.id}", json={"gym_id": gym.id}, headers=auth_headers(coach)
    )

    assert response.status_code == 422
    assert await trainer_count(db_session) == 0


async def test_other_user_cannot_create_trainer_entry(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    coach = await make_user(role="admin")
    other_admin = await make_user(role="admin")

    response = await client.post(
        f"/v1/trainers/{coach.id}", json={}, headers=auth_headers(other_admin)
    )

    assert response.status_code == 403
    assert await trainer_count(db_session) == 0


@pytest.mark.parametrize("role", ["user", "barmen"])
async def test_plain_roles_cannot_create_trainer_entry(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    coach = await make_user(role="admin")
    actor = await make_user(role=role)

    response = await client.post(f"/v1/trainers/{coach.id}", json={}, headers=auth_headers(actor))

    assert response.status_code == 403
    assert await trainer_count(db_session) == 0


async def test_user_cannot_create_own_trainer_entry(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    user = await make_user(role="user")

    response = await client.post(f"/v1/trainers/{user.id}", json={}, headers=auth_headers(user))

    assert response.status_code == 403
    assert await trainer_count(db_session) == 0


async def test_trainer_create_requires_authentication(
    client: AsyncClient, make_user: UserFactory
) -> None:
    coach = await make_user(role="admin")

    response = await client.post(f"/v1/trainers/{coach.id}", json={})

    assert response.status_code == 401


async def test_trainer_create_rejects_duplicate(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.post(f"/v1/trainers/{coach.id}", json={}, headers=auth_headers(coach))

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "trainer_exists"


async def test_owner_cannot_create_trainer_entry_for_non_admin_user(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    member = await make_user(role="user")

    response = await client.post(f"/v1/trainers/{member.id}", json={}, headers=auth_headers(owner))

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "not_a_trainer"
    assert await trainer_count(db_session) == 0


async def test_owner_create_trainer_entry_for_unknown_user_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.post("/v1/trainers/missing", json={}, headers=auth_headers(owner))

    assert response.status_code == 404


@pytest.mark.parametrize(
    "payload", [{"name": "n" * 61}, {"name": ""}, {"bio": "b" * 301}, {"accepting": "maybe"}]
)
async def test_trainer_create_rejects_invalid_values(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    payload: dict[str, Any],
) -> None:
    coach = await make_user(role="admin")

    response = await client.post(
        f"/v1/trainers/{coach.id}", json=payload, headers=auth_headers(coach)
    )

    assert response.status_code == 422
    assert await trainer_count(db_session) == 0


async def test_owner_deletes_trainer_entry(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    coach = await make_user(role="admin")
    await make_trainer(coach)
    coach_id = coach.id

    response = await client.delete(f"/v1/trainers/{coach_id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert response.content == b""
    assert await trainer_count(db_session) == 0
    assert (await reload_user(db_session, coach_id)).role == "admin"


async def test_trainer_cannot_delete_own_entry(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.delete(f"/v1/trainers/{coach.id}", headers=auth_headers(coach))

    assert response.status_code == 403
    assert await trainer_count(db_session) == 1


@pytest.mark.parametrize("role", ["user", "admin", "barmen"])
async def test_non_owner_cannot_delete_trainer_entry(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)
    actor = await make_user(role=role)

    response = await client.delete(f"/v1/trainers/{coach.id}", headers=auth_headers(actor))

    assert response.status_code == 403
    assert await trainer_count(db_session) == 1


async def test_trainer_delete_requires_authentication(
    client: AsyncClient, make_user: UserFactory, make_trainer: TrainerFactory
) -> None:
    coach = await make_user(role="admin")
    await make_trainer(coach)

    response = await client.delete(f"/v1/trainers/{coach.id}")

    assert response.status_code == 401


async def test_owner_delete_unknown_trainer_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.delete("/v1/trainers/missing", headers=auth_headers(owner))

    assert response.status_code == 404
