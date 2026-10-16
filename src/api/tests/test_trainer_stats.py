from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Day, Message, Plan, Rating, Trainer, User, Weight

UserFactory = Callable[..., Awaitable[User]]
TrainerFactory = Callable[..., Awaitable[Trainer]]
HeadersFactory = Callable[[User], dict[str, str]]

ZONE = ZoneInfo("Asia/Tashkent")
URL = "/v1/stats/trainers"


@pytest.fixture
async def owner(make_user: UserFactory) -> User:
    return await make_user(role="owner")


@pytest.fixture
async def trainer(make_user: UserFactory, make_trainer: TrainerFactory) -> User:
    user = await make_user(role="admin")
    await make_trainer(user)
    return user


def today():
    return datetime.now(ZONE).date()


async def seed_plan(session: AsyncSession, plan_id: str, meals: int) -> None:
    session.add(Plan(id=plan_id, title=plan_id, meals=[{"name": f"m{i}"} for i in range(meals)]))
    await session.commit()


async def stats_for(
    client: AsyncClient, owner: User, headers: HeadersFactory, trainer: User, **params: int
) -> dict:
    response = await client.get(URL, params=params, headers=headers(owner))
    assert response.status_code == 200
    return next(item for item in response.json() if item["trainer_id"] == trainer.id)


@pytest.mark.parametrize("role", ["admin", "barmen", "user"])
async def test_non_owner_is_forbidden(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    actor = await make_user(role=role)

    response = await client.get(URL, headers=auth_headers(actor))

    assert response.status_code == 403


async def test_trainer_is_forbidden(
    client: AsyncClient, trainer: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(URL, headers=auth_headers(trainer))

    assert response.status_code == 403


async def test_anonymous_is_unauthorized(client: AsyncClient) -> None:
    response = await client.get(URL)

    assert response.status_code == 401


@pytest.mark.parametrize("days", [0, -1, 366, "abc"])
async def test_days_out_of_range_is_rejected(
    client: AsyncClient, owner: User, auth_headers: HeadersFactory, days: int | str
) -> None:
    response = await client.get(URL, params={"days": days}, headers=auth_headers(owner))

    assert response.status_code == 422


async def test_trainer_without_clients(
    client: AsyncClient, owner: User, trainer: User, auth_headers: HeadersFactory
) -> None:
    item = await stats_for(client, owner, auth_headers, trainer)

    assert item["name"] == trainer.name
    assert item["client_count"] == 0
    assert item["tracked_days"] == 0
    assert item["adherence"] is None
    assert item["plan_coverage"] is None
    assert item["reply_rate"] is None
    assert item["progress_rate"] is None
    assert item["score"] is None
    assert item["stars"] is None
    assert item["average_rating"] is None
    assert item["rating_count"] == 0


async def test_seeded_numbers(
    client: AsyncClient,
    db_session: AsyncSession,
    owner: User,
    trainer: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    await seed_plan(db_session, "plan3", 3)
    planned = await make_user(role="user", trainer_id=trainer.id, plan_id="plan3", goal="lose")
    idle = await make_user(role="user", trainer_id=trainer.id)
    now = datetime.now(UTC)
    db_session.add_all(
        [
            Day(user_id=planned.id, day=today(), done=[1, 2, 3, 4]),
            Day(user_id=planned.id, day=today() - timedelta(days=1), done=[1]),
            Message(
                chat_uid=planned.id,
                sender_id=planned.id,
                text="salom",
                created_at=now - timedelta(hours=3),
            ),
            Message(
                chat_uid=planned.id,
                sender_id=trainer.id,
                text="javob",
                created_at=now - timedelta(hours=2),
            ),
            Message(
                chat_uid=idle.id,
                sender_id=idle.id,
                text="savol",
                created_at=now - timedelta(hours=1),
            ),
            Weight(user_id=planned.id, date=now - timedelta(days=20), weight=80),
            Weight(user_id=planned.id, date=now - timedelta(days=2), weight=78),
            Rating(trainer_id=trainer.id, stars=4),
        ]
    )
    await db_session.commit()

    item = await stats_for(client, owner, auth_headers, trainer)

    adherence = 4 / 21
    assert item["client_count"] == 2
    assert item["tracked_days"] == 7
    assert item["meals_done"] == 4
    assert item["meals_expected"] == 21
    assert item["adherence"] == pytest.approx(adherence)
    assert item["plan_coverage"] == pytest.approx(0.5)
    assert item["reply_rate"] == pytest.approx(0.5)
    assert item["progress_rate"] == pytest.approx(1.0)
    assert item["messages_sent"] == 1
    assert item["score"] == round((0.5 * 30 + 0.5 * 25 + adherence * 25 + 20) / 100 * 100)
    assert item["stars"] == 3
    assert item["average_rating"] == pytest.approx(4.0)
    assert item["rating_count"] == 1


async def test_recent_plan_limits_tracked_days(
    client: AsyncClient,
    db_session: AsyncSession,
    owner: User,
    trainer: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    await seed_plan(db_session, "plan2", 2)
    student = await make_user(
        role="user",
        trainer_id=trainer.id,
        plan_id="plan2",
        plan_assigned_at=datetime.now(UTC) - timedelta(days=1),
    )
    db_session.add_all(
        [
            Day(user_id=student.id, day=today(), done=[1, 2]),
            Day(user_id=student.id, day=today() - timedelta(days=1), done=[1]),
            Day(user_id=student.id, day=today() - timedelta(days=4), done=[1, 2]),
        ]
    )
    await db_session.commit()

    item = await stats_for(client, owner, auth_headers, trainer)

    assert item["tracked_days"] == 2
    assert item["meals_done"] == 3
    assert item["adherence"] == pytest.approx(3 / 4)


async def test_window_excludes_old_data(
    client: AsyncClient,
    db_session: AsyncSession,
    owner: User,
    trainer: User,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    await seed_plan(db_session, "plan2", 2)
    student = await make_user(role="user", trainer_id=trainer.id, plan_id="plan2")
    now = datetime.now(UTC)
    db_session.add_all(
        [
            Day(user_id=student.id, day=today() - timedelta(days=10), done=[1, 2]),
            Message(
                chat_uid=student.id,
                sender_id=trainer.id,
                text="eski",
                created_at=now - timedelta(days=10),
            ),
        ]
    )
    await db_session.commit()

    narrow = await stats_for(client, owner, auth_headers, trainer, days=7)
    wide = await stats_for(client, owner, auth_headers, trainer, days=30)

    assert narrow["meals_done"] == 0
    assert narrow["meals_expected"] == 14
    assert narrow["messages_sent"] == 0
    assert wide["meals_done"] == 2
    assert wide["meals_expected"] == 60
    assert wide["messages_sent"] == 1
