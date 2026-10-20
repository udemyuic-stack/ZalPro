import base64
import binascii
import hmac
import json
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.models import PaymentOrder
from zalpro_api.services import payments

PROVIDER = "payme"
TIMEOUT = timedelta(hours=12)
REASON_TIMEOUT = 4

ERR_PARSE = -32700
ERR_INVALID_REQUEST = -32600
ERR_METHOD_NOT_FOUND = -32601
ERR_AUTH = -32504
ERR_BAD_AMOUNT = -31001
ERR_TRANSACTION_NOT_FOUND = -31003
ERR_CANNOT_PERFORM = -31008
ERR_CANNOT_CANCEL = -31007
ERR_ORDER_NOT_FOUND = -31050
ERR_ORDER_NOT_PAYABLE = -31051
ERR_ORDER_BUSY = -31099

STATE_CREATED = 1
STATE_PERFORMED = 2
STATE_CANCELED = -1
STATE_CANCELED_AFTER_PERFORM = -2

MESSAGES = {
    ERR_PARSE: ("Ошибка парсинга JSON", "JSON xatosi", "JSON parse error"),
    ERR_INVALID_REQUEST: ("Неверный запрос", "Noto'g'ri so'rov", "Invalid request"),
    ERR_METHOD_NOT_FOUND: ("Метод не найден", "Metod topilmadi", "Method not found"),
    ERR_AUTH: ("Недостаточно привилегий", "Ruxsat yo'q", "Insufficient privilege"),
    ERR_BAD_AMOUNT: ("Неверная сумма", "Summa noto'g'ri", "Incorrect amount"),
    ERR_TRANSACTION_NOT_FOUND: ("Транзакция не найдена", "Tranzaksiya topilmadi", "Not found"),
    ERR_CANNOT_PERFORM: (
        "Невозможно выполнить операцию",
        "Amalni bajarib bo'lmaydi",
        "Unable to perform operation",
    ),
    ERR_CANNOT_CANCEL: (
        "Заказ выполнен, отмена невозможна",
        "Buyurtma bajarilgan, bekor qilib bo'lmaydi",
        "Order completed, cannot cancel",
    ),
    ERR_ORDER_NOT_FOUND: ("Заказ не найден", "Buyurtma topilmadi", "Order not found"),
    ERR_ORDER_NOT_PAYABLE: (
        "Заказ не доступен для оплаты",
        "Buyurtmani to'lab bo'lmaydi",
        "Order is not payable",
    ),
    ERR_ORDER_BUSY: (
        "Для заказа уже есть активная транзакция",
        "Buyurtmada faol tranzaksiya bor",
        "Order already has an active transaction",
    ),
}


class PaymeError(Exception):
    def __init__(self, code: int, data: str | None = None) -> None:
        super().__init__(code)
        self.code = code
        self.data = data

    def body(self) -> dict[str, Any]:
        ru, uz, en = MESSAGES[self.code]
        return {"code": self.code, "message": {"ru": ru, "uz": uz, "en": en}, "data": self.data}


def authorized(header: str | None, settings: Settings) -> bool:
    if not settings.payme_configured or not header or not header.startswith("Basic "):
        return False
    try:
        decoded = base64.b64decode(header[6:], validate=True).decode()
    except (binascii.Error, UnicodeDecodeError):
        return False
    expected = f"Paycom:{settings.payme_key}"
    return hmac.compare_digest(decoded.encode(), expected.encode())


def to_ms(moment: datetime | None) -> int:
    return 0 if moment is None else int(moment.timestamp() * 1000)


def state_of(order: PaymentOrder) -> int:
    if order.status == "paid":
        return STATE_PERFORMED
    if order.status == "canceled":
        return STATE_CANCELED_AFTER_PERFORM if order.performed_at else STATE_CANCELED
    return STATE_CREATED


def tiyin(order: PaymentOrder) -> int:
    return order.amount * payments.TIYIN


