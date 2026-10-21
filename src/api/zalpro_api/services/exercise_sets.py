from datetime import date

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import ExerciseSet
from zalpro_api.schemas.exercise_set import ExerciseSetIn, ExerciseSetOut, ExerciseSetsOut


def to_out(day: date, exercise_id: str, rows: list[ExerciseSet]) -> ExerciseSetsOut:
    return ExerciseSetsOut(
        day=day,
        exercise_id=exercise_id,
        sets=[
            ExerciseSetOut(
                set_no=row.set_no,
                weight_kg=None if row.weight_kg is None else float(row.weight_kg),
                reps=row.reps,
            )
            for row in rows
        ],
    )


async def get_sets(
    session: AsyncSession, user_id: str, day: date, exercise_id: str
) -> ExerciseSetsOut:
    statement = (
        select(ExerciseSet)
        .where(
            ExerciseSet.user_id == user_id,
            ExerciseSet.day == day,
            ExerciseSet.exercise_id == exercise_id,
        )
        .order_by(ExerciseSet.set_no)
    )
    rows = list((await session.scalars(statement)).all())
    return to_out(day, exercise_id, rows)


async def replace_sets(
    session: AsyncSession, user_id: str, day: date, exercise_id: str, sets: list[ExerciseSetIn]
) -> ExerciseSetsOut:
    await session.execute(
        delete(ExerciseSet).where(
            ExerciseSet.user_id == user_id,
            ExerciseSet.day == day,
            ExerciseSet.exercise_id == exercise_id,
        )
    )
    rows = [
        ExerciseSet(
            user_id=user_id,
            day=day,
            exercise_id=exercise_id,
            set_no=item.set_no,
            weight_kg=item.weight_kg,
            reps=item.reps,
        )
        for item in sorted(sets, key=lambda item: item.set_no)
    ]
    session.add_all(rows)
    await session.commit()
    return await get_sets(session, user_id, day, exercise_id)


async def previous_sets(
    session: AsyncSession, user_id: str, before: date, exercise_id: str
) -> ExerciseSetsOut:
    latest = await session.scalar(
        select(ExerciseSet.day)
        .where(
            ExerciseSet.user_id == user_id,
            ExerciseSet.exercise_id == exercise_id,
            ExerciseSet.day < before,
        )
        .order_by(ExerciseSet.day.desc())
        .limit(1)
    )
    if latest is None:
        return ExerciseSetsOut(day=before, exercise_id=exercise_id, sets=[])
    return await get_sets(session, user_id, latest, exercise_id)
