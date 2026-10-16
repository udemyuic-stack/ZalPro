import uuid
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.models import Membership, Subscription, User
from zalpro_api.schemas.subscription import SubscriptionIn, SubscriptionOut

PAID_AT = func.coalesce(Subscription.paid_date, Subscription.created_at, Subscription.start_date)
MAX_MEMBERSHIP_NAME = 60


def gym_zone(settings: Settings) -> ZoneInfo:
    return ZoneInfo(settings.gym_timezone)


def add_months(day: date, months: int) -> date:
    year, month_index = divmod(day.year * 12 + (day.month - 1) + months, 12)
    return date(year, month_index + 1, 1) + timedelta(days=day.day - 1)


def compute_expiry(start: datetime, months: int, days: int, zone: ZoneInfo) -> datetime:
    start_day = start.astimezone(zone).date()
    if months > 0:
        expiry_day = add_months(start_day, months)
    else:
        expiry_day = start_day + timedelta(days=days - 1)
    return datetime.combine(expiry_day, time.min, tzinfo=zone).astimezone(UTC)


def to_out(subscription: Subscription, zone: ZoneInfo) -> SubscriptionOut:
    paid_at = subscription.paid_date or subscription.created_at or subscription.start_date
    return SubscriptionOut(
        id=subscription.id,
        user_id=subscription.user_id,
        start_date=subscription.start_date,
        months=subscription.months,
        days=subscription.days,
        price=subscription.price,
        currency=subscription.currency,
        paid_date=subscription.paid_date,
        created_at=subscription.created_at,
        paid_at=paid_at,
        expires_at=compute_expiry(
            subscription.start_date, subscription.months, subscription.days, zone
        ),
    )


async def list_user_subscriptions(
    session: AsyncSession, user_id: str, zone: ZoneInfo
) -> list[SubscriptionOut]:
    statement = (
        select(Subscription)
        .where(Subscription.user_id == user_id)
        .order_by(Subscription.start_date.desc(), Subscription.created_at.desc(), Subscription.id)
    )
    return [to_out(item, zone) for item in (await session.scalars(statement)).all()]


async def list_paid_between(
    session: AsyncSession, start: datetime | None, end: datetime | None, zone: ZoneInfo
) -> list[SubscriptionOut]:
    statement = select(Subscription)
    if start is not None and end is not None:
        statement = statement.where(PAID_AT >= start, PAID_AT < end)
    statement = statement.order_by(PAID_AT.desc(), Subscription.id)
    return [to_out(item, zone) for item in (await session.scalars(statement)).all()]


async def trainer_gym_id(session: AsyncSession, client: User) -> str:
    if client.trainer_id is None:
        return ""
    gym_id = await session.scalar(select(User.gym_id).where(User.id == client.trainer_id))
    return gym_id or ""


async def upsert_membership(
    session: AsyncSession,
    client: User,
    gym_id: str,
    body: SubscriptionIn,
    expires_at: datetime,
) -> None:
    values = {
        "name": client.name[:MAX_MEMBERSHIP_NAME],
        "gym_id": gym_id,
        "months": body.months,
        "days": body.days,
        "price": body.price,
        "currency": body.currency,
        "paid_date": body.paid_date or datetime.now(UTC),
        "expires_at": expires_at,
    }
    statement = pg_insert(Membership).values(user_id=client.id, **values)
    statement = statement.on_conflict_do_update(
        index_elements=[Membership.user_id], set_={**values, "updated_at": func.now()}
    )
    await session.execute(statement)


async def add_subscription(
    session: AsyncSession, client: User, body: SubscriptionIn, zone: ZoneInfo
) -> SubscriptionOut:
    expires_at = compute_expiry(body.start_date, body.months, body.days, zone)
    subscription = Subscription(
        id=uuid.uuid4().hex,
        user_id=client.id,
        start_date=body.start_date,
        months=body.months,
        days=body.days,
        price=body.price,
        currency=body.currency,
        paid_date=body.paid_date,
    )
    session.add(subscription)
    gym_id = await trainer_gym_id(session, client)
    client.subscription_expires_at = expires_at
    await session.flush()
    await upsert_membership(session, client, gym_id, body, expires_at)
    await session.commit()
    await session.refresh(subscription)
    return to_out(subscription, zone)
