import datetime
from dataclasses import dataclass
from typing import Literal
from zoneinfo import ZoneInfo

from sqlalchemy import Date, cast, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import conflict, forbidden, not_found
from zalpro_api.models import CoinLedger, RepSession, User
from zalpro_api.schemas.game import (
    CatalogOut,
    ChallengeResultOut,
    ExerciseRuleOut,
    GameEntry,
    GameLeaderboardOut,
    GameMe,
    GameMeOut,
    SessionIn,
    SessionOut,
    StreakBonusOut,
)
from zalpro_api.services import challenges, permissions
from zalpro_api.services.leaderboard import same_gym

LEVELS = (0, 500, 1500, 3500, 7000, 12000)
DAILY_XP_CAP = 600
OVER_CAP_PERCENT = 20
MIN_SECONDS_PER_REP = 0.6
MAX_REPS_PER_SESSION = 100
MAX_SESSIONS_PER_DAY = 20
MIN_VISIBILITY_PCT = 70
TIME_SKEW = datetime.timedelta(minutes=10)
STREAK_BONUSES = {3: 10, 7: 30, 30: 150}
TOP_SIZE = 20
STREAK_LOOKBACK_DAYS = 400


@dataclass(frozen=True)
class ExerciseRule:
    key: str
    xp_per_rep: int
    max_reps_per_minute: int


EXERCISES = {
    rule.key: rule
    for rule in (
        ExerciseRule("pushup", 8, 45),
        ExerciseRule("squat", 4, 40),
        ExerciseRule("lunge", 4, 40),
        ExerciseRule("pullup", 20, 25),
        ExerciseRule("situp", 4, 40),
        ExerciseRule("shoulder", 4, 40),
        ExerciseRule("auto", 4, 40),
    )
}


def level_for(xp: int) -> int:
    return sum(1 for threshold in LEVELS if xp >= threshold)


def reward(rule: ExerciseRule, reps: int, xp_today: int) -> int:
    base = reps * rule.xp_per_rep
    full = min(base, max(0, DAILY_XP_CAP - xp_today))
    return full + (base - full) * OVER_CAP_PERCENT // 100


def assess(
    rule: ExerciseRule,
    body: SessionIn,
    sessions_today: int,
    now: datetime.datetime,
) -> str:
    ended = body.started_at + datetime.timedelta(seconds=body.duration_s)
    suspicious = (
        body.reps > MAX_REPS_PER_SESSION
        or body.duration_s < body.reps * MIN_SECONDS_PER_REP
        or body.reps * 60 > rule.max_reps_per_minute * body.duration_s
        or body.visibility_pct < MIN_VISIBILITY_PCT
        or sessions_today >= MAX_SESSIONS_PER_DAY
        or ended > now + TIME_SKEW
        or now - ended > TIME_SKEW
    )
    return "flagged" if suspicious else "valid"


def streak_length(days: set[datetime.date], today: datetime.date) -> int:
    cursor = today if today in days else today - datetime.timedelta(days=1)
    length = 0
    while cursor in days:
        length += 1
        cursor -= datetime.timedelta(days=1)
    return length


def day_bounds(zone: ZoneInfo, day: datetime.date) -> tuple[datetime.datetime, datetime.datetime]:
    start = datetime.datetime.combine(day, datetime.time.min, tzinfo=zone)
    return start, start + datetime.timedelta(days=1)


def period_start(zone: ZoneInfo, period: str, today: datetime.date) -> datetime.datetime | None:
    if period == "day":
        return day_bounds(zone, today)[0]
    if period == "week":
        return day_bounds(zone, today - datetime.timedelta(days=today.weekday()))[0]
    if period == "month":
        return day_bounds(zone, today.replace(day=1))[0]
    if period == "year":
        return day_bounds(zone, today.replace(month=1, day=1))[0]
    return None


def catalog() -> CatalogOut:
    return CatalogOut(
        exercises=[
            ExerciseRuleOut(
                key=rule.key,
                xp_per_rep=rule.xp_per_rep,
                max_reps_per_minute=rule.max_reps_per_minute,
            )
            for rule in EXERCISES.values()
        ],
        levels=list(LEVELS),
        daily_xp_cap=DAILY_XP_CAP,
        streak_bonuses=[StreakBonusOut(days=d, coins=c) for d, c in STREAK_BONUSES.items()],
    )


