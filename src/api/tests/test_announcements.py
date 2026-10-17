import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Announcement, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

URL = "/v1/announcements"


def payload(**fields: Any) -> dict[str, Any]:
    return {"title": "Safar", "body": "Dushanba kelmayman", "audience": "students", **fields}


@pytest.fixture
async def owner(make_user: UserFactory) -> User:
    return await make_user(role="owner")


@pytest.fixture
async def trainer(make_user: UserFactory) -> User:
    return await make_user(role="admin", name="Trener")


@pytest.fixture
async def other_trainer(make_user: UserFactory) -> User:
    return await make_user(role="admin")


@pytest.fixture
async def student(make_user: UserFactory, trainer: User) -> User:
    return await make_user(trainer_id=trainer.id)


@pytest.fixture
async def other_student(make_user: UserFactory, other_trainer: User) -> User:
    return await make_user(trainer_id=other_trainer.id)


@pytest.fixture
async def loner(make_user: UserFactory) -> User:
    return await make_user()


async def post(
    client: AsyncClient, headers: HeadersFactory, actor: User, **fields: Any
) -> dict[str, Any]:
    response = await client.post(URL, json=payload(**fields), headers=headers(actor))
    assert response.status_code == 201, response.text
    return response.json()


async def titles(client: AsyncClient, headers: HeadersFactory, actor: User) -> list[str]:
    response = await client.get(URL, headers=headers(actor))
    assert response.status_code == 200
    return [item["title"] for item in response.json()]


async def test_staff_creates_and_newest_comes_first(
    client: AsyncClient, auth_headers: HeadersFactory, owner: User, trainer: User
) -> None:
    first = await post(client, auth_headers, trainer, title="Birinchi")
    second = await post(client, auth_headers, trainer, title="Ikkinchi")
    assert first["audience"] == "students"
    assert first["author_name"] == "Trener"
    assert first["expires_at"] is None
    assert await titles(client, auth_headers, trainer) == ["Ikkinchi", "Birinchi"]
    assert second["id"] != first["id"]


async def test_trainer_announcement_reaches_only_own_students(
    client: AsyncClient,
    auth_headers: HeadersFactory,
    trainer: User,
    student: User,
    other_student: User,
    loner: User,
    other_trainer: User,
    owner: User,
) -> None:
    await post(client, auth_headers, trainer, title="Mening")
    assert await titles(client, auth_headers, student) == ["Mening"]
    assert await titles(client, auth_headers, other_student) == []
    assert await titles(client, auth_headers, loner) == []
    assert await titles(client, auth_headers, other_trainer) == []
    assert await titles(client, auth_headers, owner) == ["Mening"]
    assert await titles(client, auth_headers, trainer) == ["Mening"]


async def test_owner_gym_wide_announcement_reaches_everyone(
    client: AsyncClient,
    auth_headers: HeadersFactory,
    make_user: UserFactory,
    owner: User,
    trainer: User,
    student: User,
    other_student: User,
    loner: User,
) -> None:
    barmen = await make_user(role="barmen")
    created = await post(client, auth_headers, owner, title="Bayram", audience="all")
    assert created["audience"] == "all"
    for actor in (trainer, student, other_student, loner, barmen, owner):
        assert await titles(client, auth_headers, actor) == ["Bayram"]


async def test_trainer_cannot_post_gym_wide(
    client: AsyncClient, auth_headers: HeadersFactory, trainer: User
) -> None:
    response = await client.post(URL, json=payload(audience="all"), headers=auth_headers(trainer))
    assert response.status_code == 403
    assert await titles(client, auth_headers, trainer) == []


async def test_students_and_barmen_cannot_write(
    client: AsyncClient,
    auth_headers: HeadersFactory,
    make_user: UserFactory,
    owner: User,
    student: User,
) -> None:
    barmen = await make_user(role="barmen")
    created = await post(client, auth_headers, owner, audience="all")
    for actor in (student, barmen):
        response = await client.post(URL, json=payload(), headers=auth_headers(actor))
        assert response.status_code == 403
        response = await client.delete(f"{URL}/{created['id']}", headers=auth_headers(actor))
        assert response.status_code == 403


