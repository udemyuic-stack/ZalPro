import uuid
from typing import Any

from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import ApiError, conflict, not_found
from zalpro_api.models import Gym, Plan, Trainer, User
from zalpro_api.services import permissions

MAX_TRAINER_NAME_LENGTH = 60


async def get_user_or_404(session: AsyncSession, user_id: str) -> User:
    user = await session.get(User, user_id)
    if user is None:
        raise not_found("Foydalanuvchi topilmadi")
    return user


async def get_trainer_or_404(session: AsyncSession, trainer_id: str) -> Trainer:
    trainer = await session.get(Trainer, trainer_id)
    if trainer is None:
        raise not_found("Trener topilmadi")
    return trainer


async def get_gym_or_404(session: AsyncSession, gym_id: str) -> Gym:
    gym = await session.get(Gym, gym_id)
    if gym is None:
        raise not_found("Zal topilmadi")
    return gym


async def ensure_plan_exists(session: AsyncSession, plan_id: str | None) -> None:
    if plan_id is not None and await session.get(Plan, plan_id) is None:
        raise ApiError(404, "plan_not_found", "Reja topilmadi")


async def persist_new_user(session: AsyncSession, user: User) -> None:
    try:
        await session.flush()
        if user.role == "admin":
            await ensure_trainer_entry(session, user)
        await session.commit()
    except IntegrityError as error:
        await session.rollback()
        raise conflict("phone_taken", "Bu telefon raqami band") from error


async def create_user(
    session: AsyncSession,
    *,
    name: str,
    phone: str,
    password_hash: str,
    role: str = "user",
    gym_id: str | None = None,
) -> User:
    if gym_id is not None:
        await get_gym_or_404(session, gym_id)
    user = User(
        id=uuid.uuid4().hex,
        name=name,
        phone=phone,
        password_hash=password_hash,
        role=role,
        gym_id=gym_id,
    )
    session.add(user)
    await persist_new_user(session, user)
    return user


async def ensure_trainer_entry(session: AsyncSession, user: User) -> None:
    if await session.get(Trainer, user.id) is not None:
        return
    name = (user.name or user.phone)[:MAX_TRAINER_NAME_LENGTH]
    session.add(Trainer(id=user.id, name=name, bio="", accepting=True, gym_id=user.gym_id))


async def apply_role(session: AsyncSession, user: User, role: str) -> None:
    user.role = role
    if role == "admin":
        await session.flush()
        await ensure_trainer_entry(session, user)
        return
    await session.execute(delete(Trainer).where(Trainer.id == user.id))
    await session.execute(update(User).where(User.trainer_id == user.id).values(trainer_id=None))


async def apply_gym(session: AsyncSession, user: User, gym_id: str | None) -> None:
    if gym_id is not None:
        await get_gym_or_404(session, gym_id)
    user.gym_id = gym_id
    await session.execute(update(Trainer).where(Trainer.id == user.id).values(gym_id=gym_id))


async def apply_trainer(session: AsyncSession, user: User, trainer_id: str | None) -> None:
    if trainer_id is not None:
        await get_trainer_or_404(session, trainer_id)
    user.trainer_id = trainer_id


async def apply_user_changes(session: AsyncSession, user: User, changes: dict[str, Any]) -> None:
    remaining = dict(changes)
    if "plan_id" in remaining:
        await ensure_plan_exists(session, remaining["plan_id"])
    if "role" in remaining:
        await apply_role(session, user, remaining.pop("role"))
    if "gym_id" in remaining:
        await apply_gym(session, user, remaining.pop("gym_id"))
    if "trainer_id" in remaining:
        await apply_trainer(session, user, remaining.pop("trainer_id"))
    for field, value in remaining.items():
        setattr(user, field, value)


async def delete_user(session: AsyncSession, user_id: str) -> None:
    await session.execute(delete(User).where(User.id == user_id))


async def list_users(
    session: AsyncSession,
    actor: User,
    *,
    roles: list[str],
    trainer_id: str | None,
    gym_id: str | None,
    limit: int,
    offset: int,
) -> list[User]:
    scope = permissions.user_list_scope(actor)
    statement = select(User)
    if scope == "own_students":
        statement = statement.where(User.trainer_id == actor.id)
    elif scope == "staff_directory":
        statement = statement.where(User.role.in_(permissions.STAFF_DIRECTORY_ROLES))
    if roles:
        statement = statement.where(User.role.in_(roles))
    if trainer_id is not None:
        statement = statement.where(User.trainer_id == trainer_id)
    if gym_id is not None:
        statement = statement.where(User.gym_id == gym_id)
    statement = statement.order_by(User.created_at, User.id).limit(limit).offset(offset)
    return list((await session.scalars(statement)).all())
