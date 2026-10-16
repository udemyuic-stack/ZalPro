from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import not_found
from zalpro_api.models import Exercise, Food, Plan


async def get_food_or_404(session: AsyncSession, food_id: str) -> Food:
    food = await session.get(Food, food_id)
    if food is None:
        raise not_found("Mahsulot topilmadi")
    return food


async def get_plan_or_404(session: AsyncSession, plan_id: str) -> Plan:
    plan = await session.get(Plan, plan_id)
    if plan is None:
        raise not_found("Reja topilmadi")
    return plan


async def get_exercise_or_404(session: AsyncSession, exercise_id: str) -> Exercise:
    exercise = await session.get(Exercise, exercise_id)
    if exercise is None:
        raise not_found("Mashq topilmadi")
    return exercise
