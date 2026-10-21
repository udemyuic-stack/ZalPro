from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import ChallengeStep as ChallengeStepRow
from zalpro_api.models import CoinLedger, UserChallenge
from zalpro_api.schemas.game import (
    ChallengeResultOut,
    ChallengesOut,
    ChallengeStepOut,
    MuscleLevelsOut,
)


@dataclass(frozen=True)
class ChallengeStep:
    exercise: str
    target: int
    coins: int
    muscle: str


async def load_ladder(session: AsyncSession) -> list[ChallengeStep]:
    rows = await session.scalars(select(ChallengeStepRow).order_by(ChallengeStepRow.position))
    return [ChallengeStep(row.exercise, row.target, row.coins, row.muscle) for row in rows]


def muscle_levels(ladder: list[ChallengeStep], step: int) -> MuscleLevelsOut:
    done = ladder[: min(step, len(ladder))]
    return MuscleLevelsOut(
        arms=sum(1 for item in done if item.muscle == "arms"),
        chest=sum(1 for item in done if item.muscle == "chest"),
        legs=sum(1 for item in done if item.muscle == "legs"),
    )


async def lock_state(session: AsyncSession, user_id: str) -> UserChallenge:
    await session.execute(
        insert(UserChallenge)
        .values(user_id=user_id)
        .on_conflict_do_nothing(index_elements=["user_id"])
    )
    return (
        await session.execute(
            select(UserChallenge).where(UserChallenge.user_id == user_id).with_for_update()
        )
    ).scalar_one()


async def apply_session(
    session: AsyncSession, user_id: str, exercise: str, reps: int, session_id: str
) -> ChallengeResultOut | None:
    state = await lock_state(session, user_id)
    ladder = await load_ladder(session)
    if state.step >= len(ladder):
        return None
    current = ladder[state.step]
    if current.exercise != exercise:
        return None
    index = state.step
    progress = min(current.target, state.progress + reps)
    completed = progress >= current.target
    if completed:
        session.add(
            CoinLedger(user_id=user_id, delta=current.coins, reason="challenge", ref_id=session_id)
        )
        state.step = index + 1
        state.progress = 0
    else:
        state.progress = progress
    return ChallengeResultOut(
        step=index,
        exercise=current.exercise,
        target=current.target,
        progress=progress,
        completed=completed,
        coins=current.coins if completed else 0,
        muscle=current.muscle,
        finished=state.step >= len(ladder),
    )


async def read(session: AsyncSession, user_id: str) -> ChallengesOut:
    ladder = await load_ladder(session)
    state = await session.get(UserChallenge, user_id)
    step = state.step if state else 0
    progress = state.progress if state else 0
    return ChallengesOut(
        step=step,
        progress=progress,
        finished=step >= len(ladder),
        muscles=muscle_levels(ladder, step),
        steps=[
            ChallengeStepOut(
                index=i,
                exercise=item.exercise,
                target=item.target,
                coins=item.coins,
                muscle=item.muscle,
                state="done" if i < step else "current" if i == step else "locked",
            )
            for i, item in enumerate(ladder)
        ],
    )
