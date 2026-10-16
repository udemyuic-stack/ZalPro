import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Attendance, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

TODAY = datetime.now(UTC).date()
DAY = TODAY.isoformat()
OTHER_DAY = (TODAY - timedelta(days=1)).isoformat()


def url(user: User, day: str = DAY) -> str:
    return f"/v1/users/{user.id}/attendance/{day}"


def listing(user: User) -> str:
    return f"/v1/users/{user.id}/attendance"


async def count_rows(session: AsyncSession) -> int:
    return await session.scalar(select(func.count()).select_from(Attendance)) or 0


@pytest.fixture
async def trainer(make_user: UserFactory) -> User:
    return await make_user(role="admin")


@pytest.fixture
async def student(make_user: UserFactory, trainer: User) -> User:
    return await make_user(trainer_id=trainer.id)


@pytest.fixture
async def actors(make_user: UserFactory, trainer: User, student: User) -> dict[str, User]:
    return {
        "owner": await make_user(role="owner"),
        "trainer": trainer,
        "self": student,
        "other_trainer": await make_user(role="admin"),
        "unassigned_staff": await make_user(role="admin", trainer_id=trainer.id),
        "barmen": await make_user(role="barmen"),
        "stranger": await make_user(),
    }


@pytest.mark.parametrize("who", ["owner", "trainer"])
async def test_managers_can_mark_attendance(
    client: AsyncClient,
    student: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    who: str,
) -> None:
    actor = actors[who]

    response = await client.put(url(student), headers=auth_headers(actor), json={"present": True})

    assert response.status_code == 200
    body = response.json()
    assert body["day"] == DAY
    assert body["present"] is True
    assert body["marked_by"] == actor.id
    assert datetime.fromisoformat(body["marked_at"]).tzinfo is not None
    assert await count_rows(db_session) == 1


@pytest.mark.parametrize("who", ["self", "other_trainer", "unassigned_staff", "barmen", "stranger"])
async def test_others_cannot_mark_attendance(
    client: AsyncClient,
    student: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    who: str,
) -> None:
    response = await client.put(
        url(student), headers=auth_headers(actors[who]), json={"present": True}
    )

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await count_rows(db_session) == 0


async def test_owner_can_mark_own_attendance_but_trainer_cannot(
    client: AsyncClient, actors: dict[str, User], auth_headers: HeadersFactory
) -> None:
    owner = await client.put(
        url(actors["owner"]), headers=auth_headers(actors["owner"]), json={"present": True}
    )
    trainer = await client.put(
        url(actors["trainer"]), headers=auth_headers(actors["trainer"]), json={"present": True}
    )

    assert owner.status_code == 200
    assert trainer.status_code == 403


async def test_anonymous_cannot_mark_attendance(client: AsyncClient, student: User) -> None:
    response = await client.put(url(student), json={"present": True})

    assert response.status_code == 401


async def test_marking_unknown_user_is_404(
    client: AsyncClient, actors: dict[str, User], auth_headers: HeadersFactory
) -> None:
    owner = await client.put(
        f"/v1/users/missing/attendance/{DAY}",
        headers=auth_headers(actors["owner"]),
        json={"present": True},
    )
    trainer = await client.put(
        f"/v1/users/missing/attendance/{DAY}",
        headers=auth_headers(actors["trainer"]),
        json={"present": True},
    )

    assert owner.status_code == 404
    assert owner.json()["detail"]["code"] == "not_found"
    assert trainer.status_code == 404


@pytest.mark.parametrize(
    "body",
    [
        {"present": True, "marked_by": "someone"},
        {"present": True, "marked_at": "2026-01-01T00:00:00Z"},
        {"present": True, "day": DAY},
        {"present": True, "user_id": "x"},
        {},
        {"present": None},
        {"present": "maybe"},
        {"present": [True]},
    ],
)
async def test_mark_body_is_validated(
    client: AsyncClient,
    student: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    body: dict[str, Any],
) -> None:
    response = await client.put(url(student), headers=auth_headers(trainer), json=body)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await count_rows(db_session) == 0


