from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import Select, case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Attendance, Day, Order, Trainer, User
from zalpro_api.schemas.analytics import (
    ChurnItemOut,
    ChurnOut,
    RetentionCohortOut,
    RetentionOut,
    RetentionSplitOut,
    ShopAnalyticsOut,
    ShopTotalsOut,
    TopProductOut,
    TrainerRowOut,
    TrainersOut,
    WeekdaySalesOut,
)
from zalpro_api.services import permissions
from zalpro_api.services.finance import SOLD_AT
from zalpro_api.services.reminders import window_bounds

TOP_LIMIT = 10
WEEKDAYS = range(7)

HAS_COST = Order.cost_price > 0
LINE_REVENUE = Order.price * Order.qty
LINE_PROFIT = case((HAS_COST, (Order.price - Order.cost_price) * Order.qty), else_=0)


def scoped(statement: Select, scope: permissions.OrderScope, lower, upper) -> Select:
    statement = statement.where(Order.status == "given", SOLD_AT >= lower, SOLD_AT < upper)
    if scope.column is not None:
        statement = statement.where(getattr(Order, scope.column) == scope.value)
    return statement


async def shop_analytics(
    session: AsyncSession,
    scope: permissions.OrderScope,
    start: date,
    end: date,
    timezone: str,
) -> ShopAnalyticsOut:
    lower, upper = window_bounds(start, end, timezone)
    totals_rows = await session.execute(
        scoped(
            select(
                Order.currency,
                func.count(),
                func.sum(Order.qty),
                func.sum(LINE_REVENUE),
                func.sum(LINE_PROFIT),
                func.count().filter(func.coalesce(Order.cost_price, 0) == 0),
            ),
            scope,
            lower,
            upper,
        ).group_by(Order.currency)
    )
    totals = {
        currency: ShopTotalsOut(
            orders=orders,
            units=int(units),
            revenue=int(revenue),
            profit=int(profit),
            no_cost_orders=no_cost,
        )
        for currency, orders, units, revenue, profit, no_cost in totals_rows.all()
    }
    units = func.sum(Order.qty)
    revenue = func.sum(LINE_REVENUE)
    top_rows = await session.execute(
        scoped(
            select(
                Order.product_id,
                func.max(Order.product_name),
                func.max(Order.category),
                Order.currency,
                units,
                revenue,
                func.sum(LINE_PROFIT),
            ),
            scope,
            lower,
            upper,
        )
        .group_by(Order.product_id, Order.currency)
        .order_by(units.desc(), revenue.desc(), func.max(Order.product_name), Order.product_id)
        .limit(TOP_LIMIT)
    )
    top = [
        TopProductOut(
            product_id=product_id,
            name=name,
            category=category,
            currency=currency,
            units=int(sold),
            revenue=int(earned),
            profit=int(profit),
        )
        for product_id, name, category, currency, sold, earned, profit in top_rows.all()
    ]
    weekday = func.extract("isodow", func.timezone(timezone, SOLD_AT))
    weekday_rows = await session.execute(
        scoped(
            select(Order.currency, weekday, func.count(), func.sum(LINE_REVENUE)),
            scope,
            lower,
            upper,
        ).group_by(Order.currency, weekday)
    )
    cells = {
        (currency, int(day) - 1): (count, int(earned))
        for currency, day, count, earned in weekday_rows.all()
    }
    by_weekday = [
        WeekdaySalesOut(
            weekday=day,
            currency=currency,
            orders=cells.get((currency, day), (0, 0))[0],
            revenue=cells.get((currency, day), (0, 0))[1],
        )
        for currency in sorted(totals)
        for day in WEEKDAYS
    ]
    return ShopAnalyticsOut(
        from_=start.isoformat(),
        to=end.isoformat(),
        totals=totals,
        top_products=top,
        by_weekday=by_weekday,
    )


CHURN_LIMIT = 100
CHURN_WEIGHTS = {"silent": 3, "drop": 2, "expiring": 2, "expired": 3}
MIN_HISTORY_DAYS = 14
EXPIRING_DAYS = 7
EXPIRED_DAYS = 30
RETENTION_DAYS = (30, 60, 90)
RETENTION_WINDOW = 14


def gym_today(timezone: str) -> date:
    return datetime.now(ZoneInfo(timezone)).date()


def churn_reasons(
    last14: int,
    prev14: int,
    has_history: bool,
    expires_in: int | None,
) -> list[str]:
    reasons = []
    if has_history and prev14 >= 1 and last14 == 0:
        reasons.append("silent")
    elif has_history and prev14 >= 4 and last14 <= prev14 / 2:
        reasons.append("drop")
    if expires_in is not None:
        if 0 <= expires_in <= EXPIRING_DAYS:
            reasons.append("expiring")
        elif -EXPIRED_DAYS <= expires_in < 0:
            reasons.append("expired")
    return reasons