def check_amount(params: dict[str, Any], order: PaymentOrder) -> None:
    amount = params.get("amount")
    if isinstance(amount, bool) or not isinstance(amount, int) or amount != tiyin(order):
        raise PaymeError(ERR_BAD_AMOUNT)


def trans_id_of(params: dict[str, Any]) -> str:
    value = params.get("id")
    if not isinstance(value, str) or not value:
        raise PaymeError(ERR_INVALID_REQUEST)
    return value


async def find_order(session: AsyncSession, params: dict[str, Any], *, lock: bool) -> PaymentOrder:
    account = params.get("account")
    order_id = account.get("order_id") if isinstance(account, dict) else None
    if not isinstance(order_id, str) or not order_id:
        raise PaymeError(ERR_ORDER_NOT_FOUND, "order_id")
    if lock:
        order = await payments.lock_order(session, order_id)
    else:
        order = await session.get(PaymentOrder, order_id)
    if order is None or order.provider != PROVIDER:
        raise PaymeError(ERR_ORDER_NOT_FOUND, "order_id")
    return order


async def find_transaction(session: AsyncSession, params: dict[str, Any]) -> PaymentOrder:
    order = await payments.lock_by_trans_id(session, PROVIDER, trans_id_of(params))
    if order is None:
        raise PaymeError(ERR_TRANSACTION_NOT_FOUND)
    return order


async def expire_if_stale(session: AsyncSession, order: PaymentOrder) -> None:
    if order.status != "created" or order.transaction_at is None:
        return
    if datetime.now(UTC) - order.transaction_at <= TIMEOUT:
        return
    payments.cancel(order, REASON_TIMEOUT)
    await session.commit()
    raise PaymeError(ERR_CANNOT_PERFORM)


def create_result(order: PaymentOrder) -> dict[str, Any]:
    return {
        "create_time": to_ms(order.transaction_at),
        "transaction": order.id,
        "state": state_of(order),
    }


async def check_perform_transaction(
    session: AsyncSession, settings: Settings, params: dict[str, Any]
) -> dict[str, Any]:
    order = await find_order(session, params, lock=False)
    check_amount(params, order)
    if order.status == "created":
        raise PaymeError(ERR_ORDER_BUSY, "order_id")
    if order.status != "pending":
        raise PaymeError(ERR_ORDER_NOT_PAYABLE, "order_id")
    return {"allow": True}


async def create_transaction(
    session: AsyncSession, settings: Settings, params: dict[str, Any]
) -> dict[str, Any]:
    trans_id = trans_id_of(params)
    provider_time = params.get("time")
    if isinstance(provider_time, bool) or not isinstance(provider_time, int):
        raise PaymeError(ERR_INVALID_REQUEST)
    order = await find_order(session, params, lock=True)
    if order.provider_trans_id == trans_id:
        if order.status != "created":
            raise PaymeError(ERR_CANNOT_PERFORM)
        await expire_if_stale(session, order)
        return create_result(order)
    check_amount(params, order)
    taken = await session.scalar(
        select(PaymentOrder.id).where(
            PaymentOrder.provider == PROVIDER, PaymentOrder.provider_trans_id == trans_id
        )
    )
    if taken is not None:
        raise PaymeError(ERR_CANNOT_PERFORM)
    if order.status == "created":
        raise PaymeError(ERR_ORDER_BUSY, "order_id")
    if order.status != "pending":
        raise PaymeError(ERR_ORDER_NOT_PAYABLE, "order_id")
    order.status = "created"
    order.provider_trans_id = trans_id
    order.provider_time = provider_time
    order.transaction_at = datetime.now(UTC)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise PaymeError(ERR_CANNOT_PERFORM) from None
    return create_result(order)


