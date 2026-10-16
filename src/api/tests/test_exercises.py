from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Exercise, User

UserFactory = Callable[..., Awaitable[User]]
ExerciseFactory = Callable[..., Awaitable[Exercise]]
HeadersFactory = Callable[[User], dict[str, str]]

MUSCLES = [
    "chest",
    "shoulders",
    "biceps",
    "triceps",
    "forearms",
    "abs",
    "back",
    "traps",
    "glutes",
    "quads",
    "hamstrings",
    "calves",
]
VALID_EXERCISE = {
    "name": "Bench press",
    "muscle": "chest",
    "sets": "4x10",
    "tip": "Keep your back flat",
    "also": ["triceps", "shoulders"],
    "video": "https://youtu.be/abc",
    "level": "middle",
}
READ_ROLES = ["user", "barmen", "admin", "owner"]
NON_STAFF_ROLES = ["user", "barmen"]
STAFF_ROLES = ["admin", "owner"]


async def exercise_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Exercise)) or 0


@pytest.mark.parametrize("role", READ_ROLES)
async def test_every_signed_in_role_lists_exercises_sorted_by_name_then_id(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    await make_exercise(id="b", name="Squat")
    await make_exercise(id="c", name="Curl")
    await make_exercise(id="a", name="Curl")
    actor = await make_user(role=role)

    response = await client.get("/v1/exercises", headers=auth_headers(actor))

    assert response.status_code == 200
    assert [(item["name"], item["id"]) for item in response.json()] == [
        ("Curl", "a"),
        ("Curl", "c"),
        ("Squat", "b"),
    ]


@pytest.mark.parametrize("role", READ_ROLES)
async def test_every_signed_in_role_reads_one_exercise(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    exercise = await make_exercise(
        name="Row",
        muscle="back",
        sets="3x12",
        tip="Pull",
        also=["biceps"],
        video="v",
        created_by="coach",
        base="Barbell row",
    )
    actor = await make_user(role=role)

    response = await client.get(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == exercise.id
    assert body["name"] == "Row"
    assert body["muscle"] == "back"
    assert body["sets"] == "3x12"
    assert body["tip"] == "Pull"
    assert body["also"] == ["biceps"]
    assert body["video"] == "v"
    assert body["created_by"] == "coach"
    assert body["base"] == "Barbell row"
    assert body["created_at"]


async def test_exercise_read_endpoints_require_authentication(
    client: AsyncClient, make_exercise: ExerciseFactory
) -> None:
    exercise = await make_exercise()

    listed = await client.get("/v1/exercises")
    read = await client.get(f"/v1/exercises/{exercise.id}")

    assert listed.status_code == read.status_code == 401


async def test_exercise_write_endpoints_require_authentication(
    client: AsyncClient, make_exercise: ExerciseFactory, db_session: AsyncSession
) -> None:
    exercise = await make_exercise()

    created = await client.post("/v1/exercises", json=VALID_EXERCISE)
    updated = await client.put(f"/v1/exercises/{exercise.id}", json=VALID_EXERCISE)
    deleted = await client.delete(f"/v1/exercises/{exercise.id}")

    assert created.status_code == updated.status_code == deleted.status_code == 401
    assert await exercise_count(db_session) == 1


async def test_read_unknown_exercise_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user()

    response = await client.get("/v1/exercises/missing", headers=auth_headers(actor))

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "not_found"


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_creates_exercise_with_server_side_author_and_time(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    before = datetime.now(UTC) - timedelta(seconds=5)

    response = await client.post("/v1/exercises", json=VALID_EXERCISE, headers=auth_headers(actor))

    assert response.status_code == 201
    body = response.json()
    assert body["id"]
    assert body["created_by"] == actor.id
    assert body["base"] == ""
    assert body["level"] == "middle"
    for key, value in VALID_EXERCISE.items():
        assert body[key] == value
    stored = await db_session.get(Exercise, body["id"])
    assert stored is not None
    assert stored.created_by == actor.id
    assert before <= stored.created_at <= datetime.now(UTC) + timedelta(seconds=5)
    assert stored.base == ""


async def test_create_exercise_with_minimal_payload_defaults_rest(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.post(
        "/v1/exercises",
        json={"name": "Plank", "muscle": "abs"},
        headers=auth_headers(actor),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["sets"] == body["tip"] == body["video"] == body["level"] == ""
    assert body["also"] == []


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_create_exercise(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)

    response = await client.post("/v1/exercises", json=VALID_EXERCISE, headers=auth_headers(actor))

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await exercise_count(db_session) == 0


@pytest.mark.parametrize("field", ["created_by", "created_at", "id", "createdBy"])
async def test_create_exercise_rejects_forged_server_fields(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    field: str,
) -> None:
    actor = await make_user(role="admin")
    other = await make_user(role="admin")

    response = await client.post(
        "/v1/exercises",
        json={**VALID_EXERCISE, field: other.id},
        headers=auth_headers(actor),
    )

    assert response.status_code == 422
    assert await exercise_count(db_session) == 0


@pytest.mark.parametrize("field", ["created_by", "created_at", "base"])
async def test_update_exercise_rejects_immutable_fields(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    field: str,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()

    response = await client.put(
        f"/v1/exercises/{exercise.id}",
        json={**VALID_EXERCISE, field: "forged"},
        headers=auth_headers(actor),
    )

    assert response.status_code == 422


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_update_keeps_author_time_and_base(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    created_at = datetime(2024, 1, 2, 3, 4, 5, tzinfo=UTC)
    exercise = await make_exercise(
        created_by="first-author", created_at=created_at, base="Original", name="Old"
    )
    exercise_id = exercise.id

    response = await client.put(
        f"/v1/exercises/{exercise_id}", json=VALID_EXERCISE, headers=auth_headers(actor)
    )

    assert response.status_code == 200
    body = response.json()
    assert body["name"] == "Bench press"
    assert body["created_by"] == "first-author"
    assert body["base"] == "Original"
    db_session.expire_all()
    stored = await db_session.get(Exercise, exercise_id)
    assert stored is not None
    assert stored.created_by == "first-author"
    assert stored.created_at == created_at
    assert stored.base == "Original"
    assert stored.name == "Bench press"


async def test_another_staff_member_can_edit_exercise_without_taking_authorship(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    author = await make_user(role="admin")
    editor = await make_user(role="admin")
    exercise = await make_exercise(created_by=author.id)
    exercise_id = exercise.id

    response = await client.put(
        f"/v1/exercises/{exercise_id}", json=VALID_EXERCISE, headers=auth_headers(editor)
    )

    assert response.status_code == 200
    assert response.json()["created_by"] == author.id


async def test_update_is_full_replacement(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise(
        sets="5x5", tip="tip", also=["abs"], video="v", level="pro", muscle="chest"
    )
    exercise_id = exercise.id

    response = await client.put(
        f"/v1/exercises/{exercise_id}",
        json={"name": "Only", "muscle": "back"},
        headers=auth_headers(actor),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["muscle"] == "back"
    assert body["sets"] == body["tip"] == body["video"] == body["level"] == ""
    assert body["also"] == []
    db_session.expire_all()
    stored = await db_session.get(Exercise, exercise_id)
    assert stored is not None
    assert (stored.sets, stored.tip, stored.also, stored.video, stored.level) == (
        "",
        "",
        [],
        "",
        "",
    )


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_update_exercise(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    exercise = await make_exercise(name="Old")
    exercise_id = exercise.id

    response = await client.put(
        f"/v1/exercises/{exercise_id}", json=VALID_EXERCISE, headers=auth_headers(actor)
    )

    assert response.status_code == 403
    db_session.expire_all()
    stored = await db_session.get(Exercise, exercise_id)
    assert stored is not None
    assert stored.name == "Old"


async def test_update_unknown_exercise_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")

    response = await client.put(
        "/v1/exercises/missing", json=VALID_EXERCISE, headers=auth_headers(actor)
    )

    assert response.status_code == 404


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_deletes_exercise(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    exercise = await make_exercise()

    response = await client.delete(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert response.content == b""
    assert await exercise_count(db_session) == 0
    follow_up = await client.get(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))
    assert follow_up.status_code == 404


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_delete_exercise(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    exercise = await make_exercise()

    response = await client.delete(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))

    assert response.status_code == 403
    assert await exercise_count(db_session) == 1


async def test_delete_unknown_exercise_returns_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="owner")

    response = await client.delete("/v1/exercises/missing", headers=auth_headers(actor))

    assert response.status_code == 404


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_level_is_hidden_from_non_staff_on_read_and_list(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    exercise = await make_exercise(level="pro")
    actor = await make_user(role=role)

    one = await client.get(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))
    listed = await client.get("/v1/exercises", headers=auth_headers(actor))

    assert one.json()["level"] == ""
    assert [item["level"] for item in listed.json()] == [""]


@pytest.mark.parametrize("role", STAFF_ROLES)
@pytest.mark.parametrize("level", ["", "beginner", "middle", "pro"])
async def test_level_is_visible_to_staff_on_read_and_list(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    role: str,
    level: str,
) -> None:
    exercise = await make_exercise(level=level)
    actor = await make_user(role=role)

    one = await client.get(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))
    listed = await client.get("/v1/exercises", headers=auth_headers(actor))

    assert one.json()["level"] == level
    assert [item["level"] for item in listed.json()] == [level]


async def test_hiding_level_does_not_change_stored_value(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    exercise = await make_exercise(level="pro")
    exercise_id = exercise.id
    actor = await make_user(role="user")

    await client.get(f"/v1/exercises/{exercise_id}", headers=auth_headers(actor))

    db_session.expire_all()
    stored = await db_session.get(Exercise, exercise_id)
    assert stored is not None
    assert stored.level == "pro"


@pytest.mark.parametrize("muscle", MUSCLES)
async def test_every_muscle_group_is_accepted(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, muscle: str
) -> None:
    actor = await make_user(role="admin")

    response = await client.post(
        "/v1/exercises",
        json={"name": "X", "muscle": muscle, "also": []},
        headers=auth_headers(actor),
    )

    assert response.status_code == 201
    assert response.json()["muscle"] == muscle


INVALID_EXERCISES: list[dict[str, Any]] = [
    {},
    {"muscle": "chest"},
    {"name": "ok"},
    {"name": "", "muscle": "chest"},
    {"name": "   ", "muscle": "chest"},
    {"name": "n" * 81, "muscle": "chest"},
    {"name": "ok", "muscle": "legs"},
    {"name": "ok", "muscle": ""},
    {"name": "ok", "muscle": "Chest"},
    {"name": "ok", "muscle": "chest", "sets": "s" * 41},
    {"name": "ok", "muscle": "chest", "tip": "t" * 501},
    {"name": "ok", "muscle": "chest", "video": "v" * 301},
    {"name": "ok", "muscle": "chest", "also": MUSCLES[1:8]},
    {"name": "ok", "muscle": "chest", "also": ["legs"]},
    {"name": "ok", "muscle": "chest", "also": ["chest"]},
    {"name": "ok", "muscle": "chest", "also": ["abs", "chest"]},
    {"name": "ok", "muscle": "chest", "level": "expert"},
    {"name": "ok", "muscle": "chest", "level": "PRO"},
    {"name": "ok", "muscle": "chest", "sets": 5},
    {"name": "ok", "muscle": "chest", "role": "admin"},
]


@pytest.mark.parametrize("payload", INVALID_EXERCISES)
async def test_create_exercise_rejects_invalid_payload(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")

    response = await client.post("/v1/exercises", json=payload, headers=auth_headers(actor))

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await exercise_count(db_session) == 0


@pytest.mark.parametrize("payload", INVALID_EXERCISES)
async def test_update_exercise_rejects_invalid_payload(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()

    response = await client.put(
        f"/v1/exercises/{exercise.id}", json=payload, headers=auth_headers(actor)
    )

    assert response.status_code == 422


async def test_exercise_accepts_values_at_exact_limits(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    actor = await make_user(role="admin")
    payload = {
        "name": "n" * 80,
        "muscle": "chest",
        "sets": "s" * 40,
        "tip": "t" * 500,
        "also": MUSCLES[1:7],
        "video": "v" * 300,
        "level": "pro",
    }

    response = await client.post("/v1/exercises", json=payload, headers=auth_headers(actor))

    assert response.status_code == 201
    assert len(response.json()["also"]) == 6
