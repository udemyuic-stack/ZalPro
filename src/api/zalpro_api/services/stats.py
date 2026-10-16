from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import distinct_on
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Day, Message, Plan, Rating, Trainer, User, Weight
from zalpro_api.schemas.stats import TrainerStatOut

WEEKDAYS = range(1, 8)
SCORE_WEIGHTS = (30, 25, 25, 20)


@dataclass
class ClientStat:
    has_plan: bool
    tracked_days: int
    meals_done: int
    meals_expected: int
    waiting_reply: bool
    has_messages: bool
    progressing: bool | None
    staff_messages: int


@dataclass
class TrainerAccumulator:
    clients: list[ClientStat] = field(default_factory=list)
    plan_assigned: list[bool] = field(default_factory=list)


def round_half_up(value: float) -> int:
    return int(value + 0.5)


def meals_per_day(plan: Plan | None) -> int:
    if plan is None:
        return 0
    if not plan.week:
        return len(plan.meals)
    lengths = [len(plan.week.get(str(day), plan.meals)) for day in WEEKDAYS]
    return round_half_up(sum(lengths) / len(WEEKDAYS))


def tracked_days_for(assigned_at: datetime | None, today: date, window: int, zone: ZoneInfo) -> int:
    if assigned_at is None:
        return window
    elapsed = (today - assigned_at.astimezone(zone).date()).days + 1
    return max(1, min(window, elapsed))


def share(flags: list[bool]) -> float | None:
    return sum(flags) / len(flags) if flags else None


def client_adherence(stat: ClientStat) -> float | None:
    if not stat.has_plan:
        return None
    return min(1.0, stat.meals_done / (stat.meals_expected * stat.tracked_days))


def score_of(parts: list[float | None]) -> int | None:
    total = 0.0
    weight = 0
    for value, part_weight in zip(parts, SCORE_WEIGHTS, strict=True):
        if value is None:
            continue
        total += value * part_weight
        weight += part_weight
    return None if weight == 0 else round_half_up(total / weight * 100)


