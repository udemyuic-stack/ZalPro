import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Photo, User
from zalpro_api.services.storage import UnconfiguredStorage

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
PhotoFactory = Callable[..., Awaitable[Photo]]

VALID = {"weight": 80.5, "size": 1000}


def upload_url(user: User | str) -> str:
    user_id = user if isinstance(user, str) else user.id
    return f"/v1/users/{user_id}/photos/upload-url"


def list_url(user: User | str) -> str:
    user_id = user if isinstance(user, str) else user.id
    return f"/v1/users/{user_id}/photos"


async def photo_count(db_session: AsyncSession) -> int:
    return await db_session.scalar(select(func.count()).select_from(Photo)) or 0


async def build_actors(make_user: UserFactory) -> dict[str, User]:
    trainer = await make_user(role="admin")
    return {
        "student": await make_user(trainer_id=trainer.id),
        "trainer": trainer,
        "owner": await make_user(role="owner"),
        "other_user": await make_user(),
        "other_trainer": await make_user(role="admin"),
        "barmen": await make_user(role="barmen"),
    }


@pytest.mark.parametrize(
    ("actor", "status"),
    [
        ("student", 200),
        ("trainer", 200),
        ("owner", 200),
        ("other_user", 403),
        ("other_trainer", 403),
        ("barmen", 403),
    ],
)
async def test_list_read_matrix(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    actor: str,
    status: int,
) -> None:
    actors = await build_actors(make_user)

    response = await client.get(list_url(actors["student"]), headers=auth_headers(actors[actor]))

    assert response.status_code == status
    if status == 403:
        assert response.json()["detail"]["code"] == "forbidden"


