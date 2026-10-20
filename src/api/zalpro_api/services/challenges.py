from dataclasses import dataclass

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

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


CHALLENGES = (
    ChallengeStep("pullup", 20, 20, "arms"),
    ChallengeStep("pushup", 10, 15, "chest"),
    ChallengeStep("squat", 20, 15, "legs"),
    ChallengeStep("pullup", 30, 30, "arms"),
    ChallengeStep("pushup", 25, 30, "chest"),
    ChallengeStep("squat", 50, 30, "legs"),
    ChallengeStep("pullup", 50, 50, "arms"),
    ChallengeStep("pushup", 50, 50, "chest"),
    ChallengeStep("squat", 100, 50, "legs"),
    ChallengeStep("pullup", 100, 100, "arms"),
    ChallengeStep("pushup", 100, 100, "chest"),
    ChallengeStep("squat", 200, 100, "legs"),
)


def muscle_levels(step: int) -> MuscleLevelsOut:
    done = CHALLENGES[: min(step, len(CHALLENGES))]
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
    if state.step >= len(CHALLENGES):
        return None
    current = CHALLENGES[state.step]
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
        finished=state.step >= len(CHALLENGES),
    )


async def read(session: AsyncSession, user_id: str) -> ChallengesOut:
    state = await session.get(UserChallenge, user_id)
    step = state.step if state else 0
    progress = state.progress if state else 0
    return ChallengesOut(
        step=step,
        progress=progress,
        finished=step >= len(CHALLENGES),
        muscles=muscle_levels(step),
        steps=[
            ChallengeStepOut(
                index=i,
                exercise=item.exercise,
                target=item.target,
                coins=item.coins,
                muscle=item.muscle,
                state="done" if i < step else "current" if i == step else "locked",
            )
            for i, item in enumerate(CHALLENGES)
        ],
    )
