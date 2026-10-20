from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from scripts.catalog_data import EXERCISES, FOODS, PLANS, PRODUCTS
from scripts.seed_catalog import seed
from zalpro_api.models import Exercise, Food, Plan, Product
from zalpro_api.models.exercise import MUSCLES


async def count(session: AsyncSession, model: type) -> int:
    return await session.scalar(select(func.count()).select_from(model)) or 0


async def test_catalog_seed_is_idempotent(db_session: AsyncSession) -> None:
    first = await seed(db_session)
    second = await seed(db_session)

    assert first == {
        "foods": len(FOODS),
        "products": len(PRODUCTS),
        "plans": len(PLANS),
        "exercises": len(EXERCISES),
    }
    assert set(second.values()) == {0}
    assert await count(db_session, Food) == len(FOODS)
    assert await count(db_session, Product) == len(PRODUCTS)
    assert await count(db_session, Plan) == len(PLANS)
    assert await count(db_session, Exercise) == len(EXERCISES)


def test_catalog_rows_are_valid() -> None:
    assert len({row[0] for row in FOODS}) == len(FOODS)
    assert len({row[0] for row in EXERCISES}) == len(EXERCISES)
    assert all(row[1] in MUSCLES and set(row[4]) <= set(MUSCLES) for row in EXERCISES)
