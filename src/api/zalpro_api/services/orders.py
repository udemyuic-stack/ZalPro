from datetime import UTC, date, datetime

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import ApiError, conflict, not_found
from zalpro_api.models import Order, Product, User
from zalpro_api.schemas.order import OrderIn
from zalpro_api.services import permissions, system_messages
from zalpro_api.services.messages import stage_message
from zalpro_api.services.reminders import window_bounds

STATUS_NEW = "new"
STATUS_GIVEN = "given"
STATUS_CANCELED = "canceled"


def size_error(message: str) -> ApiError:
    return ApiError(422, "validation_error", message)


async def create_order(session: AsyncSession, actor: User, body: OrderIn) -> Order:
    product = await session.get(Product, body.product_id)
    if product is None:
        raise not_found("Tovar topilmadi")
    if not product.active:
        raise conflict("product_inactive", "Tovar sotuvda emas")
    if product.sizes:
        if body.size not in product.sizes:
            raise size_error("O'lcham tovar o'lchamlaridan biri bo'lishi kerak")
    elif body.size:
        raise size_error("Bu tovarda o'lcham yo'q")
    gym_id = ""
    if actor.trainer_id:
        trainer = await session.get(User, actor.trainer_id)
        gym_id = (trainer.gym_id or "") if trainer is not None else ""
    order = Order(
        client_id=actor.id,
        client_name=actor.name,
        client_phone=actor.phone,
        trainer_id=actor.trainer_id or "",
        gym_id=gym_id,
        product_id=product.id,
        product_name=product.name,
        category=product.category,
        size=body.size,
        color=body.color,
        price=product.price,
        currency=product.currency,
        qty=body.qty,
        status=STATUS_NEW,
    )
    session.add(order)
    await session.flush()
    await stage_message(
        session, actor.id, actor.id, system_messages.order_created_text(order), "system"
    )
    await session.commit()
    await session.refresh(order)
    return order


async def list_orders(
    session: AsyncSession,
    scope: permissions.OrderScope,
    start: date | None,
    end: date | None,
    status: str | None,
    timezone: str,
) -> list[Order]:
    if scope.empty:
        return []
    statement = select(Order)
    if start is not None and end is not None:
        lower, upper = window_bounds(start, end, timezone)
        statement = statement.where(Order.created_at >= lower, Order.created_at < upper)
    if scope.column is not None:
        statement = statement.where(getattr(Order, scope.column) == scope.value)
    if status is not None:
        statement = statement.where(Order.status == status)
    statement = statement.order_by(Order.created_at.desc(), Order.id.desc())
    return list((await session.scalars(statement)).all())


async def get_order_or_404(session: AsyncSession, order_id: str) -> Order:
    order = await session.get(Order, order_id)
    if order is None:
        raise not_found("Buyurtma topilmadi")
    return order


async def set_status(session: AsyncSession, actor: User, order_id: str, status: str) -> Order:
    order = await get_order_or_404(session, order_id)
    permissions.ensure_can_set_order_status(actor, order, status)
    locked = await session.scalar(
        select(Order)
        .where(Order.id == order_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if locked is None:
        raise not_found("Buyurtma topilmadi")
    if locked.status != STATUS_NEW:
        raise conflict("invalid_status_transition", "Buyurtma holatini o'zgartirib bo'lmaydi")
    now = datetime.now(UTC)
    if status == STATUS_GIVEN:
        locked.cost_price = await take_stock(session, locked)
        locked.given_by = actor.id
        locked.given_at = now
    locked.status = status
    locked.updated_at = now
    if actor.id != locked.client_id:
        text = (
            system_messages.order_given_text(locked)
            if status == STATUS_GIVEN
            else system_messages.order_canceled_text(locked)
        )
        await stage_message(session, locked.client_id, actor.id, text, "system")
    await session.commit()
    await session.refresh(locked)
    return locked


async def take_stock(session: AsyncSession, order: Order) -> int:
    product = await session.scalar(
        select(Product)
        .where(Product.id == order.product_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if product is None:
        raise conflict("product_missing", "Tovar topilmadi, buyurtmani topshirib bo'lmaydi")
    if product.sizes:
        available = product.size_stock.get(order.size, 0)
        if available < order.qty:
            raise conflict("insufficient_stock", "Omborda tovar yetarli emas")
        size_stock = dict(product.size_stock)
        size_stock[order.size] = available - order.qty
        product.size_stock = size_stock
        product.stock = sum(size_stock.values())
        return product.cost_price
    if product.stock < order.qty:
        raise conflict("insufficient_stock", "Omborda tovar yetarli emas")
    product.stock -= order.qty
    return product.cost_price


async def delete_order(session: AsyncSession, order_id: str) -> None:
    result = await session.execute(delete(Order).where(Order.id == order_id))
    if result.rowcount == 0:
        raise not_found("Buyurtma topilmadi")
    await session.commit()