async def perform_transaction(
    session: AsyncSession, settings: Settings, params: dict[str, Any]
) -> dict[str, Any]:
    order = await find_transaction(session, params)
    if order.status == "created":
        await expire_if_stale(session, order)
        await payments.fulfill(session, settings, order)
        await session.commit()
    elif order.status != "paid":
        raise PaymeError(ERR_CANNOT_PERFORM)
    return {
        "transaction": order.id,
        "perform_time": to_ms(order.performed_at),
        "state": state_of(order),
    }


async def cancel_transaction(
    session: AsyncSession, settings: Settings, params: dict[str, Any]
) -> dict[str, Any]:
    order = await find_transaction(session, params)
    if order.status == "paid":
        raise PaymeError(ERR_CANNOT_CANCEL)
    if order.status == "created":
        reason = params.get("reason")
        payments.cancel(order, reason if isinstance(reason, int) else None)
        await session.commit()
    return {
        "transaction": order.id,
        "cancel_time": to_ms(order.canceled_at),
        "state": state_of(order),
    }


def transaction_view(order: PaymentOrder) -> dict[str, Any]:
    return {
        "create_time": to_ms(order.transaction_at),
        "perform_time": to_ms(order.performed_at),
        "cancel_time": to_ms(order.canceled_at),
        "transaction": order.id,
        "state": state_of(order),
        "reason": order.cancel_reason,
    }


async def check_transaction(
    session: AsyncSession, settings: Settings, params: dict[str, Any]
) -> dict[str, Any]:
    order = await find_transaction(session, params)
    return transaction_view(order)


async def get_statement(
    session: AsyncSession, settings: Settings, params: dict[str, Any]
) -> dict[str, Any]:
    start, end = params.get("from"), params.get("to")
    if not all(isinstance(v, int) and not isinstance(v, bool) for v in (start, end)):
        raise PaymeError(ERR_INVALID_REQUEST)
    rows = await session.scalars(
        select(PaymentOrder)
        .where(
            PaymentOrder.provider == PROVIDER,
            PaymentOrder.provider_trans_id.is_not(None),
            PaymentOrder.provider_time >= start,
            PaymentOrder.provider_time <= end,
        )
        .order_by(PaymentOrder.provider_time, PaymentOrder.id)
    )
    return {
        "transactions": [
            {
                "id": order.provider_trans_id,
                "time": order.provider_time,
                "amount": tiyin(order),
                "account": {"order_id": order.id},
                **transaction_view(order),
            }
            for order in rows
        ]
    }


Method = Callable[[AsyncSession, Settings, dict[str, Any]], Awaitable[dict[str, Any]]]

METHODS: dict[str, Method] = {
    "CheckPerformTransaction": check_perform_transaction,
    "CreateTransaction": create_transaction,
    "PerformTransaction": perform_transaction,
    "CancelTransaction": cancel_transaction,
    "CheckTransaction": check_transaction,
    "GetStatement": get_statement,
}


def failure(request_id: Any, error: PaymeError) -> dict[str, Any]:
    return {"error": error.body(), "id": request_id}


async def handle(
    session: AsyncSession, settings: Settings, authorization: str | None, raw: bytes
) -> dict[str, Any]:
    try:
        payload = json.loads(raw)
    except ValueError:
        return failure(None, PaymeError(ERR_PARSE))
    if not isinstance(payload, dict):
        return failure(None, PaymeError(ERR_INVALID_REQUEST))
    request_id = payload.get("id")
    if not authorized(authorization, settings):
        return failure(request_id, PaymeError(ERR_AUTH))
    method = METHODS.get(str(payload.get("method")))
    params = payload.get("params")
    if method is None:
        return failure(request_id, PaymeError(ERR_METHOD_NOT_FOUND))
    if not isinstance(params, dict):
        return failure(request_id, PaymeError(ERR_INVALID_REQUEST))
    try:
        return {"result": await method(session, settings, params), "id": request_id}
    except PaymeError as error:
        await session.rollback()
        return failure(request_id, error)
