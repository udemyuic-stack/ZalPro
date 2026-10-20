import base64
import uuid
from datetime import UTC, datetime, timedelta
from urllib.parse import urlencode

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.errors import ApiError, bad_request, forbidden, not_found
from zalpro_api.models import PaymentOrder, User
from zalpro_api.schemas.payment import (
    PLAN_MONTHS,
    PaymentOptionsOut,
    PaymentOrderIn,
    PaymentOrderOut,
    PaymentPlanOut,
)
from zalpro_api.schemas.subscription import SubscriptionIn
from zalpro_api.services import subscriptions as subscriptions_service

CLICK_PAY_URL = "https://my.click.uz/services/pay"
PENDING_REUSE = timedelta(minutes=30)
TIYIN = 100


def enabled_providers(settings: Settings) -> list[str]:
    providers = []
    if settings.payme_configured:
        providers.append("payme")
    if settings.click_configured:
        providers.append("click")
    return providers


def plan_price(settings: Settings, months: int) -> int:
    return settings.subscription_month_price * months


def options(settings: Settings) -> PaymentOptionsOut:
    return PaymentOptionsOut(
        providers=enabled_providers(settings),  # type: ignore[arg-type]
        plans=[
            PaymentPlanOut(months=m, price=plan_price(settings, m), currency="UZS")
            for m in PLAN_MONTHS
        ],
    )


def pay_url(settings: Settings, order: PaymentOrder) -> str | None:
    if order.status not in ("pending", "created"):
        return None
    if order.provider == "payme":
        params = [
            f"m={settings.payme_merchant_id}",
            f"ac.order_id={order.id}",
            f"a={order.amount * TIYIN}",
            "cr=UZS",
            "l=uz",
        ]
        if settings.payment_return_url:
            params.append(f"c={settings.payment_return_url}")
        token = base64.b64encode(";".join(params).encode()).decode()
        return f"{settings.payme_checkout_url.rstrip('/')}/{token}"
    query = {
        "service_id": settings.click_service_id,
        "merchant_id": settings.click_merchant_id,
        "amount": f"{order.amount}.00",
        "transaction_param": order.id,
    }
    if settings.payment_return_url:
        query["return_url"] = settings.payment_return_url
    return f"{CLICK_PAY_URL}?{urlencode(query)}"


async def to_out(session: AsyncSession, settings: Settings, order: PaymentOrder) -> PaymentOrderOut:
    expires_at = None
    if order.status == "paid":
        expires_at = await session.scalar(
            select(User.subscription_expires_at).where(User.id == order.user_id)
        )
    return PaymentOrderOut(
        id=order.id,
        provider=order.provider,  # type: ignore[arg-type]
        months=order.months,
        amount=order.amount,
        currency=order.currency,
        status=order.status,  # type: ignore[arg-type]
        created_at=order.created_at,
        paid_at=order.performed_at,
        expires_at=expires_at,
        pay_url=pay_url(settings, order),
    )


def unavailable() -> ApiError:
    return ApiError(503, "provider_unavailable", "To'lov tizimi hozircha ulanmagan")


async def create_order(
    session: AsyncSession, settings: Settings, actor: User, body: PaymentOrderIn
) -> PaymentOrder:
    if actor.role != "user":
        raise forbidden("not_a_student", "Faqat talaba abonement sotib ola oladi")
    if body.months not in PLAN_MONTHS:
        raise bad_request("invalid_plan", "Bunday abonement turi yo'q")
    if body.provider not in enabled_providers(settings):
        raise unavailable()
    amount = plan_price(settings, body.months)
    reusable = await session.scalar(
        select(PaymentOrder)
        .where(
            PaymentOrder.user_id == actor.id,
            PaymentOrder.provider == body.provider,
            PaymentOrder.months == body.months,
            PaymentOrder.amount == amount,
            PaymentOrder.status == "pending",
            PaymentOrder.created_at > datetime.now(UTC) - PENDING_REUSE,
        )
        .order_by(PaymentOrder.created_at.desc())
        .limit(1)
    )
    if reusable is not None:
        return reusable
    order = PaymentOrder(
        id=uuid.uuid4().hex,
        user_id=actor.id,
        provider=body.provider,
        months=body.months,
        amount=amount,
    )
    session.add(order)
    await session.commit()
    await session.refresh(order)
    return order


async def get_own_order(session: AsyncSession, actor: User, order_id: str) -> PaymentOrder:
    order = await session.get(PaymentOrder, order_id)
    if order is None or order.user_id != actor.id:
        raise not_found("To'lov topilmadi")
    return order


async def lock_order(session: AsyncSession, order_id: str) -> PaymentOrder | None:
    return await session.scalar(
        select(PaymentOrder).where(PaymentOrder.id == order_id).with_for_update()
    )


async def lock_by_trans_id(
    session: AsyncSession, provider: str, trans_id: str
) -> PaymentOrder | None:
    return await session.scalar(
        select(PaymentOrder)
        .where(PaymentOrder.provider == provider, PaymentOrder.provider_trans_id == trans_id)
        .with_for_update()
    )


async def fulfill(session: AsyncSession, settings: Settings, order: PaymentOrder) -> None:
    """Buyurtmani to'langan qiladi va abonementni faollashtiradi (commit chaqiruvchida)."""
    now = datetime.now(UTC)
    user = await session.get(User, order.user_id, with_for_update=True)
    if user is None:
        raise not_found("Foydalanuvchi topilmadi")
    start = now
    if user.subscription_expires_at is not None and user.subscription_expires_at > now:
        start = user.subscription_expires_at
    body = SubscriptionIn(
        start_date=start,
        months=order.months,
        days=0,
        price=order.amount,
        currency=order.currency,  # type: ignore[arg-type]
        paid_date=now,
    )
    zone = subscriptions_service.gym_zone(settings)
    subscription = await subscriptions_service.apply_subscription(session, user, body, zone)
    order.status = "paid"
    order.performed_at = now
    order.subscription_id = subscription.id


def cancel(order: PaymentOrder, reason: int | None) -> None:
    order.status = "canceled"
    order.canceled_at = datetime.now(UTC)
    order.cancel_reason = reason
