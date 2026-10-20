from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Gym, Plan, Trainer, User

UserFactory = Callable[..., Awaitable[User]]
TrainerFactory = Callable[..., Awaitable[Trainer]]
GymFactory = Callable[..., Awaitable[Gym]]
PlanFactory = Callable[..., Awaitable[Plan]]
HeadersFactory = Callable[[User], dict[str, str]]

FUTURE_DATE = "2030-01-01T00:00:00Z"
UNKNOWN_ID = "does-not-exist"


@pytest.fixture
async def owner(make_user: UserFactory) -> User:
    return await make_user(role="owner")


@pytest.fixture
async def trainer(make_user: UserFactory, make_trainer: TrainerFactory) -> User:
    user = await make_user(role="admin")
    await make_trainer(user)
    return user


@pytest.fixture
async def student(make_user: UserFactory, trainer: User) -> User:
    return await make_user(role="user", trainer_id=trainer.id)


@pytest.fixture
async def stranger(make_user: UserFactory) -> User:
    return await make_user(role="user")


async def reload_user(db_session: AsyncSession, user_id: str) -> User | None:
    return await db_session.get(User, user_id, populate_existing=True)


async def reload_trainer(db_session: AsyncSession, trainer_id: str) -> Trainer | None:
    return await db_session.get(Trainer, trainer_id, populate_existing=True)


def error_code(response: Any) -> str:
    return response.json()["detail"]["code"]


