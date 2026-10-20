import hashlib
import hmac
from collections.abc import Mapping
from decimal import Decimal, InvalidOperation
from typing import Any

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.models import PaymentOrder
from zalpro_api.services import payments

PROVIDER = "click"
ACTION_PREPARE = 0
ACTION_COMPLETE = 1

OK = 0
ERR_SIGN = -1
ERR_AMOUNT = -2
ERR_ACTION = -3
ERR_ALREADY_PAID = -4
ERR_ORDER_NOT_FOUND = -5
ERR_TRANSACTION_NOT_FOUND = -6
ERR_UPDATE_FAILED = -7
ERR_REQUEST = -8
ERR_CANCELED = -9

NOTES = {
    OK: "Success",
    ERR_SIGN: "SIGN CHECK FAILED!",
    ERR_AMOUNT: "Incorrect parameter amount",
    ERR_ACTION: "Action not found",
    ERR_ALREADY_PAID: "Already paid",
    ERR_ORDER_NOT_FOUND: "User does not exist",
    ERR_TRANSACTION_NOT_FOUND: "Transaction does not exist",
    ERR_UPDATE_FAILED: "Failed to update user",
    ERR_REQUEST: "Error in request from click",
    ERR_CANCELED: "Transaction cancelled",
}

PREPARE_FIELDS = (
    "click_trans_id",
    "service_id",
    "merchant_trans_id",
    "amount",
    "action",
    "sign_time",
    "sign_string",
)
COMPLETE_FIELDS = (*PREPARE_FIELDS, "merchant_prepare_id")


def sign(form: Mapping[str, str], secret: str) -> str:
    parts = [form["click_trans_id"], form["service_id"], secret, form["merchant_trans_id"]]
    if form["action"] == str(ACTION_COMPLETE):
        parts.append(form["merchant_prepare_id"])
    parts += [form["amount"], form["action"], form["sign_time"]]
    return hashlib.md5("".join(parts).encode(), usedforsecurity=False).hexdigest()  # noqa: S324


def reply(code: int, form: Mapping[str, str], **extra: Any) -> dict[str, Any]:
    body: dict[str, Any] = {
        "click_trans_id": _int_or_raw(form.get("click_trans_id")),
        "merchant_trans_id": form.get("merchant_trans_id", ""),
        **extra,
        "error": code,
        "error_note": NOTES[code],
    }
    return body


def _int_or_raw(value: str | None) -> int | str:
    if value is None:
        return ""
    return int(value) if value.isdigit() else value


def amount_matches(raw: str, order: PaymentOrder) -> bool:
    try:
        return Decimal(raw) == Decimal(order.amount)
    except InvalidOperation:
        return False


async def prepare(
    session: AsyncSession, settings: Settings, form: Mapping[str, str]
) -> dict[str, Any]:
    if (early := precheck(settings, form, PREPARE_FIELDS, ACTION_PREPARE)) is not None:
        return early
    order = await payments.lock_order(session, form["merchant_trans_id"])
    if order is None or order.provider != PROVIDER:
        return reply(ERR_ORDER_NOT_FOUND, form)
    if not amount_matches(form["amount"], order):
        return reply(ERR_AMOUNT, form)
    if order.status == "paid":
        return reply(ERR_ALREADY_PAID, form)
    if order.status == "canceled":
        return reply(ERR_CANCELED, form)
    order.status = "created"
    order.provider_trans_id = form["click_trans_id"]
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        return reply(ERR_UPDATE_FAILED, form)
    return reply(OK, form, merchant_prepare_id=order.seq)


async def complete(
    session: AsyncSession, settings: Settings, form: Mapping[str, str]
) -> dict[str, Any]:
    if (early := precheck(settings, form, COMPLETE_FIELDS, ACTION_COMPLETE)) is not None:
        return early
    order = await payments.lock_order(session, form["merchant_trans_id"])
    if order is None or order.provider != PROVIDER:
        return reply(ERR_ORDER_NOT_FOUND, form)
    if form["merchant_prepare_id"] != str(order.seq) or (
        order.provider_trans_id != form["click_trans_id"]
    ):
        return reply(ERR_TRANSACTION_NOT_FOUND, form)
    if not amount_matches(form["amount"], order):
        return reply(ERR_AMOUNT, form)
    if order.status == "paid":
        return reply(ERR_ALREADY_PAID, form)
    if order.status == "canceled":
        return reply(ERR_CANCELED, form)
    if order.status != "created":
        return reply(ERR_TRANSACTION_NOT_FOUND, form)
    if _failed_on_click(form):
        payments.cancel(order, None)
        await session.commit()
        return reply(ERR_CANCELED, form)
    await payments.fulfill(session, settings, order)
    await session.commit()
    return reply(OK, form, merchant_confirm_id=order.seq)


def _failed_on_click(form: Mapping[str, str]) -> bool:
    try:
        return int(form.get("error", "0")) < 0
    except ValueError:
        return True


def precheck(
    settings: Settings, form: Mapping[str, str], fields: tuple[str, ...], action: int
) -> dict[str, Any] | None:
    if not settings.click_configured:
        return reply(ERR_REQUEST, form)
    if any(name not in form for name in fields):
        return reply(ERR_REQUEST, form)
    if form["action"] == str(ACTION_COMPLETE) and "merchant_prepare_id" not in form:
        return reply(ERR_REQUEST, form)
    if not hmac.compare_digest(
        sign(form, settings.click_secret_key).encode(), form["sign_string"].encode()
    ):
        return reply(ERR_SIGN, form)
    if form["action"] != str(action):
        return reply(ERR_ACTION, form)
    if form["service_id"] != settings.click_service_id:
        return reply(ERR_REQUEST, form)
    return None