async def test_requires_authentication(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401
    assert (await client.post(URL, json=payload())).status_code == 401


async def test_expired_announcement_is_hidden(
    client: AsyncClient,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    trainer: User,
    student: User,
) -> None:
    expiring = await post(client, auth_headers, trainer, title="Qisqa", expires_in_days=1)
    await post(client, auth_headers, trainer, title="Doimiy")
    assert expiring["expires_at"] is not None
    assert await titles(client, auth_headers, student) == ["Doimiy", "Qisqa"]
    await db_session.execute(
        update(Announcement)
        .where(Announcement.id == uuid.UUID(expiring["id"]))
        .values(expires_at=datetime.now(UTC) - timedelta(minutes=1))
    )
    await db_session.commit()
    assert await titles(client, auth_headers, student) == ["Doimiy"]


@pytest.mark.parametrize("days", [1, 7, 30, None])
async def test_allowed_expiry_values(
    client: AsyncClient, auth_headers: HeadersFactory, trainer: User, days: int | None
) -> None:
    created = await post(client, auth_headers, trainer, expires_in_days=days)
    assert (created["expires_at"] is None) == (days is None)


@pytest.mark.parametrize("days", [0, 2, 365, -1, "7", True, 1.5])
async def test_invalid_expiry_is_rejected(
    client: AsyncClient, auth_headers: HeadersFactory, trainer: User, days: Any
) -> None:
    response = await client.post(
        URL, json=payload(expires_in_days=days), headers=auth_headers(trainer)
    )
    assert response.status_code == 422


@pytest.mark.parametrize(
    "fields",
    [
        {"title": ""},
        {"title": "   "},
        {"title": "x" * 81},
        {"body": ""},
        {"body": "y" * 501},
        {"audience": "everyone"},
        {"extra": 1},
    ],
)
async def test_invalid_payload_is_rejected(
    client: AsyncClient, auth_headers: HeadersFactory, trainer: User, fields: dict[str, Any]
) -> None:
    response = await client.post(URL, json=payload(**fields), headers=auth_headers(trainer))
    assert response.status_code == 422


async def test_limit_values_are_accepted(
    client: AsyncClient, auth_headers: HeadersFactory, trainer: User
) -> None:
    created = await post(client, auth_headers, trainer, title="x" * 80, body="y" * 500)
    assert len(created["title"]) == 80
    assert len(created["body"]) == 500


async def test_delete_rules(
    client: AsyncClient,
    auth_headers: HeadersFactory,
    owner: User,
    trainer: User,
    other_trainer: User,
    student: User,
) -> None:
    mine = await post(client, auth_headers, trainer)
    other = await client.delete(f"{URL}/{mine['id']}", headers=auth_headers(other_trainer))
    assert other.status_code == 403
    own = await client.delete(f"{URL}/{mine['id']}", headers=auth_headers(trainer))
    assert own.status_code == 204
    assert await titles(client, auth_headers, student) == []

    theirs = await post(client, auth_headers, trainer)
    by_owner = await client.delete(f"{URL}/{theirs['id']}", headers=auth_headers(owner))
    assert by_owner.status_code == 204


async def test_delete_unknown_is_404(
    client: AsyncClient, auth_headers: HeadersFactory, trainer: User
) -> None:
    response = await client.delete(f"{URL}/{uuid.uuid4()}", headers=auth_headers(trainer))
    assert response.status_code == 404


async def test_twenty_first_active_announcement_conflicts(
    client: AsyncClient,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    trainer: User,
    other_trainer: User,
) -> None:
    for number in range(20):
        await post(client, auth_headers, trainer, title=f"E'lon {number}")
    response = await client.post(URL, json=payload(), headers=auth_headers(trainer))
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "too_many_announcements"
    await post(client, auth_headers, other_trainer)
    listed = await client.get(URL, headers=auth_headers(trainer))
    assert len(listed.json()) == 20

    await db_session.execute(
        update(Announcement)
        .where(Announcement.author_id == trainer.id)
        .values(expires_at=datetime.now(UTC) - timedelta(minutes=1))
    )
    await db_session.commit()
    await post(client, auth_headers, trainer)


async def test_deleting_author_removes_announcements(
    client: AsyncClient,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    owner: User,
    trainer: User,
) -> None:
    await post(client, auth_headers, trainer, title="Ketadi")
    await db_session.delete(trainer)
    await db_session.commit()
    assert await titles(client, auth_headers, owner) == []
