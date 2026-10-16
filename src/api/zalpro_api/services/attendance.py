from datetime import date

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Attendance
from zalpro_api.schemas.attendance import AttendanceOut

MARK = text(
    """
    insert into attendance (user_id, day, present, marked_by)
    values (:user_id, cast(:day as date), :present, :marked_by)
    on conflict (user_id, day) do update
    set present = excluded.present, marked_by = excluded.marked_by, marked_at = now()
    returning day, present, marked_by, marked_at
    """
)


def empty_attendance(day: date) -> AttendanceOut:
    return AttendanceOut(day=day, present=False)


async def get_attendance(session: AsyncSession, user_id: str, day: date) -> AttendanceOut:
    row = await session.get(Attendance, (user_id, day))
    if row is None:
        return empty_attendance(day)
    return AttendanceOut.model_validate(row)


async def list_attendance(
    session: AsyncSession, user_id: str, start: date, end: date
) -> list[AttendanceOut]:
    statement = (
        select(Attendance)
        .where(Attendance.user_id == user_id, Attendance.day.between(start, end))
        .order_by(Attendance.day)
    )
    return [AttendanceOut.model_validate(row) for row in (await session.scalars(statement)).all()]


async def mark_attendance(
    session: AsyncSession, user_id: str, day: date, present: bool, marked_by: str
) -> AttendanceOut:
    params = {"user_id": user_id, "day": day, "present": present, "marked_by": marked_by}
    row = (await session.execute(MARK, params)).mappings().one()
    await session.commit()
    return AttendanceOut.model_validate(dict(row))
