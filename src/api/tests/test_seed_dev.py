import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from scripts.seed_dev import ACCOUNTS, assert_local_database, seed
from zalpro_api.models import Food, Gym, Plan, Product, Trainer, User
from zalpro_api.services.phone import normalize_phone


async def count(session: AsyncSession, model: type) -> int:
    return await session.scalar(select(func.count()).select_from(model)) or 0


async def test_seed_is_idempotent_and_fills_rows(db_session: AsyncSession) -> None:
    await seed(db_session)
    await seed(db_session)

    assert await count(db_session, Gym) == 2
    assert await count(db_session, User) == len(ACCOUNTS)
    assert await count(db_session, Trainer) == 2
    assert await count(db_session, Plan) == 1
    assert await count(db_session, Food) == 1
    assert await count(db_session, Product) == 1

    users = {user.phone: user for user in (await db_session.scalars(select(User))).all()}
    assert all(normalize_phone(phone) == phone and len(phone) == 12 for phone in users)
    roles = sorted(user.role for user in users.values())
    assert roles == ["admin", "admin", "barmen", "owner", "user", "user", "user"]

    trainers = {spec.phone: users[spec.phone] for spec in ACCOUNTS if spec.role == "admin"}
    students = [users[spec.phone] for spec in ACCOUNTS if spec.role == "user"]
    first_trainer, second_trainer = trainers.values()
    assert [student.trainer_id for student in students] == [
        first_trainer.id,
        first_trainer.id,
        second_trainer.id,
    ]
    assert students[0].goal and students[0].weight > 0
    assert students[2].weight == 0
    assert students[2].goal is None
    assert all(trainer.gym_id for trainer in trainers.values())
    assert all(t.accepting for t in (await db_session.scalars(select(Trainer))).all())


@pytest.mark.parametrize(
    "url",
    ["postgresql+asyncpg://u:p@db.example.com:5432/x", "postgresql+asyncpg://u:p@10.0.0.5/x"],
)
def test_refuses_non_local_database(url: str) -> None:
    with pytest.raises(SystemExit):
        assert_local_database(url)


def test_accepts_local_database() -> None:
    assert_local_database("postgresql+asyncpg://u:p@127.0.0.1:5433/x")
    assert_local_database("postgresql+asyncpg://u:p@localhost/x")


def test_accepts_explicitly_allowed_host() -> None:
    assert_local_database("postgresql+asyncpg://u:p@db.example.com/x", "db.example.com")


def test_allowed_host_must_match() -> None:
    with pytest.raises(SystemExit):
        assert_local_database("postgresql+asyncpg://u:p@db.example.com/x", "other.example.com")
