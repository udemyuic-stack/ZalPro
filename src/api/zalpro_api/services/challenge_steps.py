from collections.abc import Collection

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import bad_request, conflict, not_found
from zalpro_api.models import ChallengeStep, UserChallenge
from zalpro_api.schemas.challenge_step import ChallengeStepIn, ChallengeStepPatch


def ensure_known_exercise(exercise: str, known: Collection[str]) -> None:
    if exercise not in known:
        raise bad_request("unknown_exercise", "Mashq turi noma'lum")


async def list_steps(session: AsyncSession) -> list[ChallengeStep]:
    rows = await session.scalars(select(ChallengeStep).order_by(ChallengeStep.position))
    return list(rows)


async def create(
    session: AsyncSession, body: ChallengeStepIn, known: Collection[str]
) -> ChallengeStep:
    ensure_known_exercise(body.exercise, known)
    last = await session.scalar(select(func.max(ChallengeStep.position)))
    step = ChallengeStep(position=0 if last is None else last + 1, **body.model_dump())
    session.add(step)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise conflict("position_taken", "Qadam qo'shishda ziddiyat, qayta urining") from None
    return step


async def update(
    session: AsyncSession, step_id: str, body: ChallengeStepPatch, known: Collection[str]
) -> ChallengeStep:
    step = await session.get(ChallengeStep, step_id)
    if step is None:
        raise not_found("Qadam topilmadi")
    changes = body.model_dump(exclude_unset=True)
    if "exercise" in changes:
        ensure_known_exercise(changes["exercise"], known)
    for field, value in changes.items():
        setattr(step, field, value)
    await session.commit()
    return step


async def delete(session: AsyncSession, step_id: str) -> None:
    step = await session.get(ChallengeStep, step_id)
    if step is None:
        raise not_found("Qadam topilmadi")
    last = await session.scalar(select(func.max(ChallengeStep.position)))
    if step.position != last:
        raise conflict("not_last_step", "Faqat oxirgi qadamni o'chirish mumkin")
    reached = await session.scalar(
        select(func.count()).select_from(UserChallenge).where(UserChallenge.step >= step.position)
    )
    if reached:
        raise conflict("step_reached", "Foydalanuvchilar bu qadamga yetgan")
    await session.delete(step)
    await session.commit()