async def churn_list(
    session: AsyncSession, actor: User, timezone: str, today: date | None = None
) -> ChurnOut:
    zone = ZoneInfo(timezone)
    today = today or gym_today(timezone)
    last_from = today - timedelta(days=13)
    prev_from = today - timedelta(days=27)
    students = select(User).where(User.role == "user")
    if actor.role != "owner":
        students = students.where(User.trainer_id == actor.id)
    users = list((await session.scalars(students)).all())
    ids = [user.id for user in users]
    visits: dict[str, tuple[int, int, date | None]] = {}
    if ids:
        rows = await session.execute(
            select(
                Attendance.user_id,
                func.count().filter(Attendance.day >= last_from, Attendance.day <= today),
                func.count().filter(Attendance.day >= prev_from, Attendance.day < last_from),
                func.max(Attendance.day).filter(Attendance.day <= today),
            )
            .where(Attendance.present.is_(True), Attendance.user_id.in_(ids))
            .group_by(Attendance.user_id)
        )
        visits = {user_id: (last, prev, last_day) for user_id, last, prev, last_day in rows.all()}
    trainer_ids = {user.trainer_id for user in users if user.trainer_id}
    names: dict[str, str] = {}
    if trainer_ids:
        names = dict(
            (
                await session.execute(select(User.id, User.name).where(User.id.in_(trainer_ids)))
            ).all()
        )
    items = []
    for user in users:
        last14, prev14, last_visit = visits.get(user.id, (0, 0, None))
        created_day = user.created_at.astimezone(zone).date()
        has_history = (today - created_day).days >= MIN_HISTORY_DAYS
        expires_in = None
        if user.subscription_expires_at is not None:
            expires_in = (user.subscription_expires_at.astimezone(zone).date() - today).days
        reasons = churn_reasons(last14, prev14, has_history, expires_in)
        if not reasons:
            continue
        items.append(
            ChurnItemOut(
                user_id=user.id,
                name=user.name,
                phone=user.phone,
                trainer_id=user.trainer_id,
                trainer_name=names.get(user.trainer_id or "", ""),
                reasons=reasons,
                score=sum(CHURN_WEIGHTS[reason] for reason in reasons),
                last_visit=last_visit.isoformat() if last_visit else None,
                visits_last14=last14,
                visits_prev14=prev14,
                expires_at=(
                    user.subscription_expires_at.astimezone(UTC).isoformat()
                    if user.subscription_expires_at
                    else None
                ),
            )
        )
    items.sort(key=lambda item: (-item.score, item.last_visit or "", item.name))
    return ChurnOut(as_of=today.isoformat(), items=items[:CHURN_LIMIT])


async def retention(
    session: AsyncSession,
    start: date,
    end: date,
    timezone: str,
    today: date | None = None,
) -> RetentionOut:
    zone = ZoneInfo(timezone)
    today = today or gym_today(timezone)
    lower, upper = window_bounds(start, end, timezone)
    users = list(
        (
            await session.scalars(
                select(User).where(
                    User.role == "user", User.created_at >= lower, User.created_at < upper
                )
            )
        ).all()
    )
    days_by_user: dict[str, list[date]] = {user.id: [] for user in users}
    if users:
        rows = await session.execute(
            select(Attendance.user_id, Attendance.day).where(
                Attendance.present.is_(True), Attendance.user_id.in_(list(days_by_user))
            )
        )
        for user_id, day in rows.all():
            days_by_user[user_id].append(day)
    cohorts = []
    for horizon in RETENTION_DAYS:
        counts = {True: [0, 0], False: [0, 0]}
        for user in users:
            joined = user.created_at.astimezone(zone).date()
            first = joined + timedelta(days=horizon)
            last = first + timedelta(days=RETENTION_WINDOW)
            if last > today:
                continue
            kept = any(first <= day < last for day in days_by_user[user.id])
            bucket = counts[user.trainer_id is not None]
            bucket[0] += 1
            bucket[1] += int(kept)
        eligible = counts[True][0] + counts[False][0]
        retained = counts[True][1] + counts[False][1]
        cohorts.append(
            RetentionCohortOut(
                day=horizon,
                eligible=eligible,
                retained=retained,
                rate=round(retained / eligible, 4) if eligible else None,
                with_trainer=RetentionSplitOut(eligible=counts[True][0], retained=counts[True][1]),
                without_trainer=RetentionSplitOut(
                    eligible=counts[False][0], retained=counts[False][1]
                ),
            )
        )
    return RetentionOut(from_=start.isoformat(), to=end.isoformat(), cohorts=cohorts)


async def trainer_effectiveness(
    session: AsyncSession, start: date, end: date, timezone: str
) -> TrainersOut:
    span_days = (end - start).days + 1
    students = dict(
        (
            await session.execute(
                select(User.trainer_id, func.count())
                .where(User.role == "user")
                .group_by(User.trainer_id)
            )
        ).all()
    )
    visit_rows = await session.execute(
        select(User.trainer_id, func.count(), func.count(func.distinct(Attendance.user_id)))
        .select_from(Attendance)
        .join(User, User.id == Attendance.user_id)
        .where(User.role == "user", Attendance.present.is_(True))
        .where(Attendance.day >= start, Attendance.day <= end)
        .group_by(User.trainer_id)
    )
    visits = {trainer_id: (count, active) for trainer_id, count, active in visit_rows.all()}
    feedback_rows = await session.execute(
        select(User.trainer_id, func.count(), func.count().filter(Day.feedback == 3))
        .select_from(Day)
        .join(User, User.id == Day.user_id)
        .where(User.role == "user", Day.feedback.is_not(None))
        .where(Day.day >= start, Day.day <= end)
        .group_by(User.trainer_id)
    )
    feedback = {trainer_id: (count, hard) for trainer_id, count, hard in feedback_rows.all()}
    trainers = dict((await session.execute(select(Trainer.id, Trainer.name))).all())
    keys: list[str | None] = [*sorted(trainers, key=lambda key: trainers[key]), None]
    rows = []
    for key in keys:
        count = students.get(key, 0)
        total_visits, active = visits.get(key, (0, 0))
        asked, hard = feedback.get(key, (0, 0))
        rows.append(
            TrainerRowOut(
                trainer_id=key,
                name=trainers.get(key, "") if key else "",
                students=count,
                active_students=active,
                visits_per_student_week=(
                    round(total_visits / (count * span_days / 7), 2) if count else 0.0
                ),
                feedback_count=asked,
                hard_count=hard,
                hard_share=round(hard / asked, 4) if asked else None,
            )
        )
    return TrainersOut(from_=start.isoformat(), to=end.isoformat(), rows=rows)
