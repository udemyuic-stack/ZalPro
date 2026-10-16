from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import not_found
from zalpro_api.models import Reminder, User
from zalpro_api.services import system_messages
from zalpro_api.services.messages import stage_message


def window_bounds(start: date, end: date, timezone: str) -> tuple[datetime, datetime]:
    zone = ZoneInfo(timezone)
    lower = datetime.combine(start, time.min, tzinfo=zone)
    upper = datetime.combine(end + timedelta(days=1), time.min, tzinfo=zone)
    return lower, upper


async def create_reminder(
    session: AsyncSession, actor: User, client: User, days_left: int
) -> Reminder:
    reminder = Reminder(
        client_id=client.id,
        client_name=client.name,
        trainer_id=client.trainer_id or "",
        sent_by=actor.id,
        days_left=days_left,
    )
    session.add(reminder)
    await stage_message(
        session, client.id, actor.id, system_messages.reminder_text(days_left), "system"
    )
    await session.commit()
    await session.refresh(reminder)
    return reminder


async def list_reminders(
    session: AsyncSession,
    trainer_scope: str | None,
    start: date | None,
    end: date | None,
    timezone: str,
) -> list[Reminder]:
    statement = select(Reminder)
    if start is not None and end is not None:
        lower, upper = window_bounds(start, end, timezone)
        statement = statement.where(Reminder.sent_at >= lower, Reminder.sent_at < upper)
    if trainer_scope is not None:
        statement = statement.where(Reminder.trainer_id == trainer_scope)
    statement = statement.order_by(Reminder.sent_at.desc(), Reminder.id.desc())
    return list((await session.scalars(statement)).all())


async def delete_reminder(session: AsyncSession, reminder_id: str) -> None:
    result = await session.execute(delete(Reminder).where(Reminder.id == reminder_id))
    if result.rowcount == 0:
        raise not_found("Eslatma topilmadi")
    await session.commit()