async def test_me_returns_current_user(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get("/v1/users/me", headers=auth_headers(student))

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == student.id
    assert body["phone"] == student.phone
    assert body["role"] == "user"
    assert body["trainer_id"] == student.trainer_id


async def test_me_without_token_is_unauthorized(client: AsyncClient) -> None:
    response = await client.get("/v1/users/me")

    assert response.status_code == 401
    assert error_code(response) == "unauthorized"


async def test_user_reads_self(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(f"/v1/users/{student.id}", headers=auth_headers(student))

    assert response.status_code == 200
    assert response.json()["id"] == student.id


async def test_user_cannot_read_other_user(
    client: AsyncClient, student: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(f"/v1/users/{stranger.id}", headers=auth_headers(student))

    assert response.status_code == 403


async def test_trainer_reads_own_student(
    client: AsyncClient, trainer: User, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(f"/v1/users/{student.id}", headers=auth_headers(trainer))

    assert response.status_code == 200
    assert response.json()["id"] == student.id


async def test_trainer_cannot_read_non_student(
    client: AsyncClient, trainer: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(f"/v1/users/{stranger.id}", headers=auth_headers(trainer))

    assert response.status_code == 403


async def test_other_trainer_cannot_read_student(
    client: AsyncClient,
    student: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    other_trainer = await make_user(role="admin")
    await make_trainer(other_trainer)

    response = await client.get(f"/v1/users/{student.id}", headers=auth_headers(other_trainer))

    assert response.status_code == 403


async def test_owner_reads_any_user(
    client: AsyncClient, owner: User, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(f"/v1/users/{student.id}", headers=auth_headers(owner))

    assert response.status_code == 200
    assert response.json()["id"] == student.id


async def test_owner_reading_unknown_user_is_not_found(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(f"/v1/users/{UNKNOWN_ID}", headers=auth_headers(owner))

    assert response.status_code == 404
    assert error_code(response) == "not_found"


async def test_read_user_without_token_is_unauthorized(client: AsyncClient, student: User) -> None:
    response = await client.get(f"/v1/users/{student.id}")

    assert response.status_code == 401


async def test_owner_lists_all_users(
    client: AsyncClient,
    owner: User,
    trainer: User,
    student: User,
    stranger: User,
    auth_headers: HeadersFactory,
) -> None:
    response = await client.get("/v1/users", headers=auth_headers(owner))

    assert response.status_code == 200
    ids = {item["id"] for item in response.json()}
    assert ids == {owner.id, trainer.id, student.id, stranger.id}


async def test_trainer_lists_only_own_students(
    client: AsyncClient,
    trainer: User,
    student: User,
    stranger: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    other_trainer = await make_user(role="admin")
    await make_trainer(other_trainer)
    other_student = await make_user(role="user", trainer_id=other_trainer.id)
    second_student = await make_user(role="user", trainer_id=trainer.id)

    response = await client.get("/v1/users", headers=auth_headers(trainer))

    assert response.status_code == 200
    ids = {item["id"] for item in response.json()}
    assert ids == {student.id, second_student.id}
    assert other_student.id not in ids
    assert stranger.id not in ids


async def test_student_cannot_list_users(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="user")

    response = await client.get("/v1/users", headers=auth_headers(actor))

    assert response.status_code == 403


async def test_list_users_without_token_is_unauthorized(client: AsyncClient) -> None:
    response = await client.get("/v1/users")

    assert response.status_code == 401


async def test_list_users_rejects_limit_above_maximum(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get("/v1/users", params={"limit": 501}, headers=auth_headers(owner))

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


@pytest.mark.parametrize("params", [{"limit": 0}, {"offset": -1}])
async def test_list_users_rejects_out_of_range_paging(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, params: dict[str, int]
) -> None:
    response = await client.get("/v1/users", params=params, headers=auth_headers(owner))

    assert response.status_code == 422


async def test_list_users_accepts_maximum_limit(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get("/v1/users", params={"limit": 500}, headers=auth_headers(owner))

    assert response.status_code == 200


async def test_list_users_limit_and_offset_page_through_results(
    client: AsyncClient,
    owner: User,
    trainer: User,
    student: User,
    stranger: User,
    auth_headers: HeadersFactory,
) -> None:
    headers = auth_headers(owner)
    everything = (await client.get("/v1/users", headers=headers)).json()
    first_page = (await client.get("/v1/users", params={"limit": 2}, headers=headers)).json()
    second_page = (
        await client.get("/v1/users", params={"limit": 2, "offset": 2}, headers=headers)
    ).json()
    beyond = (await client.get("/v1/users", params={"offset": 4}, headers=headers)).json()

    assert len(everything) == 4
    assert len(first_page) == 2
    assert len(second_page) == 2
    assert [item["id"] for item in first_page + second_page] == [item["id"] for item in everything]
    assert beyond == []


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("role", "owner"),
        ("plan_id", "plan-1"),
        ("program", {"day1": ["squat"]}),
        ("gym_id", "some-gym"),
        ("subscription_expires_at", FUTURE_DATE),
        ("home_workout_date", "2030-01-01"),
        ("trainer_id", "some-trainer"),
        ("plan_assigned_at", FUTURE_DATE),
    ],
)
async def test_user_cannot_patch_restricted_field(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    field: str,
    value: Any,
) -> None:
    original_trainer_id = student.trainer_id

    response = await client.patch(
        f"/v1/users/{student.id}", json={field: value}, headers=auth_headers(student)
    )

    assert response.status_code == 403
    assert error_code(response) == "field_not_allowed"
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.role == "user"
    assert stored.trainer_id == original_trainer_id
    assert stored.gym_id is None
    assert stored.plan_id is None
    assert stored.program == {}


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("name", "New Name"),
        ("goal", "mass"),
        ("gender", "male"),
        ("age", 30),
        ("height", 180.5),
        ("activity", 1.5),
        ("metabolism", "fast"),
    ],
)
async def test_user_can_patch_own_profile_field(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    field: str,
    value: Any,
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={field: value}, headers=auth_headers(student)
    )

    assert response.status_code == 200
    assert response.json()[field] == value
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert getattr(stored, field) == value


@pytest.mark.parametrize("days", [[2, 4, 6], [1, 3, 5], [1, 2, 3, 4, 5, 6, 7]])
async def test_user_can_patch_allowed_gym_days(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    days: list[int],
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={"gym_days": days}, headers=auth_headers(student)
    )

    assert response.status_code == 200
    assert response.json()["gym_days"] == days
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.gym_days == days


@pytest.mark.parametrize("days", [[1, 2, 3], [], [2, 4], [6, 4, 2]])
async def test_user_cannot_patch_invalid_gym_days(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, days: list[int]
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={"gym_days": days}, headers=auth_headers(student)
    )

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


async def test_user_can_set_weight_when_current_is_zero(
    client: AsyncClient,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.patch(
        f"/v1/users/{stranger.id}", json={"weight": 72.5}, headers=auth_headers(stranger)
    )

    assert response.status_code == 200
    assert response.json()["weight"] == 72.5
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.weight == 72.5


async def test_user_weight_is_locked_after_first_set(
    client: AsyncClient,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    headers = auth_headers(stranger)
    first = await client.patch(f"/v1/users/{stranger.id}", json={"weight": 72.5}, headers=headers)
    second = await client.patch(f"/v1/users/{stranger.id}", json={"weight": 80}, headers=headers)

    assert first.status_code == 200
    assert second.status_code == 403
    assert error_code(second) == "weight_locked"
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.weight == 72.5


async def test_user_with_existing_weight_cannot_change_it(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    weighed = await make_user(role="user", weight=70.0)

    response = await client.patch(
        f"/v1/users/{weighed.id}", json={"weight": 71}, headers=auth_headers(weighed)
    )

    assert response.status_code == 403
    assert error_code(response) == "weight_locked"


@pytest.mark.parametrize(
    ("field", "value"),
    [("last_weigh_in", FUTURE_DATE), ("phone", "998901112233"), ("unknown_field", 1)],
)
async def test_patch_rejects_fields_outside_schema(
    client: AsyncClient,
    owner: User,
    student: User,
    auth_headers: HeadersFactory,
    field: str,
    value: Any,
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={field: value}, headers=auth_headers(owner)
    )

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


@pytest.mark.parametrize("field", ["name", "role", "weight", "gym_days", "program"])
async def test_patch_rejects_explicit_null_for_required_fields(
    client: AsyncClient, owner: User, student: User, auth_headers: HeadersFactory, field: str
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={field: None}, headers=auth_headers(owner)
    )

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


async def test_patch_allows_explicit_null_for_nullable_fields(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    headers = auth_headers(student)
    await client.patch(f"/v1/users/{student.id}", json={"goal": "mass"}, headers=headers)

    response = await client.patch(f"/v1/users/{student.id}", json={"goal": None}, headers=headers)

    assert response.status_code == 200
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.goal is None


async def test_user_cannot_patch_another_user(
    client: AsyncClient,
    student: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.patch(
        f"/v1/users/{stranger.id}", json={"name": "Hacked"}, headers=auth_headers(student)
    )

    assert response.status_code == 403
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.name != "Hacked"


async def test_user_cannot_patch_another_user_with_empty_body(
    client: AsyncClient, student: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.patch(
        f"/v1/users/{stranger.id}", json={}, headers=auth_headers(student)
    )

    assert response.status_code == 403


async def test_patch_without_token_is_unauthorized(client: AsyncClient, student: User) -> None:
    response = await client.patch(f"/v1/users/{student.id}", json={"name": "X"})

    assert response.status_code == 401


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("plan_id", "plan-9"),
        ("goal", "cut"),
        ("program", {"day1": ["bench"]}),
        ("subscription_expires_at", FUTURE_DATE),
        ("plan_assigned_at", FUTURE_DATE),
        ("home_workout_date", "2030-05-05"),
        ("metabolism", "slow"),
        ("gender", "female"),
        ("age", 25),
        ("height", 170),
        ("activity", 2),
        ("name", "Renamed"),
    ],
)
async def test_trainer_can_patch_student_allowed_field(
    client: AsyncClient,
    trainer: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    make_plan: PlanFactory,
    field: str,
    value: Any,
) -> None:
    await make_plan(id="plan-9")
    response = await client.patch(
        f"/v1/users/{student.id}", json={field: value}, headers=auth_headers(trainer)
    )

    assert response.status_code == 200
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    if field in {"subscription_expires_at", "plan_assigned_at"}:
        assert getattr(stored, field) is not None
    else:
        assert getattr(stored, field) == value


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("role", "admin"),
        ("trainer_id", None),
        ("gym_id", "some-gym"),
        ("weight", 80),
        ("gym_days", [2, 4, 6]),
    ],
)
async def test_trainer_cannot_patch_student_restricted_field(
    client: AsyncClient,
    trainer: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    field: str,
    value: Any,
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={field: value}, headers=auth_headers(trainer)
    )

    assert response.status_code == 403
    assert error_code(response) == "field_not_allowed"
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.role == "user"
    assert stored.trainer_id == trainer.id
    assert stored.gym_id is None


async def test_trainer_cannot_patch_non_student(
    client: AsyncClient,
    trainer: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.patch(
        f"/v1/users/{stranger.id}", json={"plan_id": "plan-1"}, headers=auth_headers(trainer)
    )

    assert response.status_code == 403
    assert error_code(response) == "forbidden"
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.plan_id is None


async def test_other_trainer_cannot_patch_student(
    client: AsyncClient,
    student: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
) -> None:
    other_trainer = await make_user(role="admin")
    await make_trainer(other_trainer)

    response = await client.patch(
        f"/v1/users/{student.id}", json={"plan_id": "plan-1"}, headers=auth_headers(other_trainer)
    )

    assert response.status_code == 403


async def test_trainer_can_patch_own_profile_fields(
    client: AsyncClient, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.patch(
        f"/v1/users/{trainer.id}", json={"goal": "coach"}, headers=auth_headers(trainer)
    )

    assert response.status_code == 200
    assert response.json()["goal"] == "coach"


async def test_trainer_cannot_patch_own_role(
    client: AsyncClient, trainer: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    response = await client.patch(
        f"/v1/users/{trainer.id}", json={"role": "owner"}, headers=auth_headers(trainer)
    )

    assert response.status_code == 403
    stored = await reload_user(db_session, trainer.id)
    assert stored is not None
    assert stored.role == "admin"


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("plan_id", "plan-1"),
        ("program", {"x": 1}),
        ("name", "Owner Renamed"),
        ("weight", 99),
        ("subscription_expires_at", FUTURE_DATE),
        ("home_workout_date", "2031-02-03"),
        ("gym_days", [1, 3, 5]),
    ],
)
async def test_owner_can_patch_any_field(
    client: AsyncClient,
    owner: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    make_plan: PlanFactory,
    field: str,
    value: Any,
) -> None:
    await make_plan(id="plan-1")
    response = await client.patch(
        f"/v1/users/{student.id}", json={field: value}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    if field != "subscription_expires_at":
        assert getattr(stored, field) == value
    else:
        assert stored.subscription_expires_at is not None


async def test_owner_can_change_weight_after_it_was_set(
    client: AsyncClient, owner: User, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    weighed = await make_user(role="user", weight=70.0)

    response = await client.patch(
        f"/v1/users/{weighed.id}", json={"weight": 65}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["weight"] == 65


async def test_owner_patch_role_to_admin_creates_trainer_row(
    client: AsyncClient,
    owner: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.patch(
        f"/v1/users/{stranger.id}", json={"role": "admin"}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["role"] == "admin"
    assert await reload_trainer(db_session, stranger.id) is not None


async def test_owner_patching_own_role_to_different_value_conflicts(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    response = await client.patch(
        f"/v1/users/{owner.id}", json={"role": "admin"}, headers=auth_headers(owner)
    )

    assert response.status_code == 409
    assert error_code(response) == "cannot_change_own_role"
    stored = await reload_user(db_session, owner.id)
    assert stored is not None
    assert stored.role == "owner"


async def test_owner_patching_own_role_to_same_value_succeeds(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.patch(
        f"/v1/users/{owner.id}", json={"role": "owner"}, headers=auth_headers(owner)
    )

    assert response.status_code == 200


async def test_owner_patch_gym_id_sets_gym_and_mirrors_to_trainer_row(
    client: AsyncClient,
    owner: User,
    trainer: User,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym(name="Central")

    response = await client.patch(
        f"/v1/users/{trainer.id}", json={"gym_id": gym.id}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["gym_id"] == gym.id
    stored_trainer = await reload_trainer(db_session, trainer.id)
    assert stored_trainer is not None
    assert stored_trainer.gym_id == gym.id


async def test_owner_patch_gym_id_for_user_without_trainer_row(
    client: AsyncClient,
    owner: User,
    stranger: User,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()

    response = await client.patch(
        f"/v1/users/{stranger.id}", json={"gym_id": gym.id}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.gym_id == gym.id


async def test_owner_patch_unknown_gym_is_not_found(
    client: AsyncClient,
    owner: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.patch(
        f"/v1/users/{stranger.id}", json={"gym_id": UNKNOWN_ID}, headers=auth_headers(owner)
    )

    assert response.status_code == 404
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.gym_id is None


async def test_owner_patch_trainer_id_assigns_trainer(
    client: AsyncClient,
    owner: User,
    trainer: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.patch(
        f"/v1/users/{stranger.id}", json={"trainer_id": trainer.id}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.trainer_id == trainer.id


@pytest.mark.parametrize("actor_role", ["user", "admin", "barmen"])
async def test_only_owner_can_set_role(
    client: AsyncClient,
    make_user: UserFactory,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    actor_role: str,
) -> None:
    actor = await make_user(role=actor_role)

    response = await client.put(
        f"/v1/users/{stranger.id}/role", json={"role": "admin"}, headers=auth_headers(actor)
    )

    assert response.status_code == 403
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.role == "user"


async def test_owner_sets_role_admin_and_creates_trainer_row(
    client: AsyncClient,
    owner: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/role", json={"role": "admin"}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["role"] == "admin"
    created = await reload_trainer(db_session, stranger.id)
    assert created is not None
    assert created.accepting is True
    assert created.name == stranger.name


async def test_owner_demoting_trainer_removes_trainer_row_and_unassigns_students(
    client: AsyncClient,
    owner: User,
    trainer: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.put(
        f"/v1/users/{trainer.id}/role", json={"role": "user"}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["role"] == "user"
    assert await reload_trainer(db_session, trainer.id) is None
    stored_student = await reload_user(db_session, student.id)
    assert stored_student is not None
    assert stored_student.trainer_id is None


async def test_owner_sets_role_to_barmen_and_owner(
    client: AsyncClient, owner: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    barmen = await client.put(
        f"/v1/users/{stranger.id}/role", json={"role": "barmen"}, headers=auth_headers(owner)
    )
    promoted = await client.put(
        f"/v1/users/{stranger.id}/role", json={"role": "owner"}, headers=auth_headers(owner)
    )

    assert barmen.status_code == 200
    assert barmen.json()["role"] == "barmen"
    assert promoted.status_code == 200
    assert promoted.json()["role"] == "owner"


async def test_set_role_rejects_invalid_role(
    client: AsyncClient, owner: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/role", json={"role": "superuser"}, headers=auth_headers(owner)
    )

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


async def test_owner_cannot_change_own_role_via_role_endpoint(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    response = await client.put(
        f"/v1/users/{owner.id}/role", json={"role": "user"}, headers=auth_headers(owner)
    )

    assert response.status_code == 409
    assert error_code(response) == "cannot_change_own_role"
    stored = await reload_user(db_session, owner.id)
    assert stored is not None
    assert stored.role == "owner"


async def test_set_role_for_unknown_user_is_not_found(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/users/{UNKNOWN_ID}/role", json={"role": "admin"}, headers=auth_headers(owner)
    )

    assert response.status_code == 404


async def test_set_role_without_token_is_unauthorized(client: AsyncClient, stranger: User) -> None:
    response = await client.put(f"/v1/users/{stranger.id}/role", json={"role": "admin"})

    assert response.status_code == 401


@pytest.mark.parametrize("actor_role", ["user", "admin", "barmen"])
async def test_only_owner_can_set_gym(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    actor_role: str,
) -> None:
    actor = await make_user(role=actor_role)
    gym = await make_gym()

    response = await client.put(
        f"/v1/users/{stranger.id}/gym", json={"gym_id": gym.id}, headers=auth_headers(actor)
    )

    assert response.status_code == 403
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.gym_id is None


async def test_owner_sets_gym_for_user(
    client: AsyncClient,
    owner: User,
    stranger: User,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()

    response = await client.put(
        f"/v1/users/{stranger.id}/gym", json={"gym_id": gym.id}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["gym_id"] == gym.id
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.gym_id == gym.id


async def test_set_gym_unknown_gym_is_not_found(
    client: AsyncClient, owner: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/gym", json={"gym_id": UNKNOWN_ID}, headers=auth_headers(owner)
    )

    assert response.status_code == 404
    assert error_code(response) == "not_found"


async def test_set_gym_mirrors_to_trainer_row(
    client: AsyncClient,
    owner: User,
    trainer: User,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()

    response = await client.put(
        f"/v1/users/{trainer.id}/gym", json={"gym_id": gym.id}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    mirrored = await reload_trainer(db_session, trainer.id)
    assert mirrored is not None
    assert mirrored.gym_id == gym.id


async def test_set_gym_null_clears_user_and_trainer_gym(
    client: AsyncClient,
    owner: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()
    gym_trainer = await make_user(role="admin", gym_id=gym.id)
    await make_trainer(gym_trainer)

    response = await client.put(
        f"/v1/users/{gym_trainer.id}/gym", json={"gym_id": None}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["gym_id"] is None
    stored = await reload_user(db_session, gym_trainer.id)
    mirrored = await reload_trainer(db_session, gym_trainer.id)
    assert stored is not None
    assert stored.gym_id is None
    assert mirrored is not None
    assert mirrored.gym_id is None


async def test_set_gym_for_unknown_user_is_not_found(
    client: AsyncClient, owner: User, make_gym: GymFactory, auth_headers: HeadersFactory
) -> None:
    gym = await make_gym()

    response = await client.put(
        f"/v1/users/{UNKNOWN_ID}/gym", json={"gym_id": gym.id}, headers=auth_headers(owner)
    )

    assert response.status_code == 404


async def test_user_picks_accepting_trainer(
    client: AsyncClient,
    trainer: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/trainer",
        json={"trainer_id": trainer.id},
        headers=auth_headers(stranger),
    )

    assert response.status_code == 200
    assert response.json()["trainer_id"] == trainer.id
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.trainer_id == trainer.id


async def test_user_cannot_pick_trainer_who_is_not_accepting(
    client: AsyncClient,
    stranger: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    closed = await make_user(role="admin")
    await make_trainer(closed, accepting=False)

    response = await client.put(
        f"/v1/users/{stranger.id}/trainer",
        json={"trainer_id": closed.id},
        headers=auth_headers(stranger),
    )

    assert response.status_code == 403
    assert error_code(response) == "trainer_not_accepting"
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.trainer_id is None


async def test_user_picking_nonexistent_trainer_is_not_found(
    client: AsyncClient, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/trainer",
        json={"trainer_id": UNKNOWN_ID},
        headers=auth_headers(stranger),
    )

    assert response.status_code == 404


async def test_user_picking_non_trainer_user_id_is_not_found(
    client: AsyncClient, stranger: User, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/trainer",
        json={"trainer_id": student.id},
        headers=auth_headers(stranger),
    )

    assert response.status_code == 404


async def test_user_cannot_clear_own_trainer(
    client: AsyncClient,
    student: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.put(
        f"/v1/users/{student.id}/trainer", json={"trainer_id": None}, headers=auth_headers(student)
    )

    assert response.status_code == 403
    assert error_code(response) == "trainer_not_accepting"
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.trainer_id == trainer.id


async def test_user_cannot_set_trainer_of_another_user(
    client: AsyncClient,
    student: User,
    stranger: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/trainer",
        json={"trainer_id": trainer.id},
        headers=auth_headers(student),
    )

    assert response.status_code == 403
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.trainer_id is None


async def test_trainer_cannot_set_trainer_of_their_student(
    client: AsyncClient, trainer: User, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/users/{student.id}/trainer",
        json={"trainer_id": trainer.id},
        headers=auth_headers(trainer),
    )

    assert response.status_code == 403


async def test_owner_sets_trainer_even_when_not_accepting(
    client: AsyncClient,
    owner: User,
    stranger: User,
    make_user: UserFactory,
    make_trainer: TrainerFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    closed = await make_user(role="admin")
    await make_trainer(closed, accepting=False)

    response = await client.put(
        f"/v1/users/{stranger.id}/trainer",
        json={"trainer_id": closed.id},
        headers=auth_headers(owner),
    )

    assert response.status_code == 200
    stored = await reload_user(db_session, stranger.id)
    assert stored is not None
    assert stored.trainer_id == closed.id


async def test_owner_clears_trainer_with_null(
    client: AsyncClient,
    owner: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.put(
        f"/v1/users/{student.id}/trainer", json={"trainer_id": None}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    assert response.json()["trainer_id"] is None
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.trainer_id is None


async def test_owner_setting_nonexistent_trainer_is_not_found(
    client: AsyncClient, owner: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"/v1/users/{stranger.id}/trainer",
        json={"trainer_id": UNKNOWN_ID},
        headers=auth_headers(owner),
    )

    assert response.status_code == 404


async def test_owner_deletes_user(
    client: AsyncClient,
    owner: User,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.delete(f"/v1/users/{stranger.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert response.content == b""
    assert await reload_user(db_session, stranger.id) is None


@pytest.mark.parametrize("actor_role", ["user", "admin", "barmen"])
async def test_non_owner_cannot_delete_user(
    client: AsyncClient,
    make_user: UserFactory,
    stranger: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    actor_role: str,
) -> None:
    actor = await make_user(role=actor_role)

    response = await client.delete(f"/v1/users/{stranger.id}", headers=auth_headers(actor))

    assert response.status_code == 403
    assert await reload_user(db_session, stranger.id) is not None


async def test_trainer_cannot_delete_own_student(
    client: AsyncClient,
    trainer: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.delete(f"/v1/users/{student.id}", headers=auth_headers(trainer))

    assert response.status_code == 403
    assert await reload_user(db_session, student.id) is not None


async def test_owner_cannot_delete_self(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    response = await client.delete(f"/v1/users/{owner.id}", headers=auth_headers(owner))

    assert response.status_code == 409
    assert error_code(response) == "cannot_delete_self"
    assert await reload_user(db_session, owner.id) is not None


async def test_owner_deleting_unknown_user_is_not_found(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.delete(f"/v1/users/{UNKNOWN_ID}", headers=auth_headers(owner))

    assert response.status_code == 404


async def test_delete_without_token_is_unauthorized(client: AsyncClient, stranger: User) -> None:
    response = await client.delete(f"/v1/users/{stranger.id}")

    assert response.status_code == 401


async def test_deleting_trainer_unassigns_students_and_removes_trainer_row(
    client: AsyncClient,
    owner: User,
    trainer: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.delete(f"/v1/users/{trainer.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert await reload_user(db_session, trainer.id) is None
    assert await reload_trainer(db_session, trainer.id) is None
    stored_student = await reload_user(db_session, student.id)
    assert stored_student is not None
    assert stored_student.trainer_id is None


async def test_owner_creates_staff_user_with_default_admin_role_and_trainer_row(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    response = await client.post(
        "/v1/users",
        json={"name": "New Coach", "phone": "998901234567", "password": "password123"},
        headers=auth_headers(owner),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["role"] == "admin"
    assert body["phone"] == "998901234567"
    created = await reload_trainer(db_session, body["id"])
    assert created is not None
    assert created.name == "New Coach"


async def test_owner_creates_user_with_local_phone_normalized(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        "/v1/users",
        json={"name": "Local", "phone": "90 123 45 67", "password": "password123"},
        headers=auth_headers(owner),
    )

    assert response.status_code == 201
    assert response.json()["phone"] == "998901234567"


async def test_owner_creates_user_with_owner_role_without_trainer_row(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    response = await client.post(
        "/v1/users",
        json={
            "name": "Second Owner",
            "phone": "998901234567",
            "password": "password123",
            "role": "owner",
        },
        headers=auth_headers(owner),
    )

    assert response.status_code == 201
    assert response.json()["role"] == "owner"
    assert await reload_trainer(db_session, response.json()["id"]) is None


@pytest.mark.parametrize("role", ["user", "barmen"])
async def test_owner_creates_user_with_non_trainer_role(
    client: AsyncClient,
    owner: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    response = await client.post(
        "/v1/users",
        json={"name": "Staff", "phone": "998901234567", "password": "password123", "role": role},
        headers=auth_headers(owner),
    )

    assert response.status_code == 201
    assert response.json()["role"] == role
    assert await reload_trainer(db_session, response.json()["id"]) is None


async def test_owner_creates_user_with_gym(
    client: AsyncClient,
    owner: User,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()

    response = await client.post(
        "/v1/users",
        json={
            "name": "Coach",
            "phone": "998901234567",
            "password": "password123",
            "gym_id": gym.id,
        },
        headers=auth_headers(owner),
    )

    assert response.status_code == 201
    assert response.json()["gym_id"] == gym.id
    created = await reload_trainer(db_session, response.json()["id"])
    assert created is not None
    assert created.gym_id == gym.id


async def test_owner_creating_user_with_unknown_gym_is_not_found(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        "/v1/users",
        json={
            "name": "Coach",
            "phone": "998901234567",
            "password": "password123",
            "gym_id": UNKNOWN_ID,
        },
        headers=auth_headers(owner),
    )

    assert response.status_code == 404


@pytest.mark.parametrize("actor_role", ["user", "admin", "barmen"])
async def test_non_owner_cannot_create_user(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    actor_role: str,
) -> None:
    actor = await make_user(role=actor_role)

    response = await client.post(
        "/v1/users",
        json={"name": "X", "phone": "998901234567", "password": "password123"},
        headers=auth_headers(actor),
    )

    assert response.status_code == 403


async def test_create_user_without_token_is_unauthorized(client: AsyncClient) -> None:
    response = await client.post(
        "/v1/users", json={"name": "X", "phone": "998901234567", "password": "password123"}
    )

    assert response.status_code == 401


@pytest.mark.parametrize("role", ["user", "admin", "owner", "barmen"])
async def test_create_user_with_duplicate_phone_conflicts(
    client: AsyncClient, owner: User, stranger: User, auth_headers: HeadersFactory, role: str
) -> None:
    response = await client.post(
        "/v1/users",
        json={"name": "Dup", "phone": stranger.phone, "password": "password123", "role": role},
        headers=auth_headers(owner),
    )

    assert response.status_code == 409
    assert error_code(response) == "phone_taken"


async def test_create_user_rejects_short_password(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        "/v1/users",
        json={"name": "Short", "phone": "998901234567", "password": "short12"},
        headers=auth_headers(owner),
    )

    assert response.status_code == 422
    assert error_code(response) == "validation_error"


@pytest.mark.parametrize(
    "extra", [{"role": "superuser"}, {"unknown": 1}, {"phone": "123"}, {"name": "  "}]
)
async def test_create_user_rejects_invalid_payload(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, extra: dict[str, Any]
) -> None:
    payload = {"name": "Valid", "phone": "998901234567", "password": "password123", **extra}

    response = await client.post("/v1/users", json=payload, headers=auth_headers(owner))

    assert response.status_code == 422


async def test_responses_never_expose_password_material(
    client: AsyncClient,
    owner: User,
    trainer: User,
    student: User,
    auth_headers: HeadersFactory,
) -> None:
    headers = auth_headers(owner)
    created = await client.post(
        "/v1/users",
        json={"name": "Coach", "phone": "998901234567", "password": "password123"},
        headers=headers,
    )
    responses = [
        created,
        await client.get("/v1/users/me", headers=headers),
        await client.get(f"/v1/users/{student.id}", headers=headers),
        await client.get("/v1/users", headers=headers),
        await client.patch(f"/v1/users/{student.id}", json={"goal": "mass"}, headers=headers),
        await client.put(f"/v1/users/{student.id}/role", json={"role": "barmen"}, headers=headers),
    ]

    for response in responses:
        assert response.status_code in {200, 201}
        assert "password" not in response.text
        assert student.password_hash not in response.text


async def test_patch_unknown_plan_id_returns_plan_not_found(
    client: AsyncClient,
    owner: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={"plan_id": UNKNOWN_ID}, headers=auth_headers(owner)
    )

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "plan_not_found"
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.plan_id is None


async def test_trainer_patch_unknown_plan_id_returns_plan_not_found(
    client: AsyncClient, trainer: User, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.patch(
        f"/v1/users/{student.id}", json={"plan_id": UNKNOWN_ID}, headers=auth_headers(trainer)
    )

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "plan_not_found"


async def test_patch_plan_id_null_clears_plan(
    client: AsyncClient,
    owner: User,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    make_plan: PlanFactory,
) -> None:
    plan = await make_plan()
    await client.patch(
        f"/v1/users/{student.id}", json={"plan_id": plan.id}, headers=auth_headers(owner)
    )

    response = await client.patch(
        f"/v1/users/{student.id}", json={"plan_id": None}, headers=auth_headers(owner)
    )

    assert response.status_code == 200
    stored = await reload_user(db_session, student.id)
    assert stored is not None
    assert stored.plan_id is None


async def test_unauthorized_patch_with_unknown_plan_id_is_forbidden_not_not_found(
    client: AsyncClient, student: User, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    stranger = await make_user()

    response = await client.patch(
        f"/v1/users/{student.id}", json={"plan_id": UNKNOWN_ID}, headers=auth_headers(stranger)
    )

    assert response.status_code == 403
