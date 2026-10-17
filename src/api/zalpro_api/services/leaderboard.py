import datetime
from collections import defaultdict
from dataclasses import dataclass
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Attendance, Day, User
from zalpro_api.schemas.leaderboard import LeaderboardEntry, LeaderboardMe, LeaderboardOut

PERIOD_DAYS = 30
TOP_SIZE = 10
POINTS_PRESENT = 10
POINTS_WORKOUT = 5
MIN_WORKOUT_EXERCISES = 3
WEEK_ACTIVE_DAYS = 3
POINTS_WEEK_BONUS = 15


@dataclass(frozen=True)
class Standing:
    user_id: str
    name: str
    points: int
    active_days: int


def score(present: set[datetime.date], worked: set[datetime.date]) -> tuple[int, int]:
    points = POINTS_PRESENT * len(present) + POINTS_WORKOUT * len(worked)
    active = present | worked
    per_week: dict[tuple[int, int], int] = defaultdict(int)
    for day in active:
        iso = day.isocalendar()
        per_week[(iso.year, iso.week)] += 1
    bonus = POINTS_WEEK_BONUS * sum(1 for count in per_week.values() if count >= WEEK_ACTIVE_DAYS)
    return points + bonus, len(active)


def window(
    zone: ZoneInfo, now: datetime.datetime | None = None
) -> tuple[datetime.date, datetime.date]:
    today = (now or datetime.datetime.now(zone)).astimezone(zone).date()
    return today - datetime.timedelta(days=PERIOD_DAYS - 1), today


def same_gym(actor: User):
    return User.gym_id.is_not_distinct_from(actor.gym_id)


async def standings(
    session: AsyncSession, actor: User, start: datetime.date, end: datetime.date
) -> list[Standing]:
    members = (
        await session.execute(
            select(User.id, User.name).where(
                User.role == "user", User.show_in_leaderboard.is_(True), same_gym(actor)
            )
        )
    ).all()
    names = {row.id: row.name for row in members}
    if not names:
        return []
    present: dict[str, set[datetime.date]] = defaultdict(set)
    worked: dict[str, set[datetime.date]] = defaultdict(set)
    attendance = await session.execute(
        select(Attendance.user_id, Attendance.day).where(
            Attendance.user_id.in_(names),
            Attendance.present.is_(True),
            Attendance.day.between(start, end),
        )
    )
    for user_id, day in attendance.all():
        present[user_id].add(day)
    days = await session.execute(
        select(Day.user_id, Day.day).where(
            Day.user_id.in_(names),
            Day.gym_started.is_(True),
            func.cardinality(Day.gym_done) >= MIN_WORKOUT_EXERCISES,
            Day.day.between(start, end),
        )
    )
    for user_id, day in days.all():
        worked[user_id].add(day)
    result = []
    for user_id, name in names.items():
        points, active = score(present[user_id], worked[user_id])
        if points > 0:
            result.append(Standing(user_id, name, points, active))
    result.sort(key=lambda s: (-s.points, -s.active_days, s.name.casefold(), s.user_id))
    return result


async def leaderboard(session: AsyncSession, actor: User, zone: ZoneInfo) -> LeaderboardOut:
    start, end = window(zone)
    ranked = await standings(session, actor, start, end)
    top = [
        LeaderboardEntry(
            rank=index, user_id=s.user_id, name=s.name, points=s.points, active_days=s.active_days
        )
        for index, s in enumerate(ranked[:TOP_SIZE], start=1)
    ]
    me = next(
        (
            LeaderboardMe(rank=index, points=s.points, active_days=s.active_days)
            for index, s in enumerate(ranked, start=1)
            if s.user_id == actor.id
        ),
        None,
    )
    return LeaderboardOut(period_days=PERIOD_DAYS, top=top, me=me)
