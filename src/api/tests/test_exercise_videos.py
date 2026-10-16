import uuid
from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import FakeStorage
from zalpro_api.models import Exercise, User
from zalpro_api.models.exercise import MAX_VIDEO_BYTES
from zalpro_api.services.storage import UnconfiguredStorage

UserFactory = Callable[..., Awaitable[User]]
ExerciseFactory = Callable[..., Awaitable[Exercise]]
HeadersFactory = Callable[[User], dict[str, str]]

STAFF_ROLES = ["admin", "owner"]
NON_STAFF_ROLES = ["user", "barmen"]
ALL_ROLES = ["user", "barmen", "admin", "owner"]


def video_url(exercise: Exercise) -> str:
    return f"/v1/exercises/{exercise.id}/video"


def new_key(exercise: Exercise) -> str:
    return f"videos/{exercise.id}/{uuid.uuid4().hex}"


async def refresh(db_session: AsyncSession, exercise: Exercise) -> Exercise:
    await db_session.refresh(exercise)
    return exercise


@pytest.mark.parametrize("role", STAFF_ROLES)
async def test_staff_gets_upload_url_for_exercise_prefix(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    exercise = await make_exercise()

    response = await client.post(
        f"{video_url(exercise)}/upload-url", headers=auth_headers(actor), json={"size": 5_000_000}
    )

    assert response.status_code == 201
    body = response.json()
    assert body["key"].startswith(f"videos/{exercise.id}/")
    assert body["upload_url"].startswith("https://storage.test/put/")
    assert body["expires_in"] == 3600
    assert storage.put_calls == [(body["key"], 5_000_000)]
    assert (await refresh(db_session, exercise)).video_key is None


@pytest.mark.parametrize("size", [0, -1, MAX_VIDEO_BYTES + 1, "10", 1.5, None])
async def test_upload_url_rejects_bad_size(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    size: Any,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()

    response = await client.post(
        f"{video_url(exercise)}/upload-url", headers=auth_headers(actor), json={"size": size}
    )

    assert response.status_code == 422
    assert storage.put_calls == []


async def test_upload_url_accepts_max_size(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()

    response = await client.post(
        f"{video_url(exercise)}/upload-url",
        headers=auth_headers(actor),
        json={"size": MAX_VIDEO_BYTES},
    )

    assert response.status_code == 201


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_manage_video(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    actor = await make_user(role=role)
    exercise = await make_exercise(video_key=new_key(Exercise(id="x")))
    headers = auth_headers(actor)
    key = new_key(exercise)

    responses = [
        await client.post(f"{video_url(exercise)}/upload-url", headers=headers, json={"size": 5}),
        await client.put(video_url(exercise), headers=headers, json={"key": key}),
        await client.delete(video_url(exercise), headers=headers),
    ]

    assert [response.status_code for response in responses] == [403, 403, 403]
    assert storage.put_calls == []
    assert storage.deleted == []


async def test_unknown_exercise_is_404_on_every_video_endpoint(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    headers = auth_headers(actor)
    url = "/v1/exercises/missing/video"

    responses = [
        await client.post(f"{url}/upload-url", headers=headers, json={"size": 5}),
        await client.put(url, headers=headers, json={"key": "videos/missing/" + "a" * 32}),
        await client.get(url, headers=headers),
        await client.delete(url, headers=headers),
    ]

    assert [response.status_code for response in responses] == [404, 404, 404, 404]


async def test_endpoints_require_login(
    client: AsyncClient, storage: FakeStorage, make_exercise: ExerciseFactory
) -> None:
    exercise = await make_exercise()

    responses = [
        await client.post(f"{video_url(exercise)}/upload-url", json={"size": 5}),
        await client.put(video_url(exercise), json={"key": new_key(exercise)}),
        await client.get(video_url(exercise)),
        await client.delete(video_url(exercise)),
    ]

    assert [response.status_code for response in responses] == [401, 401, 401, 401]


async def test_upload_url_with_unconfigured_storage_is_503(
    client: AsyncClient,
    app: Any,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    original = app.state.storage
    app.state.storage = UnconfiguredStorage()
    try:
        response = await client.post(
            f"{video_url(exercise)}/upload-url", headers=auth_headers(actor), json={"size": 5}
        )
    finally:
        app.state.storage = original

    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "storage_unavailable"


async def test_confirm_sets_video_key_and_has_video(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    key = new_key(exercise)
    storage.objects[key] = 10_000_000

    response = await client.put(video_url(exercise), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 200
    body = response.json()
    assert body["has_video"] is True
    assert "video_key" not in body
    assert key not in response.text
    assert (await refresh(db_session, exercise)).video_key == key


async def test_confirm_without_uploaded_object_is_422(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()

    response = await client.put(
        video_url(exercise), headers=auth_headers(actor), json={"key": new_key(exercise)}
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "video_not_uploaded"
    assert (await refresh(db_session, exercise)).video_key is None


@pytest.mark.parametrize(
    "key",
    [
        "videos/other/" + "a" * 32,
        "images/{id}/" + "a" * 32,
        "videos/{id}/short",
        "videos/{id}/" + "A" * 32,
        "videos/{id}/" + "a" * 32 + "/extra",
        "videos/{id}/../other/" + "a" * 32,
        "videos/{id}/" + "a" * 32 + "x",
        "{id}/" + "a" * 32,
    ],
)
async def test_confirm_rejects_foreign_or_malformed_keys(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    key: str,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    key = key.format(id=exercise.id)
    storage.objects[key] = 100

    response = await client.put(video_url(exercise), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "video_key_invalid"
    assert (await refresh(db_session, exercise)).video_key is None


async def test_confirm_rejects_other_exercises_key(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    other = await make_exercise()
    key = new_key(other)
    storage.objects[key] = 100

    response = await client.put(video_url(exercise), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 422
    assert (await refresh(db_session, exercise)).video_key is None


async def test_confirm_oversized_object_is_422_and_removed(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    key = new_key(exercise)
    storage.objects[key] = MAX_VIDEO_BYTES + 1

    response = await client.put(video_url(exercise), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "video_too_large"
    assert storage.deleted == [key]
    assert (await refresh(db_session, exercise)).video_key is None


async def test_replacing_video_deletes_old_object(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    old = new_key(exercise)
    new = new_key(exercise)
    exercise.video_key = old
    await db_session.commit()
    storage.objects[new] = 100

    response = await client.put(video_url(exercise), headers=auth_headers(actor), json={"key": new})

    assert response.status_code == 200
    assert storage.deleted == [old]
    assert (await refresh(db_session, exercise)).video_key == new


async def test_confirming_same_key_twice_does_not_delete_it(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()
    key = new_key(exercise)
    storage.objects[key] = 100

    for _ in range(2):
        response = await client.put(
            video_url(exercise), headers=auth_headers(actor), json={"key": key}
        )
        assert response.status_code == 200

    assert storage.deleted == []


@pytest.mark.parametrize("role", ALL_ROLES)
async def test_any_signed_in_user_gets_video_url(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    actor = await make_user(role=role)
    key = f"videos/abc/{uuid.uuid4().hex}"
    exercise = await make_exercise(video_key=key)

    response = await client.get(video_url(exercise), headers=auth_headers(actor))

    assert response.status_code == 200
    body = response.json()
    assert body["url"] == f"https://storage.test/get/{key}?type=video/mp4"
    assert body["expires_in"] == 3600


async def test_get_video_without_video_is_404(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user()
    exercise = await make_exercise()

    response = await client.get(video_url(exercise), headers=auth_headers(actor))

    assert response.status_code == 404


async def test_delete_video_clears_key_and_deletes_object(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    key = f"videos/abc/{uuid.uuid4().hex}"
    exercise = await make_exercise(video_key=key)

    response = await client.delete(video_url(exercise), headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == [key]
    assert (await refresh(db_session, exercise)).video_key is None


async def test_delete_video_when_none_is_noop_204(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()

    response = await client.delete(video_url(exercise), headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == []


async def test_delete_exercise_deletes_video_object(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    key = f"videos/abc/{uuid.uuid4().hex}"
    exercise = await make_exercise(video_key=key)

    response = await client.delete(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == [key]


async def test_delete_exercise_without_video_touches_no_storage(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    exercise = await make_exercise()

    response = await client.delete(f"/v1/exercises/{exercise.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == []


async def test_exercise_update_does_not_touch_video_key(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    key = f"videos/abc/{uuid.uuid4().hex}"
    exercise = await make_exercise(video_key=key)

    response = await client.put(
        f"/v1/exercises/{exercise.id}",
        headers=auth_headers(actor),
        json={"name": "Renamed", "muscle": "chest", "video": "https://youtu.be/x"},
    )

    assert response.status_code == 200
    assert response.json()["has_video"] is True
    assert (await refresh(db_session, exercise)).video_key == key


@pytest.mark.parametrize("role", ALL_ROLES)
async def test_exercise_out_has_video_flag_and_never_exposes_key(
    client: AsyncClient,
    make_user: UserFactory,
    make_exercise: ExerciseFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    actor = await make_user(role=role)
    key = f"videos/abc/{uuid.uuid4().hex}"
    with_video = await make_exercise(name="A", video_key=key)
    without = await make_exercise(name="B")

    listing = await client.get("/v1/exercises", headers=auth_headers(actor))
    single = await client.get(f"/v1/exercises/{with_video.id}", headers=auth_headers(actor))

    flags = {item["id"]: item["has_video"] for item in listing.json()}
    assert flags == {with_video.id: True, without.id: False}
    assert single.json()["has_video"] is True
    assert key not in listing.text + single.text
    assert "video_key" not in single.json()