async def test_mark_requires_json_object(
    client: AsyncClient, student: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(url(student), headers=auth_headers(trainer), json=True)

    assert response.status_code == 422


@pytest.mark.parametrize(
    "day",
    [
        "bad",
        "20260301",
        "2026-3-1",
        "2026-02-30",
        "2019-12-31",
        "1999-01-01",
        (TODAY + timedelta(days=3)).isoformat(),
        "2999-01-01",
    ],
)
async def test_invalid_or_out_of_window_days_are_422(
    client: AsyncClient,
    student: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    day: str,
) -> None:
    headers = auth_headers(trainer)

    write = await client.put(url(student, day), headers=headers, json={"present": True})
    read = await client.get(url(student, day), headers=headers)

    assert write.status_code == 422
    assert write.json()["detail"]["code"] == "validation_error"
    assert read.status_code == 422
    assert await count_rows(db_session) == 0


@pytest.mark.parametrize("day", ["2020-01-01", (TODAY + timedelta(days=2)).isoformat()])
async def test_window_edges_are_accepted(
    client: AsyncClient, student: User, trainer: User, auth_headers: HeadersFactory, day: str
) -> None:
    response = await client.put(
        url(student, day), headers=auth_headers(trainer), json={"present": True}
    )

    assert response.status_code == 200
    assert response.json()["day"] == day


async def test_repeated_put_is_idempotent_and_replaces_the_value(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    first = await client.put(url(student), headers=auth_headers(trainer), json={"present": True})
    same = await client.put(url(student), headers=auth_headers(trainer), json={"present": True})
    flipped = await client.put(url(student), headers=auth_headers(trainer), json={"present": False})
    by_owner = await client.put(
        url(student), headers=auth_headers(actors["owner"]), json={"present": True}
    )

    assert [r.status_code for r in (first, same, flipped, by_owner)] == [200, 200, 200, 200]
    assert same.json()["present"] is True
    assert flipped.json()["present"] is False
    assert by_owner.json()["marked_by"] == actors["owner"].id
    assert first.json()["marked_at"] <= flipped.json()["marked_at"] <= by_owner.json()["marked_at"]
    assert await count_rows(db_session) == 1
    read = await client.get(url(student), headers=auth_headers(student))
    assert read.json()["present"] is True
    assert read.json()["marked_by"] == actors["owner"].id


async def test_different_days_and_users_are_separate_rows(
    client: AsyncClient,
    student: User,
    trainer: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    other = await make_user(trainer_id=trainer.id)
    headers = auth_headers(trainer)

    await client.put(url(student), headers=headers, json={"present": True})
    await client.put(url(student, OTHER_DAY), headers=headers, json={"present": False})
    await client.put(url(other), headers=headers, json={"present": True})

    assert await count_rows(db_session) == 3


async def test_concurrent_marks_produce_one_row_and_no_errors(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    headers = {"trainer": auth_headers(trainer), "owner": auth_headers(actors["owner"])}
    calls = [
        client.put(
            url(student),
            headers=headers["trainer" if n % 2 else "owner"],
            json={"present": bool(n % 3)},
        )
        for n in range(20)
    ]

    results = await asyncio.gather(*calls)

    assert {r.status_code for r in results} == {200}
    assert await count_rows(db_session) == 1


async def test_concurrent_marks_on_new_days_create_one_row_each(
    client: AsyncClient,
    student: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    headers = auth_headers(trainer)
    days = [(TODAY - timedelta(days=n % 5)).isoformat() for n in range(15)]

    results = await asyncio.gather(
        *(client.put(url(student, day), headers=headers, json={"present": True}) for day in days)
    )

    assert {r.status_code for r in results} == {200}
    assert await count_rows(db_session) == 5


@pytest.mark.parametrize("who", ["self", "trainer", "owner"])
async def test_allowed_roles_read_attendance(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    who: str,
) -> None:
    await client.put(url(student), headers=auth_headers(trainer), json={"present": True})

    response = await client.get(url(student), headers=auth_headers(actors[who]))

    assert response.status_code == 200
    assert response.json()["present"] is True
    assert response.json()["marked_by"] == trainer.id


@pytest.mark.parametrize("who", ["other_trainer", "unassigned_staff", "barmen", "stranger"])
async def test_other_roles_cannot_read_attendance(
    client: AsyncClient,
    student: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    who: str,
) -> None:
    response = await client.get(url(student), headers=auth_headers(actors[who]))

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"


async def test_anonymous_and_unknown_user_reads(
    client: AsyncClient, student: User, actors: dict[str, User], auth_headers: HeadersFactory
) -> None:
    anonymous = await client.get(url(student))
    unknown = await client.get(
        f"/v1/users/missing/attendance/{DAY}", headers=auth_headers(actors["owner"])
    )

    assert anonymous.status_code == 401
    assert unknown.status_code == 404


async def test_missing_row_reads_as_not_present(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await client.get(url(student), headers=auth_headers(student))

    assert response.status_code == 200
    assert response.json() == {
        "day": DAY,
        "present": False,
        "marked_by": None,
        "marked_at": None,
    }
    assert await count_rows(db_session) == 0


async def test_list_returns_window_rows_in_day_order(
    client: AsyncClient, student: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(trainer)
    for day, present in (("2026-03-03", True), ("2026-03-01", False), ("2026-03-02", True)):
        await client.put(url(student, day), headers=headers, json={"present": present})
    await client.put(url(student, "2026-03-09"), headers=headers, json={"present": True})

    response = await client.get(
        listing(student), headers=headers, params={"from": "2026-03-01", "to": "2026-03-03"}
    )

    assert response.status_code == 200
    assert [(r["day"], r["present"]) for r in response.json()] == [
        ("2026-03-01", False),
        ("2026-03-02", True),
        ("2026-03-03", True),
    ]
    assert all(r["marked_by"] == trainer.id for r in response.json())


async def test_list_is_empty_without_rows_and_scoped_to_the_user(
    client: AsyncClient,
    student: User,
    trainer: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user(trainer_id=trainer.id)
    await client.put(url(other), headers=auth_headers(trainer), json={"present": True})

    response = await client.get(
        listing(student), headers=auth_headers(student), params={"from": DAY, "to": DAY}
    )

    assert response.status_code == 200
    assert response.json() == []


async def test_list_span_limit_is_400_days(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    start = date(2025, 1, 1)

    allowed = await client.get(
        listing(student),
        headers=headers,
        params={"from": start.isoformat(), "to": (start + timedelta(399)).isoformat()},
    )
    refused = await client.get(
        listing(student),
        headers=headers,
        params={"from": start.isoformat(), "to": (start + timedelta(400)).isoformat()},
    )

    assert allowed.status_code == 200
    assert refused.status_code == 422
    assert refused.json()["detail"]["code"] == "validation_error"


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"from": "2026-03-01"},
        {"to": "2026-03-01"},
        {"from": "2026-03-05", "to": "2026-03-01"},
        {"from": "bad", "to": "2026-03-01"},
        {"from": "2026-03-01", "to": "2026-02-30"},
        {"from": "20260301", "to": "20260302"},
        {"from": "2026-03-01", "to": "2026-03-02", "extra": "1"},
    ],
)
async def test_list_query_is_validated(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    params: dict[str, str],
) -> None:
    response = await client.get(listing(student), headers=auth_headers(student), params=params)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


@pytest.mark.parametrize("who", ["self", "trainer", "owner"])
async def test_list_is_readable_by_self_and_managers(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    who: str,
) -> None:
    await client.put(url(student), headers=auth_headers(trainer), json={"present": True})

    response = await client.get(
        listing(student), headers=auth_headers(actors[who]), params={"from": DAY, "to": DAY}
    )

    assert response.status_code == 200
    assert len(response.json()) == 1


@pytest.mark.parametrize("who", ["other_trainer", "unassigned_staff", "barmen", "stranger"])
async def test_list_is_forbidden_for_others(
    client: AsyncClient,
    student: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    who: str,
) -> None:
    response = await client.get(
        listing(student), headers=auth_headers(actors[who]), params={"from": DAY, "to": DAY}
    )

    assert response.status_code == 403


async def test_list_anonymous_is_401_and_unknown_user_is_404(
    client: AsyncClient, student: User, actors: dict[str, User], auth_headers: HeadersFactory
) -> None:
    params = {"from": DAY, "to": DAY}

    anonymous = await client.get(listing(student), params=params)
    unknown = await client.get(
        "/v1/users/missing/attendance", headers=auth_headers(actors["owner"]), params=params
    )

    assert anonymous.status_code == 401
    assert unknown.status_code == 404


async def test_attendance_is_removed_with_its_user(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    await client.put(url(student), headers=auth_headers(trainer), json={"present": True})

    response = await client.delete(f"/v1/users/{student.id}", headers=auth_headers(actors["owner"]))

    assert response.status_code == 204
    assert await count_rows(db_session) == 0
