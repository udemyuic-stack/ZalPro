from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import not_found
from zalpro_api.models import Membership


async def get_membership_or_404(session: AsyncSession, user_id: str) -> Membership:
    membership = await session.get(Membership, user_id)
    if membership is None:
        raise not_found("Abonement ko'zgusi topilmadi")
    return membership


async def list_memberships(session: AsyncSession, gym_scope: str | None) -> list[Membership]:
    if gym_scope == "":
        return []
    statement = select(Membership).order_by(Membership.expires_at, Membership.user_id)
    if gym_scope is not None:
        statement = statement.where(Membership.gym_id == gym_scope)
    return list((await session.scalars(statement)).all())


async def delete_membership(session: AsyncSession, user_id: str) -> None:
    result = await session.execute(delete(Membership).where(Membership.user_id == user_id))
    if result.rowcount == 0:
        raise not_found("Abonement ko'zgusi topilmadi")
    await session.commit()
