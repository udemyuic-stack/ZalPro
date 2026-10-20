import asyncio
import os
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from scripts.catalog_data import EXERCISES, FOODS, PLANS, PRODUCTS
from scripts.seed_dev import assert_local_database
from zalpro_api.core.config import Settings
from zalpro_api.db.session import create_engine, create_sessionmaker
from zalpro_api.models import Exercise, Food, Plan, Product

CREATED_BY = "seed_catalog"


def new_id() -> str:
    return uuid.uuid4().hex


async def seed_foods(session: AsyncSession) -> int:
    known = set(await session.scalars(select(Food.name)))
    fresh = [row for row in FOODS if row[0] not in known]
    for name, kcal, protein, fat, carbs in fresh:
        session.add(Food(id=new_id(), name=name, kcal=kcal, protein=protein, fat=fat, carbs=carbs))
    return len(fresh)


async def seed_products(session: AsyncSession) -> int:
    known = set(await session.scalars(select(Product.name)))
    fresh = [row for row in PRODUCTS if row[1] not in known]
    for category, name, note, price, cost_price, stock in fresh:
        session.add(
            Product(
                id=new_id(),
                category=category,
                name=name,
                note=note,
                price=price,
                cost_price=cost_price,
                stock=stock,
            )
        )
    return len(fresh)


async def seed_plans(session: AsyncSession) -> int:
    known = set(await session.scalars(select(Plan.title)))
    fresh = [plan for plan in PLANS if plan["title"] not in known]
    for plan in fresh:
        session.add(
            Plan(
                id=new_id(),
                title=plan["title"],
                note=plan["note"],
                forbidden=plan["forbidden"],
                meals=plan["meals"],
                week={str(day): plan["meals"] for day in range(1, 8)},
            )
        )
    return len(fresh)


async def seed_exercises(session: AsyncSession) -> int:
    known = set(await session.scalars(select(Exercise.base).where(Exercise.base != "")))
    fresh = [row for row in EXERCISES if row[0] not in known]
    for name, muscle, sets, tip, also in fresh:
        session.add(
            Exercise(
                id=new_id(),
                name=name,
                muscle=muscle,
                sets=sets,
                tip=tip,
                also=list(also),
                created_by=CREATED_BY,
                base=name,
            )
        )
    return len(fresh)


async def seed(session: AsyncSession) -> dict[str, int]:
    added = {
        "foods": await seed_foods(session),
        "products": await seed_products(session),
        "plans": await seed_plans(session),
        "exercises": await seed_exercises(session),
    }
    await session.commit()
    return added


async def main() -> None:
    settings = Settings()
    assert_local_database(settings.database_url, os.environ.get("SEED_ALLOW_HOST"))
    engine = create_engine(settings.database_url)
    try:
        async with create_sessionmaker(engine)() as session:
            added = await seed(session)
    finally:
        await engine.dispose()
    for table, count in added.items():
        print(f"{table:<10}{count} ta qo'shildi")


if __name__ == "__main__":
    asyncio.run(main())