async def test_list_unknown_user_is_404(
    client: AsyncClient, storage: Any, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.get(list_url("missing"), headers=auth_headers(owner))

    assert response.status_code == 404


async def test_list_is_newest_first_with_download_url(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    make_photo: PhotoFactory,
    auth_headers: HeadersFactory,
) -> None:
    student = await make_user()
    other = await make_user()
    now = datetime.now(UTC)
    old = await make_photo(student.id, taken_at=now - timedelta(days=2), weight=82.0)
    new = await make_photo(student.id, taken_at=now, weight=80.0)
    mid = await make_photo(student.id, taken_at=now - timedelta(days=1), weight=81.0)
    await make_photo(other.id)

    response = await client.get(list_url(student), headers=auth_headers(student))

    assert response.status_code == 200
    body = response.json()
    assert [item["id"] for item in body] == [str(new.id), str(mid.id), str(old.id)]
    assert set(body[0]) == {"id", "taken_at", "weight", "size", "download_url"}
    assert body[0]["download_url"] == f"https://storage.test/get/{new.key}"
    assert body[0]["weight"] == 80.0
    assert body[0]["size"] == 1000


async def test_list_empty(
    client: AsyncClient, storage: Any, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    response = await client.get(list_url(student), headers=auth_headers(student))

    assert response.status_code == 200
    assert response.json() == []


async def test_upload_url_self_creates_row(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    before = datetime.now(UTC)

    response = await client.post(upload_url(student), headers=auth_headers(student), json=VALID)

    assert response.status_code == 201
    body = response.json()
    assert set(body) == {"photo_id", "upload_url", "expires_in"}
    photo = await db_session.get(Photo, uuid.UUID(body["photo_id"]))
    assert photo is not None
    assert photo.user_id == student.id
    assert photo.weight == 80.5
    assert photo.size == 1000
    assert photo.key.startswith(f"images/{student.id}/")
    assert abs((photo.taken_at - before).total_seconds()) < 5
    assert body["upload_url"] == f"https://storage.test/put/{photo.key}?size=1000"
    assert body["expires_in"] == 600
    assert storage.put_calls == [(photo.key, 1000)]


@pytest.mark.parametrize("actor", ["trainer", "owner", "other_user", "barmen"])
async def test_upload_url_only_self(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    actor: str,
) -> None:
    actors = await build_actors(make_user)

    response = await client.post(
        upload_url(actors["student"]), headers=auth_headers(actors[actor]), json=VALID
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await photo_count(db_session) == 0
    assert storage.put_calls == []


async def test_upload_url_permission_checked_before_user_lookup(
    client: AsyncClient, storage: Any, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.post(upload_url("missing"), headers=auth_headers(owner), json=VALID)

    assert response.status_code == 403


async def test_upload_url_unauthenticated_is_401(
    client: AsyncClient, storage: Any, make_user: UserFactory
) -> None:
    student = await make_user()

    assert (await client.post(upload_url(student), json=VALID)).status_code == 401
    assert (await client.get(list_url(student))).status_code == 401
    assert (await client.delete(f"{list_url(student)}/{uuid.uuid4()}")).status_code == 401


@pytest.mark.parametrize("size", [1, 358400])
async def test_upload_url_size_boundaries_ok(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    size: int,
) -> None:
    student = await make_user()

    response = await client.post(
        upload_url(student), headers=auth_headers(student), json={"weight": 70, "size": size}
    )

    assert response.status_code == 201
    assert storage.put_calls[0][1] == size


@pytest.mark.parametrize("size", [0, -1, 358401, "1000", 1000.5, None])
async def test_upload_url_invalid_size_is_422(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    size: Any,
) -> None:
    student = await make_user()

    response = await client.post(
        upload_url(student), headers=auth_headers(student), json={"weight": 70, "size": size}
    )

    assert response.status_code == 422
    assert await photo_count(db_session) == 0


@pytest.mark.parametrize("weight", ["80", 0, -1, 501, 0.0, None, True])
async def test_upload_url_invalid_weight_is_422(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    weight: Any,
) -> None:
    student = await make_user()

    response = await client.post(
        upload_url(student), headers=auth_headers(student), json={"weight": weight, "size": 10}
    )

    assert response.status_code == 422


async def test_upload_url_nan_weight_is_422(
    client: AsyncClient, storage: Any, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    response = await client.post(
        upload_url(student),
        headers={**auth_headers(student), "Content-Type": "application/json"},
        content='{"weight": NaN, "size": 10}',
    )

    assert response.status_code == 422


@pytest.mark.parametrize("weight", [1, 500, 0.1, 500.0])
async def test_upload_url_valid_weights(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    weight: float,
) -> None:
    student = await make_user()

    response = await client.post(
        upload_url(student), headers=auth_headers(student), json={"weight": weight, "size": 10}
    )

    assert response.status_code == 201


@pytest.mark.parametrize(
    "extra",
    [
        {"taken_at": "2020-01-01T00:00:00Z"},
        {"key": "images/x/y"},
        {"user_id": "x"},
        {"id": str(uuid.uuid4())},
    ],
)
async def test_upload_url_extra_field_is_422(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    extra: dict[str, Any],
) -> None:
    student = await make_user()

    response = await client.post(
        upload_url(student), headers=auth_headers(student), json={**VALID, **extra}
    )

    assert response.status_code == 422
    assert await photo_count(db_session) == 0


async def test_upload_url_missing_fields_is_422(
    client: AsyncClient, storage: Any, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    for body in ({}, {"weight": 70}, {"size": 10}):
        response = await client.post(upload_url(student), headers=auth_headers(student), json=body)
        assert response.status_code == 422


async def test_upload_url_storage_failure_is_503_and_nothing_persisted(
    client: AsyncClient,
    app: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    original = app.state.storage
    app.state.storage = UnconfiguredStorage()
    try:
        response = await client.post(upload_url(student), headers=auth_headers(student), json=VALID)
    finally:
        app.state.storage = original

    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "storage_unavailable"
    assert await photo_count(db_session) == 0


async def test_upload_url_keys_are_unique(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()

    for _ in range(2):
        response = await client.post(upload_url(student), headers=auth_headers(student), json=VALID)
        assert response.status_code == 201

    assert await photo_count(db_session) == 2
    assert len({key for key, _ in storage.put_calls}) == 2


async def test_delete_self_removes_row_and_object(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    make_photo: PhotoFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    photo = await make_photo(student.id)
    key = photo.key
    photo_id = photo.id

    response = await client.delete(f"{list_url(student)}/{photo_id}", headers=auth_headers(student))

    assert response.status_code == 204
    assert response.content == b""
    db_session.expire_all()
    assert await db_session.get(Photo, photo_id) is None
    assert storage.deleted == [key]


async def test_delete_other_users_photo_via_own_route_is_404(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    make_photo: PhotoFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    other = await make_user()
    photo = await make_photo(other.id)

    response = await client.delete(f"{list_url(student)}/{photo.id}", headers=auth_headers(student))

    assert response.status_code == 404
    assert response.json()["detail"]["message"] == "Rasm topilmadi"
    assert await photo_count(db_session) == 1
    assert storage.deleted == []


async def test_delete_other_users_photo_via_their_route_is_403(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    make_photo: PhotoFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    other = await make_user()
    photo = await make_photo(student.id)

    response = await client.delete(f"{list_url(student)}/{photo.id}", headers=auth_headers(other))

    assert response.status_code == 403
    assert await photo_count(db_session) == 1


@pytest.mark.parametrize("actor", ["trainer", "owner", "other_trainer", "barmen"])
async def test_delete_by_non_self_is_403(
    client: AsyncClient,
    storage: Any,
    make_user: UserFactory,
    make_photo: PhotoFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    actor: str,
) -> None:
    actors = await build_actors(make_user)
    photo = await make_photo(actors["student"].id)

    response = await client.delete(
        f"{list_url(actors['student'])}/{photo.id}", headers=auth_headers(actors[actor])
    )

    assert response.status_code == 403
    assert await photo_count(db_session) == 1
    assert storage.deleted == []


async def test_delete_unknown_photo_is_404(
    client: AsyncClient, storage: Any, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    response = await client.delete(
        f"{list_url(student)}/{uuid.uuid4()}", headers=auth_headers(student)
    )

    assert response.status_code == 404
    assert storage.deleted == []


async def test_delete_malformed_photo_id_is_422(
    client: AsyncClient, storage: Any, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    response = await client.delete(f"{list_url(student)}/not-a-uuid", headers=auth_headers(student))

    assert response.status_code == 422


async def test_deleting_user_cascades_photos(
    client: AsyncClient,
    make_user: UserFactory,
    make_photo: PhotoFactory,
    db_session: AsyncSession,
) -> None:
    student = await make_user()
    keeper = await make_user()
    await make_photo(student.id)
    await make_photo(keeper.id)

    await db_session.delete(await db_session.get(User, student.id))
    await db_session.commit()

    assert await photo_count(db_session) == 1
