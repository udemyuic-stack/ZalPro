from datetime import UTC, date, datetime
from typing import Literal

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.errors import ApiError, not_found
from zalpro_api.core.security import decode_checkin_token
from zalpro_api.models import Attendance, User
from zalpro_api.schemas.attendance import AttendanceOut, ScanOut
from zalpro_api.services.subscriptions import gym_zone

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


def subscription_status(
    expires_at: datetime | None, today: date, settings: Settings
) -> tuple[Literal["active", "expired", "none"], int | None]:
    if expires_at is None:
        return "none", None
    days_left = (expires_at.astimezone(gym_zone(settings)).date() - today).days
    if days_left < 0:
        return "expired", None
    return "active", days_left


async def scan_checkin(
    session: AsyncSession, settings: Settings, actor: User, token: str
) -> ScanOut:
    member = await session.get(User, decode_checkin_token(token, settings))
    if member is None:
        raise not_found("Foydalanuvchi topilmadi")
    if member.role != "user":
        raise ApiError(422, "checkin_not_member", "Faqat mijoz davomatini belgilash mumkin")
    today = datetime.now(UTC).astimezone(gym_zone(settings)).date()
    existing = await get_attendance(session, member.id, today)
    if not existing.present:
        await mark_attendance(session, member.id, today, True, actor.id)
    expires_at = member.subscription_expires_at
    status, days_left = subscription_status(expires_at, today, settings)
    return ScanOut(
        user_id=member.id,
        name=member.name,
        day=today,
        already_present=existing.present,
        subscription_expires_at=expires_at,
        days_left=days_left,
        subscription=status,
    )
