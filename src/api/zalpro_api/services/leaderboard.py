import datetime
from collections import defaultdict
from dataclasses import dataclass
from zoneinfo import ZoneInfo

from sqlalchemy import func, literal, select, union_all
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
    marks = union_all(
        select(
            Attendance.user_id.label("user_id"),
            Attendance.day.label("day"),
            literal(1).label("present"),
            literal(0).label("worked"),
        ).where(
            Attendance.user_id.in_(names),
            Attendance.present.is_(True),
            Attendance.day.between(start, end),
        ),
        select(
            Day.user_id.label("user_id"),
            Day.day.label("day"),
            literal(0).label("present"),
            literal(1).label("worked"),
        ).where(
            Day.user_id.in_(names),
            Day.gym_started.is_(True),
            func.cardinality(Day.gym_done) >= MIN_WORKOUT_EXERCISES,
            Day.day.between(start, end),
        ),
    ).subquery()
    per_day = (
        select(
            marks.c.user_id,
            marks.c.day,
            func.max(marks.c.present).label("present"),
            func.max(marks.c.worked).label("worked"),
        )
        .group_by(marks.c.user_id, marks.c.day)
        .subquery()
    )
    per_week = (
        select(
            per_day.c.user_id,
            func.count().label("active"),
            func.sum(per_day.c.present).label("present"),
            func.sum(per_day.c.worked).label("worked"),
        )
        .group_by(per_day.c.user_id, func.date_trunc("week", per_day.c.day))
        .subquery()
    )
    totals = await session.execute(
        select(
            per_week.c.user_id,
            func.sum(per_week.c.active),
            func.sum(per_week.c.present),
            func.sum(per_week.c.worked),
            func.count().filter(per_week.c.active >= WEEK_ACTIVE_DAYS),
        ).group_by(per_week.c.user_id)
    )
    result = []
    for user_id, active, present, worked, bonus_weeks in totals.all():
        points = (
            POINTS_PRESENT * present + POINTS_WORKOUT * worked + POINTS_WEEK_BONUS * bonus_weeks
        )
        if points > 0:
            result.append(Standing(user_id, names[user_id], points, active))
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
