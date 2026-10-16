import asyncio
import os
import sys
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.security import hash_password
from zalpro_api.db.session import create_engine, create_sessionmaker
from zalpro_api.models import Food, Gym, Plan, Product, Trainer, User

OWNER_PASSWORD = "Owner-Dev-4827"
TRAINER_ONE_PASSWORD = "Trainer1-Dev-5193"
TRAINER_TWO_PASSWORD = "Trainer2-Dev-6254"
BARMEN_PASSWORD = "Barmen-Dev-7315"
STUDENT_ONE_PASSWORD = "Student1-Dev-8426"
STUDENT_TWO_PASSWORD = "Student2-Dev-9537"
STUDENT_THREE_PASSWORD = "Student3-Dev-1648"

LOCAL_HOSTS = frozenset({"localhost", "127.0.0.1", "::1"})

GYM_ONE_NAME = "Diamond Chilonzor"
GYM_TWO_NAME = "Diamond Yunusobod"
PLAN_TITLE = "Dev: Massa nabor"
FOOD_NAME = "Dev: Tovuq ko'kragi"
PRODUCT_NAME = "Dev: Protein 2 kg"

COMPLETE_PROFILE: dict[str, Any] = {
    "gender": "male",
    "age": 25,
    "height": 178.0,
    "weight": 78.0,
    "activity": 1.55,
    "metabolism": "fast",
    "goal": "gain",
}


@dataclass(frozen=True)
class AccountSpec:
    phone: str
    name: str
    role: str
    password: str
    gym: str | None = None
    trainer_phone: str | None = None
    assign_plan: bool = False
    profile: dict[str, Any] = field(default_factory=dict)


ACCOUNTS: tuple[AccountSpec, ...] = (
    AccountSpec("998900000001", "Dev Owner", "owner", OWNER_PASSWORD),
    AccountSpec("998900000002", "Dev Trener Bir", "admin", TRAINER_ONE_PASSWORD, GYM_ONE_NAME),
    AccountSpec("998900000003", "Dev Trener Ikki", "admin", TRAINER_TWO_PASSWORD, GYM_TWO_NAME),
    AccountSpec("998900000004", "Dev Barmen", "barmen", BARMEN_PASSWORD, GYM_ONE_NAME),
    AccountSpec(
        "998900000005",
        "Dev Shogird Bir",
        "user",
        STUDENT_ONE_PASSWORD,
        GYM_ONE_NAME,
        "998900000002",
        True,
        COMPLETE_PROFILE,
    ),
    AccountSpec(
        "998900000006",
        "Dev Shogird Ikki",
        "user",
        STUDENT_TWO_PASSWORD,
        GYM_ONE_NAME,
        "998900000002",
        False,
        {**COMPLETE_PROFILE, "gender": "female", "age": 30, "weight": 62.0, "goal": "lose"},
    ),
    AccountSpec(
        "998900000007",
        "Dev Shogird Uch",
        "user",
        STUDENT_THREE_PASSWORD,
        GYM_TWO_NAME,
        "998900000003",
    ),
)


def new_id() -> str:
    return uuid.uuid4().hex


def assert_local_database(database_url: str, allowed_host: str | None = None) -> None:
    host = make_url(database_url).host
    if host in LOCAL_HOSTS or (allowed_host and host == allowed_host):
        return
    raise SystemExit(
        f"Refusing to seed: database host {host!r} is not local "
        f"(allowed: {', '.join(sorted(LOCAL_HOSTS))}) and does not match SEED_ALLOW_HOST."
    )


async def get_or_create_gym(session: AsyncSession, name: str, address: str) -> Gym:
    gym = await session.scalar(select(Gym).where(Gym.name == name))
    if gym is None:
        gym = Gym(
            id=new_id(),
            name=name,
            address=address,
            country="O'zbekiston",
            region="Toshkent",
            district=name.removeprefix("Diamond "),
        )
        session.add(gym)
        await session.flush()
    return gym


