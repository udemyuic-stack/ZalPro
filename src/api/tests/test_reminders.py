import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Reminder, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

TODAY = datetime.now(UTC).date()
NOW_WINDOW = {
    "from": (TODAY - timedelta(days=1)).isoformat(),
    "to": (TODAY + timedelta(days=1)).isoformat(),
}


async def count_rows(session: AsyncSession) -> int:
    return await session.scalar(select(func.count()).select_from(Reminder)) or 0


async def insert_reminder(session: AsyncSession, **fields: Any) -> Reminder:
    values = {
        "client_id": "client",
        "client_name": "Client",
        "trainer_id": "",
        "sent_by": "sender",
        "days_left": 3,
    }
    reminder = Reminder(**{**values, **fields})
    session.add(reminder)
    await session.commit()
    return reminder


@pytest.fixture
async def trainer(make_user: UserFactory) -> User:
    return await make_user(role="admin")


@pytest.fixture
async def student(make_user: UserFactory, trainer: User) -> User:
    return await make_user(trainer_id=trainer.id, name="Aziz")


@pytest.fixture
async def actors(make_user: UserFactory, trainer: User, student: User) -> dict[str, User]:
    return {
        "owner": await make_user(role="owner"),
        "trainer": trainer,
        "self": student,
        "other_trainer": await make_user(role="admin"),
        "barmen": await make_user(role="barmen"),
        "stranger": await make_user(),
    }


async def send(
    client: AsyncClient, actor: User, headers: HeadersFactory, client_id: str, days_left: Any = 3
) -> Any:
    return await client.post(
        "/v1/reminders",
        headers=headers(actor),
        json={"client_id": client_id, "days_left": days_left},
    )


@pytest.mark.parametrize("who", ["owner", "trainer"])
async def test_staff_who_manage_the_client_can_create_a_reminder(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    who: str,
) -> None:
    actor = actors[who]

    response = await send(client, actor, auth_headers, student.id, 2)

    assert response.status_code == 201
    body = response.json()
    assert set(body) == {
        "id",
        "client_id",
        "client_name",
        "trainer_id",
        "sent_by",
        "sent_at",
        "days_left",
    }
    assert body["client_id"] == student.id
    assert body["client_name"] == "Aziz"
    assert body["trainer_id"] == trainer.id
    assert body["sent_by"] == actor.id
    assert body["days_left"] == 2
    sent_at = datetime.fromisoformat(body["sent_at"])
    assert abs(datetime.now(UTC) - sent_at) < timedelta(minutes=1)
    assert await count_rows(db_session) == 1


async def test_owner_can_remind_a_client_without_trainer(
    client: AsyncClient,
    make_user: UserFactory,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
) -> None:
    loner = await make_user(name="Loner")

    response = await send(client, actors["owner"], auth_headers, loner.id)

    assert response.status_code == 201
    assert response.json()["trainer_id"] == ""
    assert response.json()["client_name"] == "Loner"


