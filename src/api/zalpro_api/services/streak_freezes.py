from datetime import date, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.errors import conflict, not_found
from zalpro_api.models import StreakFreeze
from zalpro_api.schemas.streak_freeze import StreakFreezeOut
from zalpro_api.services.subscriptions import gym_zone

MONTHLY_FREEZE_LIMIT = 2


def week_start_of(day: date) -> date:
    return day - timedelta(days=day.weekday())


async def list_streak_freezes(
    session: AsyncSession, user_id: str, start: date, end: date
) -> list[StreakFreezeOut]:
    statement = (
        select(StreakFreeze)
        .where(StreakFreeze.user_id == user_id, StreakFreeze.week_start.between(start, end))
        .order_by(StreakFreeze.week_start)
    )
    return [StreakFreezeOut.model_validate(row) for row in (await session.scalars(statement)).all()]


async def grant_streak_freeze(
    session: AsyncSession, settings: Settings, user_id: str, week_start: date, granted_by: str
) -> StreakFreezeOut:
    today = datetime.now(gym_zone(settings)).date()
    if week_start >= week_start_of(today):
        raise conflict("freeze_not_allowed", "Faqat o'tgan to'liq hafta muzlatiladi")
    month_start = week_start.replace(day=1)
    next_month = (month_start + timedelta(days=32)).replace(day=1)
    used = await session.scalar(
        select(func.count())
        .select_from(StreakFreeze)
        .where(
            StreakFreeze.user_id == user_id,
            StreakFreeze.week_start >= month_start,
            StreakFreeze.week_start < next_month,
        )
    )
    if (used or 0) >= MONTHLY_FREEZE_LIMIT:
        raise conflict("freeze_limit_reached", "Bu oy uchun muzlatishlar limiti tugagan")
    row = StreakFreeze(user_id=user_id, week_start=week_start, granted_by=granted_by)
    session.add(row)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise conflict("freeze_exists", "Bu hafta allaqachon muzlatilgan") from None
    return StreakFreezeOut.model_validate(row)


async def revoke_streak_freeze(session: AsyncSession, user_id: str, week_start: date) -> None:
    row = await session.get(StreakFreeze, (user_id, week_start))
    if row is None:
        raise not_found("Muzlatish topilmadi")
    await session.delete(row)
    await session.commit()
