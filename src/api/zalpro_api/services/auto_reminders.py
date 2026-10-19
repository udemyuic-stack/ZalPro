import asyncio
import contextlib
import logging
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Reminder, User
from zalpro_api.services import system_messages
from zalpro_api.services.messages import publish_staged, stage_message

logger = logging.getLogger(__name__)

DEFAULT_TIMEZONE = "Asia/Tashkent"
STAGES = (3, 0, -3)
CATCH_UP_DAYS = 1
SEND_HOUR = 9
CHECK_INTERVAL_SECONDS = 3600


@dataclass(frozen=True, slots=True)
class Due:
    client_id: str
    client_name: str
    trainer_id: str
    gym_id: str | None
    expires_at: datetime
    days_left: int
    stage: int


def stage_for(days_left: int) -> int | None:
    for stage in STAGES:
        if stage - CATCH_UP_DAYS <= days_left <= stage:
            return stage
    return None


def local_date(moment: datetime, zone: ZoneInfo) -> date:
    return moment.astimezone(zone).date()


async def find_candidates(session: AsyncSession, today: date, zone: ZoneInfo) -> list[User]:
    reach = max(STAGES) + 1
    reach_back = abs(min(STAGES)) + CATCH_UP_DAYS + 1
    lower = datetime.combine(today - timedelta(days=reach_back), time.min, tzinfo=zone)
    upper = datetime.combine(today + timedelta(days=reach), time.min, tzinfo=zone)
    statement = select(User).where(
        User.role == "user",
        User.subscription_expires_at.is_not(None),
        User.subscription_expires_at >= lower,
        User.subscription_expires_at < upper,
    )
    return list((await session.scalars(statement)).all())


def find_due(clients: list[User], today: date, zone: ZoneInfo) -> list[Due]:
    due: list[Due] = []
    for client in clients:
        if client.subscription_expires_at is None:
            continue
        days_left = (local_date(client.subscription_expires_at, zone) - today).days
        stage = stage_for(days_left)
        if stage is not None:
            due.append(
                Due(
                    client.id,
                    client.name,
                    client.trainer_id or "",
                    client.gym_id,
                    client.subscription_expires_at,
                    days_left,
                    stage,
                )
            )
    return due


async def load_owners(session: AsyncSession) -> list[tuple[str, str | None]]:
    statement = select(User.id, User.gym_id).where(User.role == "owner").order_by(User.id)
    return [(row.id, row.gym_id) for row in await session.execute(statement)]


def pick_sender_id(item: Due, owners: list[tuple[str, str | None]]) -> str | None:
    if item.trainer_id:
        return item.trainer_id
    same_gym = [owner for owner in owners if owner[1] == item.gym_id]
    candidates = same_gym or owners
    return candidates[0][0] if candidates else None


async def insert_reminder(session: AsyncSession, item: Due, sender_id: str) -> str | None:
    statement = (
        insert(Reminder)
        .values(
            client_id=item.client_id,
            client_name=item.client_name,
            trainer_id=item.trainer_id,
            sent_by=sender_id,
            days_left=item.days_left,
            auto=True,
            expires_ref=item.expires_at,
            auto_stage=item.stage,
        )
        .on_conflict_do_nothing(
            index_elements=["client_id", "auto_stage", "expires_ref"],
            index_where=text("auto"),
        )
        .returning(Reminder.id)
    )
    return await session.scalar(statement)


async def send_one(session: AsyncSession, item: Due, sender_id: str) -> bool:
    if await insert_reminder(session, item, sender_id) is None:
        await session.rollback()
        return False
    text = system_messages.reminder_text(item.days_left)
    await stage_message(session, item.client_id, sender_id, text, "system")
    await session.commit()
    return True


async def run_once(
    session: AsyncSession, now: datetime, timezone: str = DEFAULT_TIMEZONE, hub: Any = None
) -> int:
    zone = ZoneInfo(timezone)
    today = local_date(now, zone)
    clients = await find_candidates(session, today, zone)
    due = find_due(clients, today, zone)
    owners = await load_owners(session)
    sent = 0
    for item in due:
        sender_id = pick_sender_id(item, owners)
        if sender_id is None:
            logger.warning("auto_reminder_no_sender", extra={"client_id": item.client_id})
            continue
        try:
            is_sent = await send_one(session, item, sender_id)
        except Exception:
            await session.rollback()
            session.info.clear()
            logger.exception("auto_reminder_failed", extra={"client_id": item.client_id})
            continue
        if is_sent:
            sent += 1
            if hub is not None:
                publish_staged(session, hub)
    return sent


class AutoReminderWorker:
    def __init__(self, state: Any) -> None:
        self._state = state
        self._task: asyncio.Task[None] | None = None
        self._last_run_day: date | None = None

    async def start(self) -> None:
        if self._task is None:
            self._task = asyncio.create_task(self._run())

    async def stop(self) -> None:
        task = self._task
        if task is None:
            return
        self._task = None
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task

    def is_due(self, now: datetime) -> bool:
        local = now.astimezone(ZoneInfo(self._state.settings.gym_timezone))
        return local.hour >= SEND_HOUR and self._last_run_day != local.date()

    async def _run(self) -> None:
        while True:
            await self.tick(datetime.now().astimezone())
            await asyncio.sleep(CHECK_INTERVAL_SECONDS)

    async def tick(self, now: datetime) -> None:
        if not self.is_due(now):
            return
        try:
            async with self._state.sessionmaker() as session:
                sent = await run_once(
                    session, now, self._state.settings.gym_timezone, self._state.hub
                )
        except Exception:
            logger.exception("auto_reminders_cycle_failed")
            return
        self._last_run_day = now.astimezone(ZoneInfo(self._state.settings.gym_timezone)).date()
        logger.info("auto_reminders_cycle_done", extra={"sent": sent})