async def test_trainer_cannot_remind_a_client_without_trainer(
    client: AsyncClient,
    make_user: UserFactory,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    loner = await make_user()

    response = await send(client, trainer, auth_headers, loner.id)

    assert response.status_code == 403
    assert await count_rows(db_session) == 0


async def test_trainer_cannot_remind_another_trainers_client(
    client: AsyncClient,
    student: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    response = await send(client, actors["other_trainer"], auth_headers, student.id)

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await count_rows(db_session) == 0


@pytest.mark.parametrize("who", ["barmen", "self", "stranger"])
async def test_non_staff_cannot_create_reminders(
    client: AsyncClient,
    student: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    who: str,
) -> None:
    response = await send(client, actors[who], auth_headers, student.id)

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"
    assert await count_rows(db_session) == 0


async def test_anonymous_cannot_create_a_reminder(client: AsyncClient, student: User) -> None:
    response = await client.post("/v1/reminders", json={"client_id": student.id, "days_left": 1})

    assert response.status_code == 401


async def test_unknown_client_is_404_for_staff_and_403_for_non_staff(
    client: AsyncClient, actors: dict[str, User], auth_headers: HeadersFactory
) -> None:
    owner = await send(client, actors["owner"], auth_headers, "missing")
    trainer = await send(client, actors["trainer"], auth_headers, "missing")
    barmen = await send(client, actors["barmen"], auth_headers, "missing")

    assert owner.status_code == 404
    assert owner.json()["detail"]["code"] == "not_found"
    assert trainer.status_code == 404
    assert barmen.status_code == 403


@pytest.mark.parametrize(
    "field", ["client_name", "trainer_id", "sent_by", "sent_at", "id", "extra"]
)
async def test_server_owned_fields_in_the_body_are_422(
    client: AsyncClient,
    student: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    field: str,
) -> None:
    response = await client.post(
        "/v1/reminders",
        headers=auth_headers(trainer),
        json={"client_id": student.id, "days_left": 3, field: "forged"},
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await count_rows(db_session) == 0


@pytest.mark.parametrize("days_left", [32, -3651, "5", 5.5, True, None, [1]])
async def test_invalid_days_left_is_422(
    client: AsyncClient,
    student: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    days_left: Any,
) -> None:
    response = await send(client, trainer, auth_headers, student.id, days_left)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await count_rows(db_session) == 0


@pytest.mark.parametrize("days_left", [31, 0, -1, -3650])
async def test_days_left_boundaries_are_accepted(
    client: AsyncClient, student: User, trainer: User, auth_headers: HeadersFactory, days_left: int
) -> None:
    response = await send(client, trainer, auth_headers, student.id, days_left)

    assert response.status_code == 201
    assert response.json()["days_left"] == days_left


@pytest.mark.parametrize(
    "body",
    [
        {},
        {"days_left": 3},
        {"client_id": "x"},
        {"client_id": "", "days_left": 3},
        {"client_id": "x" * 129, "days_left": 3},
        {"client_id": 5, "days_left": 3},
        {"client_id": None, "days_left": 3},
    ],
)
async def test_invalid_bodies_are_422(
    client: AsyncClient,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    body: dict[str, Any],
) -> None:
    response = await client.post("/v1/reminders", headers=auth_headers(trainer), json=body)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"
    assert await count_rows(db_session) == 0


async def test_each_post_creates_a_new_journal_row(
    client: AsyncClient,
    student: User,
    trainer: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    results = await asyncio.gather(
        *(send(client, trainer, auth_headers, student.id) for _ in range(5))
    )

    assert {r.status_code for r in results} == {201}
    assert len({r.json()["id"] for r in results}) == 5
    assert await count_rows(db_session) == 5


async def test_owner_lists_all_and_trainer_lists_only_own(
    client: AsyncClient,
    make_user: UserFactory,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
) -> None:
    other_student = await make_user(trainer_id=actors["other_trainer"].id)
    loner = await make_user()
    await send(client, trainer, auth_headers, student.id)
    await send(client, actors["other_trainer"], auth_headers, other_student.id)
    await send(client, actors["owner"], auth_headers, loner.id)

    owner = await client.get(
        "/v1/reminders", headers=auth_headers(actors["owner"]), params=NOW_WINDOW
    )
    own = await client.get("/v1/reminders", headers=auth_headers(trainer), params=NOW_WINDOW)
    other = await client.get(
        "/v1/reminders", headers=auth_headers(actors["other_trainer"]), params=NOW_WINDOW
    )

    assert {r["client_id"] for r in owner.json()} == {student.id, other_student.id, loner.id}
    assert [r["client_id"] for r in own.json()] == [student.id]
    assert [r["client_id"] for r in other.json()] == [other_student.id]


@pytest.mark.parametrize("who", ["barmen", "self", "stranger"])
async def test_barmen_and_users_see_an_empty_list(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    who: str,
) -> None:
    await send(client, trainer, auth_headers, student.id)

    response = await client.get(
        "/v1/reminders", headers=auth_headers(actors[who]), params=NOW_WINDOW
    )

    assert response.status_code == 200
    assert response.json() == []


async def test_list_is_newest_first(
    client: AsyncClient,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    base = datetime(2026, 3, 10, 8, 0, tzinfo=UTC)
    for n in range(3):
        await insert_reminder(
            db_session, client_id=f"c{n}", trainer_id=trainer.id, sent_at=base + timedelta(hours=n)
        )

    response = await client.get(
        "/v1/reminders",
        headers=auth_headers(actors["owner"]),
        params={"from": "2026-03-10", "to": "2026-03-10"},
    )

    assert [r["client_id"] for r in response.json()] == ["c2", "c1", "c0"]


async def test_list_window_uses_the_gym_timezone_day(
    client: AsyncClient,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    await insert_reminder(
        db_session, client_id="before", sent_at=datetime(2026, 3, 1, 18, 59, 59, tzinfo=UTC)
    )
    await insert_reminder(
        db_session, client_id="first", sent_at=datetime(2026, 3, 1, 19, 0, tzinfo=UTC)
    )
    await insert_reminder(
        db_session, client_id="last", sent_at=datetime(2026, 3, 2, 18, 59, 59, tzinfo=UTC)
    )
    await insert_reminder(
        db_session, client_id="after", sent_at=datetime(2026, 3, 2, 19, 0, tzinfo=UTC)
    )
    headers = auth_headers(actors["owner"])

    day = await client.get(
        "/v1/reminders", headers=headers, params={"from": "2026-03-02", "to": "2026-03-02"}
    )
    wide = await client.get(
        "/v1/reminders", headers=headers, params={"from": "2026-03-01", "to": "2026-03-03"}
    )

    assert {r["client_id"] for r in day.json()} == {"first", "last"}
    assert len(wide.json()) == 4


async def test_list_span_limit_is_400_days(
    client: AsyncClient, actors: dict[str, User], auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(actors["owner"])
    start = date(2025, 1, 1)

    allowed = await client.get(
        "/v1/reminders",
        headers=headers,
        params={"from": start.isoformat(), "to": (start + timedelta(399)).isoformat()},
    )
    refused = await client.get(
        "/v1/reminders",
        headers=headers,
        params={"from": start.isoformat(), "to": (start + timedelta(400)).isoformat()},
    )

    assert allowed.status_code == 200
    assert refused.status_code == 422


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"from": "2026-03-01"},
        {"to": "2026-03-01"},
        {"from": "2026-03-05", "to": "2026-03-01"},
        {"from": "bad", "to": "2026-03-01"},
        {"from": "2026-03-01", "to": "2026-02-30"},
        {"from": "2026-03-01", "to": "2026-03-02", "extra": "1"},
    ],
)
async def test_list_query_is_validated(
    client: AsyncClient, trainer: User, auth_headers: HeadersFactory, params: dict[str, str]
) -> None:
    response = await client.get("/v1/reminders", headers=auth_headers(trainer), params=params)

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


async def test_anonymous_cannot_list_reminders(client: AsyncClient) -> None:
    response = await client.get("/v1/reminders", params=NOW_WINDOW)

    assert response.status_code == 401


async def test_owner_can_delete_a_reminder(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    created = (await send(client, trainer, auth_headers, student.id)).json()

    response = await client.delete(
        f"/v1/reminders/{created['id']}", headers=auth_headers(actors["owner"])
    )

    assert response.status_code == 204
    assert await count_rows(db_session) == 0


@pytest.mark.parametrize("who", ["trainer", "other_trainer", "barmen", "self", "stranger"])
async def test_non_owners_cannot_delete_reminders(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    who: str,
) -> None:
    created = (await send(client, trainer, auth_headers, student.id)).json()

    response = await client.delete(
        f"/v1/reminders/{created['id']}", headers=auth_headers(actors[who])
    )

    assert response.status_code == 403
    assert await count_rows(db_session) == 1


async def test_delete_anonymous_is_401_and_unknown_is_404(
    client: AsyncClient, actors: dict[str, User], auth_headers: HeadersFactory
) -> None:
    anonymous = await client.delete("/v1/reminders/anything")
    unknown = await client.delete("/v1/reminders/missing", headers=auth_headers(actors["owner"]))

    assert anonymous.status_code == 401
    assert unknown.status_code == 404
    assert unknown.json()["detail"]["code"] == "not_found"


async def test_reminders_survive_deleting_the_client(
    client: AsyncClient,
    student: User,
    trainer: User,
    actors: dict[str, User],
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    await send(client, trainer, auth_headers, student.id)

    deleted = await client.delete(f"/v1/users/{student.id}", headers=auth_headers(actors["owner"]))
    listed = await client.get("/v1/reminders", headers=auth_headers(trainer), params=NOW_WINDOW)

    assert deleted.status_code == 204
    assert await count_rows(db_session) == 1
    assert [(r["client_id"], r["client_name"]) for r in listed.json()] == [(student.id, "Aziz")]
