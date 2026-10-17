import json
from datetime import date
from typing import Any

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import conflict
from zalpro_api.models import Day
from zalpro_api.schemas.day import MAX_EXTRAS, MAX_GYM_DONE, DayOut, ExtraIn

RETURNING = "returning day, done, extras, gym_started, gym_done, water, feedback"

ADD_MEAL = text(
    f"""
    insert into days (user_id, day, done)
    values (:user_id, cast(:day as date), array[cast(:index as integer)])
    on conflict (user_id, day) do update set done = (
        select coalesce(array_agg(distinct value order by value), '{{}}')
        from unnest(array_append(days.done, cast(:index as integer))) as value
    )
    {RETURNING}
    """
)

REMOVE_MEAL = text(
    f"""
    insert into days (user_id, day) values (:user_id, cast(:day as date))
    on conflict (user_id, day) do update
    set done = array_remove(days.done, cast(:index as integer))
    {RETURNING}
    """
)

ADD_EXTRA = text(
    f"""
    insert into days (user_id, day, extras)
    values (:user_id, cast(:day as date), jsonb_build_array(cast(cast(:extra as text) as jsonb)))
    on conflict (user_id, day) do update
    set extras = days.extras || jsonb_build_array(cast(cast(:extra as text) as jsonb))
    where jsonb_array_length(days.extras) < {MAX_EXTRAS}
        and not exists (
            select 1 from jsonb_array_elements(days.extras) as item
            where item ->> 'at' = cast(:at as text)
        )
    {RETURNING}
    """
)

REMOVE_EXTRA = text(
    f"""
    update days
    set extras = coalesce(
        (
            select jsonb_agg(item order by ord)
            from jsonb_array_elements(days.extras) with ordinality as entry(item, ord)
            where item ->> 'at' <> cast(:at as text)
        ),
        '[]'::jsonb
    )
    where user_id = :user_id and day = cast(:day as date)
    {RETURNING}
    """
)

START_WORKOUT = text(
    f"""
    insert into days (user_id, day, gym_started)
    values (:user_id, cast(:day as date), true)
    on conflict (user_id, day) do update set gym_started = true
    {RETURNING}
    """
)

ADD_EXERCISE = text(
    f"""
    insert into days (user_id, day, gym_started, gym_done)
    values (:user_id, cast(:day as date), true, array[cast(:key as text)])
    on conflict (user_id, day) do update
    set gym_started = true,
        gym_done = case
            when days.gym_done @> array[cast(:key as text)] then days.gym_done
            else array_append(days.gym_done, cast(:key as text))
        end
    where days.gym_done @> array[cast(:key as text)]
        or coalesce(cardinality(days.gym_done), 0) < {MAX_GYM_DONE}
    {RETURNING}
    """
)

REMOVE_EXERCISE = text(
    f"""
    insert into days (user_id, day, gym_started) values (:user_id, cast(:day as date), true)
    on conflict (user_id, day) do update
    set gym_started = true, gym_done = array_remove(days.gym_done, cast(:key as text))
    {RETURNING}
    """
)

SET_FEEDBACK = text(
    f"""
    insert into days (user_id, day, feedback)
    values (:user_id, cast(:day as date), cast(:rating as smallint))
    on conflict (user_id, day) do update set feedback = cast(:rating as smallint)
    {RETURNING}
    """
)

SET_WATER = text(
    f"""
    insert into days (user_id, day, water)
    values (:user_id, cast(:day as date), cast(:glasses as integer))
    on conflict (user_id, day) do update set water = cast(:glasses as integer)
    {RETURNING}
    """
)


def empty_day(day: date) -> DayOut:
    return DayOut(
        day=day, done=[], extras=[], gym_started=False, gym_done=[], water=0, feedback=None
    )


async def _run(session: AsyncSession, statement: Any, **params: Any) -> DayOut | None:
    row = (await session.execute(statement, params)).mappings().first()
    await session.commit()
    return None if row is None else DayOut.model_validate(dict(row))


async def _run_upsert(session: AsyncSession, statement: Any, **params: Any) -> DayOut:
    row = (await session.execute(statement, params)).mappings().one()
    await session.commit()
    return DayOut.model_validate(dict(row))


async def get_day(session: AsyncSession, user_id: str, day: date) -> DayOut:
    row = await session.get(Day, (user_id, day))
    if row is None:
        return empty_day(day)
    return DayOut.model_validate(row)


async def list_days(session: AsyncSession, user_id: str, start: date, end: date) -> list[DayOut]:
    statement = (
        select(Day).where(Day.user_id == user_id, Day.day.between(start, end)).order_by(Day.day)
    )
    return [DayOut.model_validate(row) for row in (await session.scalars(statement)).all()]


async def set_meal(
    session: AsyncSession, user_id: str, day: date, index: int, done: bool
) -> DayOut:
    statement = ADD_MEAL if done else REMOVE_MEAL
    return await _run_upsert(session, statement, user_id=user_id, day=day, index=index)


async def add_extra(session: AsyncSession, user_id: str, day: date, extra: ExtraIn) -> DayOut:
    result = await _run(
        session,
        ADD_EXTRA,
        user_id=user_id,
        day=day,
        extra=json.dumps(extra.model_dump()),
        at=str(extra.at),
    )
    if result is not None:
        return result
    current = await get_day(session, user_id, day)
    if any(item.at == extra.at for item in current.extras):
        raise conflict("extra_exists", "Bu vaqtdagi qo'shimcha ovqat allaqachon mavjud")
    if len(current.extras) >= MAX_EXTRAS:
        raise conflict("extras_limit", "Kunlik qo'shimcha ovqatlar soni to'lgan")
    raise conflict("extra_conflict", "Kun bir vaqtda o'zgardi, qayta urinib ko'ring")


async def remove_extra(session: AsyncSession, user_id: str, day: date, at: int) -> DayOut:
    result = await _run(session, REMOVE_EXTRA, user_id=user_id, day=day, at=str(at))
    return empty_day(day) if result is None else result


async def start_workout(session: AsyncSession, user_id: str, day: date) -> DayOut:
    return await _run_upsert(session, START_WORKOUT, user_id=user_id, day=day)


async def set_exercise(
    session: AsyncSession, user_id: str, day: date, key: str, done: bool
) -> DayOut:
    statement = ADD_EXERCISE if done else REMOVE_EXERCISE
    result = await _run(session, statement, user_id=user_id, day=day, key=key)
    if result is None:
        raise conflict("gym_done_limit", "Bajarilgan mashqlar soni to'lgan")
    return result


async def set_water(session: AsyncSession, user_id: str, day: date, glasses: int) -> DayOut:
    return await _run_upsert(session, SET_WATER, user_id=user_id, day=day, glasses=glasses)


async def set_feedback(session: AsyncSession, user_id: str, day: date, rating: int) -> DayOut:
    return await _run_upsert(session, SET_FEEDBACK, user_id=user_id, day=day, rating=rating)