async def get_or_create_plan(session: AsyncSession) -> Plan:
    plan = await session.scalar(select(Plan).where(Plan.title == PLAN_TITLE))
    if plan is None:
        meal = {
            "time": "08:00",
            "title": "Nonushta",
            "items": [{"name": "Suli bo'tqasi", "grams": 80, "kcal": 300, "protein": 10}],
        }
        plan = Plan(
            id=new_id(),
            title=PLAN_TITLE,
            note="Ko'p suv iching",
            forbidden=["shakar", "gazli ichimlik"],
            meals=[meal],
            week={"1": [meal]},
        )
        session.add(plan)
        await session.flush()
    return plan


async def ensure_food(session: AsyncSession) -> None:
    if await session.scalar(select(Food.id).where(Food.name == FOOD_NAME)) is None:
        session.add(Food(id=new_id(), name=FOOD_NAME, kcal=165, protein=31, fat=3.6, carbs=0))


async def ensure_product(session: AsyncSession) -> None:
    if await session.scalar(select(Product.id).where(Product.name == PRODUCT_NAME)) is None:
        session.add(
            Product(
                id=new_id(),
                category="Protein",
                name=PRODUCT_NAME,
                note="Dev uchun sinov mahsuloti",
                price=350000,
                cost_price=280000,
                stock=20,
            )
        )


async def get_or_create_user(
    session: AsyncSession,
    spec: AccountSpec,
    gyms: dict[str, Gym],
    plan: Plan,
    users: dict[str, User],
) -> User:
    user = await session.scalar(select(User).where(User.phone == spec.phone))
    if user is not None:
        return user
    trainer = users[spec.trainer_phone] if spec.trainer_phone else None
    user = User(
        id=new_id(),
        name=spec.name,
        phone=spec.phone,
        password_hash=await hash_password(spec.password),
        role=spec.role,
        gym_id=gyms[spec.gym].id if spec.gym else None,
        trainer_id=trainer.id if trainer else None,
        plan_id=plan.id if spec.assign_plan else None,
        plan_assigned_at=datetime.now(UTC) if spec.assign_plan else None,
        **spec.profile,
    )
    session.add(user)
    await session.flush()
    return user


async def ensure_trainer(session: AsyncSession, user: User) -> None:
    if await session.get(Trainer, user.id) is None:
        session.add(
            Trainer(
                id=user.id,
                name=user.name,
                bio="Dev trener",
                accepting=True,
                gym_id=user.gym_id,
            )
        )


async def seed(session: AsyncSession) -> list[AccountSpec]:
    gyms = {
        GYM_ONE_NAME: await get_or_create_gym(session, GYM_ONE_NAME, "Chilonzor 9-kvartal"),
        GYM_TWO_NAME: await get_or_create_gym(session, GYM_TWO_NAME, "Yunusobod 4-kvartal"),
    }
    plan = await get_or_create_plan(session)
    await ensure_food(session)
    await ensure_product(session)
    users: dict[str, User] = {}
    for spec in ACCOUNTS:
        user = await get_or_create_user(session, spec, gyms, plan, users)
        users[spec.phone] = user
        if spec.role == "admin":
            await ensure_trainer(session, user)
    await session.commit()
    return list(ACCOUNTS)


def print_accounts(accounts: list[AccountSpec]) -> None:
    print(f"{'phone':<14}{'role':<8}password")
    for account in accounts:
        print(f"{account.phone:<14}{account.role:<8}{account.password}")


async def main() -> None:
    settings = Settings()
    assert_local_database(settings.database_url, os.environ.get("SEED_ALLOW_HOST"))
    engine = create_engine(settings.database_url)
    try:
        async with create_sessionmaker(engine)() as session:
            accounts = await seed(session)
    finally:
        await engine.dispose()
    print_accounts(accounts)


if __name__ == "__main__":
    asyncio.run(main())
