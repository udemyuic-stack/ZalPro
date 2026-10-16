from sqlalchemy import delete
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import PushToken


async def register_token(session: AsyncSession, user_id: str, token: str, platform: str) -> None:
    statement = insert(PushToken).values(user_id=user_id, token=token, platform=platform)
    await session.execute(
        statement.on_conflict_do_update(
            index_elements=[PushToken.token],
            set_={"user_id": user_id, "platform": platform},
        )
    )
    await session.commit()


async def remove_token(session: AsyncSession, user_id: str, token: str) -> None:
    await session.execute(
        delete(PushToken).where(PushToken.user_id == user_id, PushToken.token == token)
    )
    await session.commit()