async def total_coins(session: AsyncSession, user_id: str) -> int:
    return int(
        await session.scalar(
            select(func.coalesce(func.sum(CoinLedger.delta), 0)).where(
                CoinLedger.user_id == user_id
            )
        )
        or 0
    )


async def total_xp(session: AsyncSession, user_id: str) -> int:
    return int(
        await session.scalar(
            select(func.coalesce(func.sum(RepSession.xp), 0)).where(
                RepSession.user_id == user_id, RepSession.status == "valid"
            )
        )
        or 0
    )


async def active_days(session: AsyncSession, user_id: str, zone: ZoneInfo) -> set[datetime.date]:
    since = datetime.datetime.now(zone) - datetime.timedelta(days=STREAK_LOOKBACK_DAYS)
    rows = await session.scalars(
        select(cast(func.timezone(zone.key, RepSession.started_at), Date))
        .where(
            RepSession.user_id == user_id,
            RepSession.status == "valid",
            RepSession.started_at >= since,
        )
        .distinct()
    )
    return set(rows.all())


async def xp_and_sessions_on(
    session: AsyncSession, user_id: str, zone: ZoneInfo, day: datetime.date
) -> tuple[int, int]:
    start, end = day_bounds(zone, day)
    row = (
        await session.execute(
            select(
                func.coalesce(func.sum(RepSession.xp).filter(RepSession.status == "valid"), 0),
                func.count(),
            ).where(
                RepSession.user_id == user_id,
                RepSession.started_at >= start,
                RepSession.started_at < end,
                RepSession.status != "voided",
            )
        )
    ).one()
    return int(row[0]), int(row[1])


async def outcome(
    session: AsyncSession,
    record: RepSession,
    zone: ZoneInfo,
    streak_bonus: int,
    challenge: ChallengeResultOut | None = None,
) -> SessionOut:
    xp = await total_xp(session, record.user_id)
    days = await active_days(session, record.user_id, zone)
    today = datetime.datetime.now(zone).date()
    return SessionOut(
        id=record.id,
        status=record.status,
        coins=record.coins,
        xp=record.xp,
        streak_bonus=streak_bonus,
        streak_days=streak_length(days, today),
        total_coins=await total_coins(session, record.user_id),
        total_xp=xp,
        level=level_for(xp),
        level_up=level_for(xp) > level_for(xp - record.xp),
        challenge=challenge,
    )


async def streak_bonus_of(session: AsyncSession, record: RepSession) -> int:
    return int(
        await session.scalar(
            select(func.coalesce(func.sum(CoinLedger.delta), 0)).where(
                CoinLedger.user_id == record.user_id,
                CoinLedger.reason == "streak",
                CoinLedger.ref_id == record.id,
            )
        )
        or 0
    )


async def submit(session: AsyncSession, actor: User, body: SessionIn, zone: ZoneInfo) -> SessionOut:
    if actor.role != "user":
        raise forbidden()
    rule = EXERCISES.get(body.exercise)
    if rule is None:
        raise conflict("unknown_exercise", "Noma'lum mashq turi")
    if body.started_at.tzinfo is None:
        raise conflict("naive_time", "Vaqt zonasi kerak")
    session_id = body.id.hex
    actor_id = actor.id
    existing = await session.get(RepSession, session_id)
    if existing is not None:
        if existing.user_id != actor_id:
            raise conflict("session_id_taken", "Sessiya identifikatori band")
        return await outcome(session, existing, zone, await streak_bonus_of(session, existing))
    now = datetime.datetime.now(datetime.UTC)
    local_day = body.started_at.astimezone(zone).date()
    xp_today, sessions_today = await xp_and_sessions_on(session, actor_id, zone, local_day)
    status = assess(rule, body, sessions_today, now)
    xp = reward(rule, body.reps, xp_today) if status == "valid" else 0
    days_before = await active_days(session, actor_id, zone) if status == "valid" else set()
    record = RepSession(
        id=session_id,
        user_id=actor_id,
        exercise_key=rule.key,
        reps=body.reps,
        duration_s=body.duration_s,
        visibility_pct=body.visibility_pct,
        started_at=body.started_at,
        coins=0,
        xp=xp,
        status=status,
    )
    session.add(record)
    try:
        await session.flush()
    except IntegrityError:
        await session.rollback()
        existing = await session.get(RepSession, session_id)
        if existing is None or existing.user_id != actor_id:
            raise conflict("session_id_taken", "Sessiya identifikatori band") from None
        return await outcome(session, existing, zone, await streak_bonus_of(session, existing))
    bonus = 0
    challenge = None
    if status == "valid":
        challenge = await challenges.apply_session(
            session, actor_id, rule.key, body.reps, session_id
        )
        if local_day not in days_before:
            length = streak_length(days_before | {local_day}, local_day)
            bonus = STREAK_BONUSES.get(length, 0)
            if bonus:
                session.add(
                    CoinLedger(user_id=actor_id, delta=bonus, reason="streak", ref_id=session_id)
                )
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        existing = await session.get(RepSession, session_id)
        if existing is None or existing.user_id != actor_id:
            raise conflict("session_id_taken", "Sessiya identifikatori band") from None
        return await outcome(session, existing, zone, await streak_bonus_of(session, existing))
    return await outcome(session, record, zone, bonus, challenge)