def stars_of(score: int | None) -> int | None:
    if score is None:
        return None
    return max(1, min(5, -(-score // 20)))


def build_trainer_stat(
    trainer: Trainer, clients: list[ClientStat], plan_flags: list[bool], ratings: list[int]
) -> TrainerStatOut:
    adherences = [a for c in clients if (a := client_adherence(c)) is not None]
    adherence = sum(adherences) / len(adherences) if adherences else None
    plan_coverage = share(plan_flags)
    reply_rate = share([not c.waiting_reply for c in clients if c.has_messages])
    progress_rate = share([c.progressing for c in clients if c.progressing is not None])
    score = score_of([plan_coverage, reply_rate, adherence, progress_rate]) if clients else None
    return TrainerStatOut(
        trainer_id=trainer.id,
        name=trainer.name,
        client_count=len(clients),
        tracked_days=sum(c.tracked_days for c in clients if c.has_plan),
        meals_done=sum(c.meals_done for c in clients if c.has_plan),
        meals_expected=sum(c.meals_expected * c.tracked_days for c in clients if c.has_plan),
        adherence=adherence,
        plan_coverage=plan_coverage,
        reply_rate=reply_rate,
        progress_rate=progress_rate,
        messages_sent=sum(c.staff_messages for c in clients),
        score=score,
        stars=stars_of(score),
        average_rating=sum(ratings) / len(ratings) if ratings else None,
        rating_count=len(ratings),
    )


async def trainer_stats(
    session: AsyncSession, window: int, zone: ZoneInfo, now: datetime | None = None
) -> list[TrainerStatOut]:
    moment = now or datetime.now(zone)
    today = moment.astimezone(zone).date()
    trainers = list(
        (await session.scalars(select(Trainer).order_by(Trainer.name, Trainer.id))).all()
    )
    trainer_ids = [t.id for t in trainers]
    clients = list(
        (
            await session.scalars(
                select(User).where(User.role == "user", User.trainer_id.in_(trainer_ids))
            )
        ).all()
    )
    client_ids = [c.id for c in clients]
    plan_ids = {c.plan_id for c in clients if c.plan_id is not None}
    plans = {
        p.id: p for p in (await session.scalars(select(Plan).where(Plan.id.in_(plan_ids)))).all()
    }
    days_done = await load_days_done(session, client_ids, today, window)
    latest_senders = await load_latest_senders(session, client_ids)
    staff_counts = await load_staff_counts(session, client_ids, trainer_ids, moment, window)
    progress = await load_progress(session, clients)
    ratings = await load_ratings(session)

    grouped: dict[str, TrainerAccumulator] = {t.id: TrainerAccumulator() for t in trainers}
    for client in clients:
        if client.trainer_id is None:
            continue
        per_day = meals_per_day(plans.get(client.plan_id)) if client.plan_id else 0
        tracked = tracked_days_for(client.plan_assigned_at, today, window, zone)
        done = sum(
            min(len(done), per_day)
            for day, done in days_done.get(client.id, {}).items()
            if (today - day).days < tracked
        )
        latest = latest_senders.get(client.id)
        accumulator = grouped[client.trainer_id]
        accumulator.plan_assigned.append(client.plan_id is not None)
        accumulator.clients.append(
            ClientStat(
                has_plan=client.plan_id is not None and per_day > 0,
                tracked_days=tracked,
                meals_done=done,
                meals_expected=per_day,
                waiting_reply=latest == client.id,
                has_messages=latest is not None,
                progressing=progress.get(client.id),
                staff_messages=staff_counts.get(client.id, 0),
            )
        )
    return [
        build_trainer_stat(
            trainer,
            grouped[trainer.id].clients,
            grouped[trainer.id].plan_assigned,
            ratings.get(trainer.id, []),
        )
        for trainer in trainers
    ]


async def load_days_done(
    session: AsyncSession, client_ids: list[str], today: date, window: int
) -> dict[str, dict[date, list[int]]]:
    rows = await session.execute(
        select(Day.user_id, Day.day, Day.done).where(
            Day.user_id.in_(client_ids),
            Day.day > today - timedelta(days=window),
            Day.day <= today,
        )
    )
    result: dict[str, dict[date, list[int]]] = {}
    for user_id, day, done in rows.all():
        result.setdefault(user_id, {})[day] = done
    return result


async def load_latest_senders(session: AsyncSession, client_ids: list[str]) -> dict[str, str]:
    rows = await session.execute(
        select(Message.chat_uid, Message.sender_id)
        .ext(distinct_on(Message.chat_uid))
        .where(Message.chat_uid.in_(client_ids))
        .order_by(Message.chat_uid, Message.created_at.desc(), Message.id.desc())
    )
    return {chat_uid: sender_id for chat_uid, sender_id in rows.all()}


async def load_staff_counts(
    session: AsyncSession,
    client_ids: list[str],
    trainer_ids: list[str],
    now: datetime,
    window: int,
) -> dict[str, int]:
    rows = await session.execute(
        select(Message.chat_uid, User.trainer_id, func.count())
        .join(User, User.id == Message.chat_uid)
        .where(
            Message.chat_uid.in_(client_ids),
            Message.sender_id.in_(trainer_ids),
            Message.sender_id == User.trainer_id,
            Message.created_at > now - timedelta(days=window),
        )
        .group_by(Message.chat_uid, User.trainer_id)
    )
    return {chat_uid: count for chat_uid, _, count in rows.all()}


async def load_progress(session: AsyncSession, clients: list[User]) -> dict[str, bool]:
    goals = {c.id: c.goal for c in clients if c.goal}
    if not goals:
        return {}
    ids = list(goals)
    first = await weight_edges(session, ids, ascending=True)
    last = await weight_edges(session, ids, ascending=False)
    result: dict[str, bool] = {}
    counts = dict(
        (
            await session.execute(
                select(Weight.user_id, func.count())
                .where(Weight.user_id.in_(ids))
                .group_by(Weight.user_id)
            )
        ).all()
    )
    for user_id, goal in goals.items():
        if counts.get(user_id, 0) < 2:
            continue
        change = last[user_id] - first[user_id]
        result[user_id] = change > 0 if goal == "gain" else change < 0
    return result


async def weight_edges(session: AsyncSession, ids: list[str], ascending: bool) -> dict[str, float]:
    order = Weight.date.asc() if ascending else Weight.date.desc()
    rows = await session.execute(
        select(Weight.user_id, Weight.weight)
        .ext(distinct_on(Weight.user_id))
        .where(Weight.user_id.in_(ids))
        .order_by(Weight.user_id, order)
    )
    return {user_id: weight for user_id, weight in rows.all()}


async def load_ratings(session: AsyncSession) -> dict[str, list[int]]:
    rows = await session.execute(select(Rating.trainer_id, Rating.stars))
    result: dict[str, list[int]] = {}
    for trainer_id, stars in rows.all():
        result.setdefault(trainer_id, []).append(stars)
    return result
