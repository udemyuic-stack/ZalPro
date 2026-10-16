import uuid
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import conflict, not_found
from zalpro_api.models import User, Weight
from zalpro_api.services.permissions import WEIGH_IN_MIN_INTERVAL


async def record_weight(session: AsyncSession, user_id: str, weight: float) -> Weight:
    now = datetime.now(UTC)
    statement = (
        select(User)
        .where(User.id == user_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    user = await session.scalar(statement)
    if user is None:
        raise not_found("Foydalanuvchi topilmadi")
    if user.last_weigh_in is not None:
        next_allowed = user.last_weigh_in + WEIGH_IN_MIN_INTERVAL
        if now <= next_allowed:
            raise conflict(
                "weigh_in_too_soon",
                f"Keyingi o'lchov {next_allowed.isoformat()} dan keyin mumkin",
            )
    entry = Weight(id=uuid.uuid4(), user_id=user_id, date=now, weight=weight)
    session.add(entry)
    user.weight = weight
    user.last_weigh_in = now
    await session.commit()
    return entry


async def list_weights(session: AsyncSession, user_id: str, limit: int) -> list[Weight]:
    statement = (
        select(Weight)
        .where(Weight.user_id == user_id)
        .order_by(Weight.date.desc(), Weight.id.desc())
        .limit(limit)
    )
    return list(reversed((await session.scalars(statement)).all()))