async def me(session: AsyncSession, actor: User, zone: ZoneInfo) -> GameMeOut:
    xp = await total_xp(session, actor.id)
    level = level_for(xp)
    days = await active_days(session, actor.id, zone)
    best = await session.execute(
        select(RepSession.exercise_key, func.max(RepSession.reps))
        .where(RepSession.user_id == actor.id, RepSession.status == "valid")
        .group_by(RepSession.exercise_key)
    )
    count = await session.scalar(
        select(func.count()).where(RepSession.user_id == actor.id, RepSession.status == "valid")
    )
    return GameMeOut(
        coins=await total_coins(session, actor.id),
        xp=xp,
        level=level,
        level_xp=LEVELS[level - 1],
        next_level_xp=LEVELS[level] if level < len(LEVELS) else None,
        streak_days=streak_length(days, datetime.datetime.now(zone).date()),
        sessions_total=int(count or 0),
        best_sets={key: int(reps) for key, reps in best.all()},
    )


async def leaderboard(
    session: AsyncSession,
    actor: User,
    zone: ZoneInfo,
    period: Literal["day", "week", "month", "year", "all"],
    exercise: str | None,
) -> GameLeaderboardOut:
    if exercise is not None and exercise not in EXERCISES:
        raise conflict("unknown_exercise", "Noma'lum mashq turi")
    statement = (
        select(
            User.id,
            User.name,
            func.sum(RepSession.xp),
            func.sum(RepSession.reps),
            func.max(RepSession.started_at),
        )
        .join(User, User.id == RepSession.user_id)
        .where(
            RepSession.status == "valid",
            User.role == "user",
            User.show_in_leaderboard.is_(True),
            User.game_enabled.is_(True),
            same_gym(actor),
        )
        .group_by(User.id, User.name)
    )
    start = period_start(zone, period, datetime.datetime.now(zone).date())
    if start is not None:
        statement = statement.where(RepSession.started_at >= start)
    if exercise is not None:
        statement = statement.where(RepSession.exercise_key == exercise)
    rows = (await session.execute(statement)).all()

    def metric(row: tuple) -> int:
        return int(row[3] if exercise else row[2])

    ranked = sorted(rows, key=lambda r: (-metric(r), r[4], r[1].casefold(), r[0]))
    top = [
        GameEntry(rank=i, user_id=r[0], name=r[1], xp=int(r[2]), reps=int(r[3]))
        for i, r in enumerate(ranked[:TOP_SIZE], start=1)
    ]
    mine = next(
        (
            GameMe(rank=i, xp=int(r[2]), reps=int(r[3]))
            for i, r in enumerate(ranked, start=1)
            if r[0] == actor.id
        ),
        None,
    )
    return GameLeaderboardOut(period=period, exercise=exercise, top=top, me=mine)


async def void(session: AsyncSession, actor: User, session_id: str) -> None:
    record = await session.get(RepSession, session_id)
    if record is None:
        raise not_found()
    owner = await session.get(User, record.user_id)
    if owner is None or not permissions.can_manage(actor, owner):
        raise forbidden()
    if record.status == "voided":
        return
    was_valid = record.status == "valid"
    record.status = "voided"
    if was_valid:
        earned = await session.scalar(
            select(func.coalesce(func.sum(CoinLedger.delta), 0)).where(
                CoinLedger.ref_id == record.id,
                CoinLedger.reason.in_(("session", "streak", "challenge")),
            )
        )
        if earned:
            session.add(
                CoinLedger(
                    user_id=record.user_id, delta=-int(earned), reason="void", ref_id=record.id
                )
            )
    await session.commit()
