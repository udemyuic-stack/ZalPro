from datetime import datetime
from zoneinfo import ZoneInfo

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from zalpro_api.models import Order, Product, Subscription, User
from zalpro_api.schemas.finance import MonthlyReportOut, TrainerBreakdownOut
from zalpro_api.services.subscriptions import PAID_AT

SOLD_AT = func.coalesce(Order.given_at, Order.created_at)
CLIENT = aliased(User)
TRAINER = aliased(User)
CLIENT_GYM = func.coalesce(TRAINER.gym_id, "")
CLIENT_TRAINER = func.coalesce(CLIENT.trainer_id, "")


def month_bounds(year: int, month: int, zone: ZoneInfo) -> tuple[datetime, datetime]:
    start = datetime(year, month, 1, tzinfo=zone)
    next_year, next_month = (year + 1, 1) if month == 12 else (year, month + 1)
    return start, datetime(next_year, next_month, 1, tzinfo=zone)


def with_client_gym(statement: Select, gym_id: str | None) -> Select:
    if gym_id is None:
        return statement
    return statement.where(CLIENT_GYM == gym_id)


def subscription_rows(statement: Select, gym_id: str | None) -> Select:
    joined = (
        statement.select_from(Subscription)
        .outerjoin(CLIENT, CLIENT.id == Subscription.user_id)
        .outerjoin(TRAINER, TRAINER.id == CLIENT.trainer_id)
    )
    return with_client_gym(joined, gym_id)


async def shop_part(
    session: AsyncSession, start: datetime, end: datetime, gym_id: str | None
) -> tuple[int, dict[str, int], dict[str, int], int]:
    statement = (
        select(
            Order.currency,
            Order.price,
            Order.qty,
            Product.cost_price,
        )
        .outerjoin(Product, Product.id == Order.product_id)
        .where(Order.status == "given", SOLD_AT >= start, SOLD_AT < end)
    )
    if gym_id is not None:
        statement = statement.where(Order.gym_id == gym_id)
    sums: dict[str, int] = {}
    profit: dict[str, int] = {}
    count = 0
    no_cost = 0
    for currency, price, qty, cost_price in (await session.execute(statement)).all():
        count += 1
        sums[currency] = sums.get(currency, 0) + price * qty
        if not cost_price:
            no_cost += 1
            continue
        profit[currency] = profit.get(currency, 0) + (price - cost_price) * qty
    return count, sums, profit, no_cost


async def trainer_breakdown(
    session: AsyncSession, start: datetime, end: datetime, gym_id: str | None
) -> list[TrainerBreakdownOut]:
    client_counts = (
        select(CLIENT_TRAINER, func.count())
        .select_from(CLIENT)
        .outerjoin(TRAINER, TRAINER.id == CLIENT.trainer_id)
        .where(CLIENT.role == "user")
        .group_by(CLIENT_TRAINER)
    )
    if gym_id is not None:
        client_counts = client_counts.where(CLIENT_GYM == gym_id)
    clients = {
        trainer_id: count for trainer_id, count in (await session.execute(client_counts)).all()
    }
    paid = subscription_rows(
        select(CLIENT_TRAINER, Subscription.currency, func.count(), func.sum(Subscription.price)),
        gym_id,
    )
    paid = paid.where(PAID_AT >= start, PAID_AT < end).group_by(
        CLIENT_TRAINER, Subscription.currency
    )
    counts: dict[str, int] = {}
    sums: dict[str, dict[str, int]] = {}
    for trainer_id, currency, count, total in (await session.execute(paid)).all():
        counts[trainer_id] = counts.get(trainer_id, 0) + count
        sums.setdefault(trainer_id, {})[currency] = int(total)
    trainer_ids = {*clients, *counts}
    names = {}
    if trainer_ids - {""}:
        rows = await session.execute(select(User.id, User.name).where(User.id.in_(trainer_ids)))
        names = dict(rows.all())
    result = [
        TrainerBreakdownOut(
            trainer_id=trainer_id,
            name=names.get(trainer_id, ""),
            clients=clients.get(trainer_id, 0),
            subs_count=counts.get(trainer_id, 0),
            subs_sums=sums.get(trainer_id, {}),
        )
        for trainer_id in trainer_ids
    ]
    return sorted(result, key=lambda item: (-sum(item.subs_sums.values()), item.trainer_id))


async def monthly_report(
    session: AsyncSession, year: int, month: int, zone: ZoneInfo, gym_id: str | None = None
) -> MonthlyReportOut:
    start, end = month_bounds(year, month, zone)
    statement = subscription_rows(
        select(Subscription.currency, func.count(), func.sum(Subscription.price)), gym_id
    )
    statement = statement.where(PAID_AT >= start, PAID_AT < end).group_by(Subscription.currency)
    rows = (await session.execute(statement)).all()
    orders_count, shop_sums, profit, no_cost_orders = await shop_part(session, start, end, gym_id)
    return MonthlyReportOut(
        month=f"{year:04d}-{month:02d}",
        subs_count=sum(count for _, count, _ in rows),
        subs_sums={currency: int(total) for currency, _, total in rows},
        orders_count=orders_count,
        shop_sums=shop_sums,
        profit=profit,
        no_cost_orders=no_cost_orders,
        trainers=await trainer_breakdown(session, start, end, gym_id),
    )
