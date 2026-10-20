import asyncio
import base64
import hashlib
from collections.abc import AsyncIterator, Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.models import Membership, PaymentOrder, Subscription, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

PAYME_KEY = "payme-secret-key"
CLICK_SECRET = "click-secret"
CLICK_SERVICE = "4242"
MONTH_PRICE = 500000


@pytest_asyncio.fixture(autouse=True)
async def payment_settings(app: Any, settings: Settings) -> AsyncIterator[Settings]:
    configured = settings.model_copy(
        update={
            "subscription_month_price": MONTH_PRICE,
            "payme_merchant_id": "merchant-1",
            "payme_key": PAYME_KEY,
            "click_service_id": CLICK_SERVICE,
            "click_merchant_id": "777",
            "click_secret_key": CLICK_SECRET,
            "payment_return_url": "https://app.test/return",
        }
    )
    original = app.state.settings
    app.state.settings = configured
    yield configured
    app.state.settings = original


def payme_auth(key: str = PAYME_KEY) -> dict[str, str]:
    token = base64.b64encode(f"Paycom:{key}".encode()).decode()
    return {"Authorization": f"Basic {token}"}


async def rpc(
    client: AsyncClient, method: str, params: dict[str, Any], headers: dict[str, str] | None = None
) -> dict[str, Any]:
    response = await client.post(
        "/v1/payments/payme",
        json={"jsonrpc": "2.0", "id": 7, "method": method, "params": params},
        headers=payme_auth() if headers is None else headers,
    )
    assert response.status_code == 200
    return response.json()


async def new_order(
    client: AsyncClient, headers: dict[str, str], provider: str = "payme", months: int = 1
) -> dict[str, Any]:
    response = await client.post(
        "/v1/payments/orders", json={"months": months, "provider": provider}, headers=headers
    )
    assert response.status_code == 201, response.text
    return response.json()


def click_form(order: dict[str, Any], action: int, **fields: Any) -> dict[str, str]:
    form = {
        "click_trans_id": "9001",
        "service_id": CLICK_SERVICE,
        "click_paydoc_id": "5001",
        "merchant_trans_id": order["id"],
        "amount": f"{order['amount']}.00",
        "action": str(action),
        "error": "0",
        "error_note": "Success",
        "sign_time": "2026-10-20 12:00:00",
        **{key: str(value) for key, value in fields.items()},
    }
    parts = [form["click_trans_id"], form["service_id"], CLICK_SECRET, form["merchant_trans_id"]]
    if action == 1:
        parts.append(form["merchant_prepare_id"])
    parts += [form["amount"], form["action"], form["sign_time"]]
    form.setdefault("sign_string", hashlib.md5("".join(parts).encode()).hexdigest())
    return form


async def count_rows(db_session: AsyncSession, model: type) -> int:
    return await db_session.scalar(select(func.count()).select_from(model)) or 0


async def fresh(db_session: AsyncSession, order_id: str) -> PaymentOrder:
    db_session.expire_all()
    return await db_session.get(PaymentOrder, order_id)  # type: ignore[return-value]


@pytest.fixture
async def student(make_user: UserFactory) -> User:
    return await make_user()


async def test_options_list_plans_and_providers(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get("/v1/payments/options", headers=auth_headers(student))
    assert response.status_code == 200
    body = response.json()
    assert body["providers"] == ["payme", "click"]
    assert [(p["months"], p["price"]) for p in body["plans"]] == [
        (1, 500000),
        (3, 1500000),
        (6, 3000000),
        (12, 6000000),
    ]


async def test_options_requires_auth(client: AsyncClient) -> None:
    assert (await client.get("/v1/payments/options")).status_code == 401


async def test_create_order_returns_payme_checkout_url(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "payme", 3)
    assert order["status"] == "pending"
    assert order["amount"] == 1500000
    url = order["pay_url"]
    assert url.startswith("https://checkout.paycom.uz/")
    decoded = base64.b64decode(url.rsplit("/", 1)[1]).decode()
    assert f"ac.order_id={order['id']}" in decoded
    assert "m=merchant-1" in decoded
    assert "a=150000000" in decoded
    assert "c=https://app.test/return" in decoded


async def test_create_order_returns_click_url(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click", 1)
    assert order["pay_url"].startswith("https://my.click.uz/services/pay?")
    assert f"transaction_param={order['id']}" in order["pay_url"]
    assert "service_id=4242" in order["pay_url"]
    assert "amount=500000.00" in order["pay_url"]


async def test_create_order_reuses_fresh_pending_order(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    first = await new_order(client, auth_headers(student))
    second = await new_order(client, auth_headers(student))
    assert first["id"] == second["id"]
    assert await count_rows(db_session, PaymentOrder) == 1
    other = await new_order(client, auth_headers(student), months=3)
    assert other["id"] != first["id"]


@pytest.mark.parametrize(
    "body", [{"months": 2, "provider": "payme"}, {"months": 0, "provider": "click"}]
)
async def test_create_order_rejects_unknown_plan(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, body: dict[str, Any]
) -> None:
    response = await client.post("/v1/payments/orders", json=body, headers=auth_headers(student))
    assert response.status_code == 400
    assert response.json()["detail"]["code"] == "invalid_plan"


async def test_create_order_validates_body(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    for body in (
        {"months": 1, "provider": "stripe"},
        {"months": "1", "provider": "payme"},
        {"months": 1, "provider": "payme", "price": 1},
    ):
        response = await client.post(
            "/v1/payments/orders", json=body, headers=auth_headers(student)
        )
        assert response.status_code == 422


async def test_create_order_ignores_client_price(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        "/v1/payments/orders",
        json={"months": 1, "provider": "payme", "amount": 1},
        headers=auth_headers(student),
    )
    assert response.status_code == 422


@pytest.mark.parametrize("role", ["admin", "owner", "barmen"])
async def test_staff_cannot_buy(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    staff = await make_user(role)
    response = await client.post(
        "/v1/payments/orders", json={"months": 1, "provider": "payme"}, headers=auth_headers(staff)
    )
    assert response.status_code == 403


async def test_unconfigured_provider_is_unavailable(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    payment_settings: Settings,
    app: Any,
) -> None:
    app.state.settings = payment_settings.model_copy(update={"click_secret_key": ""})
    response = await client.post(
        "/v1/payments/orders",
        json={"months": 1, "provider": "click"},
        headers=auth_headers(student),
    )
    assert response.status_code == 503
    options = await client.get("/v1/payments/options", headers=auth_headers(student))
    assert options.json()["providers"] == ["payme"]


async def test_read_order_is_owner_only(
    client: AsyncClient, student: User, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student))
    other = await make_user()
    own = await client.get(f"/v1/payments/orders/{order['id']}", headers=auth_headers(student))
    assert own.status_code == 200
    assert own.json()["status"] == "pending"
    stranger = await client.get(f"/v1/payments/orders/{order['id']}", headers=auth_headers(other))
    assert stranger.status_code == 404
    missing = await client.get("/v1/payments/orders/nope", headers=auth_headers(student))
    assert missing.status_code == 404


# ---- Payme ----


async def test_payme_rejects_bad_credentials(client: AsyncClient) -> None:
    for headers in (
        {},
        payme_auth("wrong"),
        {"Authorization": "Basic !!!"},
        {"Authorization": "Bearer x"},
    ):
        body = await rpc(client, "CheckTransaction", {"id": "x"}, headers)
        assert body["error"]["code"] == -32504
        assert body["id"] == 7


async def test_payme_rejects_when_not_configured(
    client: AsyncClient, payment_settings: Settings, app: Any
) -> None:
    app.state.settings = payment_settings.model_copy(update={"payme_key": ""})
    body = await rpc(
        client, "CheckTransaction", {"id": "x"}, {"Authorization": "Basic UGF5Y29tOg=="}
    )
    assert body["error"]["code"] == -32504


async def test_payme_malformed_requests(client: AsyncClient) -> None:
    broken = await client.post("/v1/payments/payme", content=b"{", headers=payme_auth())
    assert broken.json()["error"]["code"] == -32700
    listed = await client.post("/v1/payments/payme", json=[1], headers=payme_auth())
    assert listed.json()["error"]["code"] == -32600
    assert (await rpc(client, "Nope", {}))["error"]["code"] == -32601
    no_params = await client.post(
        "/v1/payments/payme",
        json={"id": 1, "method": "CheckTransaction", "params": []},
        headers=payme_auth(),
    )
    assert no_params.json()["error"]["code"] == -32600


async def test_payme_check_perform(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student))
    ok = await rpc(
        client,
        "CheckPerformTransaction",
        {"amount": 50000000, "account": {"order_id": order["id"]}},
    )
    assert ok["result"] == {"allow": True}
    wrong = await rpc(
        client, "CheckPerformTransaction", {"amount": 100, "account": {"order_id": order["id"]}}
    )
    assert wrong["error"]["code"] == -31001
    missing = await rpc(
        client, "CheckPerformTransaction", {"amount": 100, "account": {"order_id": "zzz"}}
    )
    assert missing["error"]["code"] == -31050
    assert missing["error"]["data"] == "order_id"
    no_account = await rpc(client, "CheckPerformTransaction", {"amount": 100, "account": {}})
    assert no_account["error"]["code"] == -31050


async def test_payme_click_order_is_not_payable_via_payme(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    body = await rpc(
        client,
        "CheckPerformTransaction",
        {"amount": 50000000, "account": {"order_id": order["id"]}},
    )
    assert body["error"]["code"] == -31050


async def create_tx(
    client: AsyncClient, order: dict[str, Any], trans_id: str = "tx-1", amount: int | None = None
) -> dict[str, Any]:
    return await rpc(
        client,
        "CreateTransaction",
        {
            "id": trans_id,
            "time": 1760000000000,
            "amount": order["amount"] * 100 if amount is None else amount,
            "account": {"order_id": order["id"]},
        },
    )


async def test_payme_full_flow_activates_subscription(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    uid = student.id
    headers = auth_headers(student)
    order = await new_order(client, headers, "payme", 3)
    created = await create_tx(client, order)
    assert created["result"]["state"] == 1
    assert created["result"]["transaction"] == order["id"]
    assert created["result"]["create_time"] > 0
    assert (await client.get(f"/v1/payments/orders/{order['id']}", headers=headers)).json()[
        "status"
    ] == "created"

    performed = await rpc(client, "PerformTransaction", {"id": "tx-1"})
    assert performed["result"]["state"] == 2
    assert performed["result"]["perform_time"] > 0

    status = (await client.get(f"/v1/payments/orders/{order['id']}", headers=headers)).json()
    assert status["status"] == "paid"
    assert status["pay_url"] is None
    assert status["expires_at"] is not None

    subscriptions = (await client.get(f"/v1/users/{uid}/subscriptions", headers=headers)).json()
    assert len(subscriptions) == 1
    assert subscriptions[0]["months"] == 3
    assert subscriptions[0]["price"] == 1500000
    assert subscriptions[0]["currency"] == "UZS"
    assert subscriptions[0]["paid_date"] is not None

    db_session.expire_all()
    user = await db_session.get(User, uid)
    assert user is not None
    assert user.subscription_expires_at is not None
    membership = await db_session.get(Membership, student.id)
    assert membership is not None
    assert membership.months == 3
    assert membership.expires_at == user.subscription_expires_at
    stored = await fresh(db_session, order["id"])
    assert stored.status == "paid"
    assert stored.subscription_id == subscriptions[0]["id"]


async def test_payme_create_is_idempotent(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student))
    first = await create_tx(client, order)
    second = await create_tx(client, order)
    assert first["result"] == second["result"]
    assert await count_rows(db_session, PaymentOrder) == 1


async def test_payme_create_checks_amount_and_order_state(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student))
    assert (await create_tx(client, order, amount=1))["error"]["code"] == -31001
    assert (await create_tx(client, order))["result"]["state"] == 1
    busy = await create_tx(client, order, trans_id="tx-2")
    assert busy["error"]["code"] == -31099
    await rpc(client, "PerformTransaction", {"id": "tx-1"})
    done = await create_tx(client, order, trans_id="tx-3")
    assert done["error"]["code"] == -31051
    replay_paid = await create_tx(client, order)
    assert replay_paid["error"]["code"] == -31008


async def test_payme_transaction_id_cannot_be_reused_for_other_order(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    first = await new_order(client, auth_headers(student), months=1)
    second = await new_order(client, auth_headers(student), months=3)
    assert (await create_tx(client, first))["result"]["state"] == 1
    clash = await create_tx(client, second)
    assert clash["error"]["code"] == -31008


async def test_payme_perform_is_idempotent(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student))
    await create_tx(client, order)
    first = await rpc(client, "PerformTransaction", {"id": "tx-1"})
    second = await rpc(client, "PerformTransaction", {"id": "tx-1"})
    assert first["result"] == second["result"]
    assert await count_rows(db_session, Subscription) == 1


async def test_payme_concurrent_performs_make_one_subscription(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student))
    await create_tx(client, order)
    results = await asyncio.gather(
        *(rpc(client, "PerformTransaction", {"id": "tx-1"}) for _ in range(5))
    )
    assert all(item["result"]["state"] == 2 for item in results)
    assert len({item["result"]["perform_time"] for item in results}) == 1
    assert await count_rows(db_session, Subscription) == 1


async def test_payme_unknown_transaction(client: AsyncClient) -> None:
    for method in ("PerformTransaction", "CheckTransaction"):
        assert (await rpc(client, method, {"id": "none"}))["error"]["code"] == -31003
    cancel = await rpc(client, "CancelTransaction", {"id": "none", "reason": 1})
    assert cancel["error"]["code"] == -31003
    assert (await rpc(client, "PerformTransaction", {}))["error"]["code"] == -32600


async def test_payme_cancel_before_perform(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student))
    await create_tx(client, order)
    canceled = await rpc(client, "CancelTransaction", {"id": "tx-1", "reason": 3})
    assert canceled["result"]["state"] == -1
    assert canceled["result"]["cancel_time"] > 0
    again = await rpc(client, "CancelTransaction", {"id": "tx-1", "reason": 3})
    assert again["result"] == canceled["result"]
    check = await rpc(client, "CheckTransaction", {"id": "tx-1"})
    assert check["result"]["state"] == -1
    assert check["result"]["reason"] == 3
    assert (await rpc(client, "PerformTransaction", {"id": "tx-1"}))["error"]["code"] == -31008
    assert await count_rows(db_session, Subscription) == 0
    retry = await create_tx(client, order, trans_id="tx-9")
    assert retry["error"]["code"] == -31051


async def test_payme_performed_transaction_cannot_be_canceled(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student))
    await create_tx(client, order)
    await rpc(client, "PerformTransaction", {"id": "tx-1"})
    result = await rpc(client, "CancelTransaction", {"id": "tx-1", "reason": 5})
    assert result["error"]["code"] == -31007
    assert await count_rows(db_session, Subscription) == 1
    check = await rpc(client, "CheckTransaction", {"id": "tx-1"})
    assert check["result"]["state"] == 2
    assert check["result"]["reason"] is None


async def test_payme_stale_transaction_times_out(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student))
    await create_tx(client, order)
    stored = await fresh(db_session, order["id"])
    stored.transaction_at = datetime.now(UTC) - timedelta(hours=13)
    await db_session.commit()
    result = await rpc(client, "PerformTransaction", {"id": "tx-1"})
    assert result["error"]["code"] == -31008
    check = await rpc(client, "CheckTransaction", {"id": "tx-1"})
    assert check["result"]["state"] == -1
    assert check["result"]["reason"] == 4
    assert await count_rows(db_session, Subscription) == 0


async def test_payme_get_statement(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student))
    await new_order(client, auth_headers(student), months=3)
    await create_tx(client, order)
    await rpc(client, "PerformTransaction", {"id": "tx-1"})
    inside = await rpc(client, "GetStatement", {"from": 1759999999999, "to": 1760000000001})
    [item] = inside["result"]["transactions"]
    assert item["id"] == "tx-1"
    assert item["account"] == {"order_id": order["id"]}
    assert item["amount"] == 50000000
    assert item["state"] == 2
    outside = await rpc(client, "GetStatement", {"from": 1, "to": 2})
    assert outside["result"]["transactions"] == []
    assert (await rpc(client, "GetStatement", {"from": "a", "to": 2}))["error"]["code"] == -32600


async def test_renewal_extends_from_current_expiry(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    uid = student.id
    current_end = datetime.now(UTC).replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(
        days=10
    )
    user = await db_session.get(User, uid)
    assert user is not None
    user.subscription_expires_at = current_end
    await db_session.commit()
    order = await new_order(client, auth_headers(student), months=1)
    await create_tx(client, order)
    await rpc(client, "PerformTransaction", {"id": "tx-1"})
    subs = (
        await client.get(f"/v1/users/{uid}/subscriptions", headers=auth_headers(student))
    ).json()
    assert datetime.fromisoformat(subs[0]["start_date"]) == current_end
    db_session.expire_all()
    user = await db_session.get(User, uid)
    assert user is not None
    assert user.subscription_expires_at is not None
    assert user.subscription_expires_at > current_end + timedelta(days=27)


async def test_expired_subscription_restarts_from_now(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    uid = student.id
    user = await db_session.get(User, uid)
    assert user is not None
    user.subscription_expires_at = datetime.now(UTC) - timedelta(days=40)
    await db_session.commit()
    order = await new_order(client, auth_headers(student))
    await create_tx(client, order)
    await rpc(client, "PerformTransaction", {"id": "tx-1"})
    db_session.expire_all()
    user = await db_session.get(User, uid)
    assert user is not None
    assert user.subscription_expires_at is not None
    assert user.subscription_expires_at > datetime.now(UTC) + timedelta(days=25)


# ---- Click ----


async def post_click(client: AsyncClient, step: str, form: dict[str, str]) -> dict[str, Any]:
    response = await client.post(f"/v1/payments/click/{step}", data=form)
    assert response.status_code == 200
    return response.json()


async def test_click_full_flow_activates_subscription(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    headers = auth_headers(student)
    order = await new_order(client, headers, "click", 6)
    prepared = await post_click(client, "prepare", click_form(order, 0))
    assert prepared["error"] == 0
    assert prepared["click_trans_id"] == 9001
    assert prepared["merchant_trans_id"] == order["id"]
    prepare_id = prepared["merchant_prepare_id"]
    assert (await client.get(f"/v1/payments/orders/{order['id']}", headers=headers)).json()[
        "status"
    ] == "created"

    completed = await post_click(
        client, "complete", click_form(order, 1, merchant_prepare_id=prepare_id)
    )
    assert completed["error"] == 0
    assert completed["merchant_confirm_id"] == prepare_id

    status = (await client.get(f"/v1/payments/orders/{order['id']}", headers=headers)).json()
    assert status["status"] == "paid"
    subs = (await client.get(f"/v1/users/{student.id}/subscriptions", headers=headers)).json()
    assert [(s["months"], s["price"]) for s in subs] == [(6, 3000000)]
    assert await count_rows(db_session, Membership) == 1


async def test_click_prepare_is_repeatable(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    first = await post_click(client, "prepare", click_form(order, 0))
    second = await post_click(client, "prepare", click_form(order, 0))
    assert first == second


async def test_click_rejects_bad_sign(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    body = await post_click(client, "prepare", click_form(order, 0, sign_string="0" * 32))
    assert body["error"] == -1
    tampered = click_form(order, 0)
    tampered["amount"] = "1.00"
    assert (await post_click(client, "prepare", tampered))["error"] == -1


async def test_click_rejects_wrong_amount_and_unknown_order(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    wrong = click_form({**order, "amount": 1}, 0)
    assert (await post_click(client, "prepare", wrong))["error"] == -2
    ghost = click_form({**order, "id": "ghost"}, 0)
    assert (await post_click(client, "prepare", ghost))["error"] == -5


async def test_click_payme_order_is_unknown_to_click(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "payme")
    assert (await post_click(client, "prepare", click_form(order, 0)))["error"] == -5


async def test_click_rejects_wrong_action_and_missing_fields(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    wrong_action = click_form(order, 1, merchant_prepare_id=1)
    assert (await post_click(client, "prepare", wrong_action))["error"] == -3
    assert (await post_click(client, "prepare", {"click_trans_id": "1"}))["error"] == -8
    empty = await client.post("/v1/payments/click/complete")
    assert empty.status_code == 200
    assert empty.json()["error"] == -8
    other_service = click_form(order, 0, service_id="1")
    assert (await post_click(client, "prepare", other_service))["error"] == -8


async def test_click_complete_requires_matching_prepare(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    prepared = await post_click(client, "prepare", click_form(order, 0))
    wrong_id = click_form(order, 1, merchant_prepare_id=prepared["merchant_prepare_id"] + 1)
    assert (await post_click(client, "complete", wrong_id))["error"] == -6
    other_trans = click_form(
        order, 1, merchant_prepare_id=prepared["merchant_prepare_id"], click_trans_id=123
    )
    assert (await post_click(client, "complete", other_trans))["error"] == -6


async def test_click_complete_without_prepare(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    body = await post_click(client, "complete", click_form(order, 1, merchant_prepare_id=1))
    assert body["error"] == -6


async def test_click_repeated_complete_is_already_paid(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    prepared = await post_click(client, "prepare", click_form(order, 0))
    form = click_form(order, 1, merchant_prepare_id=prepared["merchant_prepare_id"])
    assert (await post_click(client, "complete", form))["error"] == 0
    assert (await post_click(client, "complete", form))["error"] == -4
    assert (await post_click(client, "prepare", click_form(order, 0)))["error"] == -4
    assert await count_rows(db_session, Subscription) == 1


async def test_click_concurrent_completes_make_one_subscription(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    prepared = await post_click(client, "prepare", click_form(order, 0))
    form = click_form(order, 1, merchant_prepare_id=prepared["merchant_prepare_id"])
    results = await asyncio.gather(*(post_click(client, "complete", form) for _ in range(5)))
    assert sorted(item["error"] for item in results) == [-4, -4, -4, -4, 0]
    assert await count_rows(db_session, Subscription) == 1


async def test_click_failed_payment_cancels_order(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    prepared = await post_click(client, "prepare", click_form(order, 0))
    failed = click_form(order, 1, merchant_prepare_id=prepared["merchant_prepare_id"], error=-5017)
    assert (await post_click(client, "complete", failed))["error"] == -9
    assert (await fresh(db_session, order["id"])).status == "canceled"
    assert await count_rows(db_session, Subscription) == 0
    late = click_form(order, 1, merchant_prepare_id=prepared["merchant_prepare_id"])
    assert (await post_click(client, "complete", late))["error"] == -9
    assert (await post_click(client, "prepare", click_form(order, 0)))["error"] == -9


async def test_click_not_configured_rejects(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    payment_settings: Settings,
    app: Any,
) -> None:
    order = await new_order(client, auth_headers(student), "click")
    app.state.settings = payment_settings.model_copy(update={"click_secret_key": ""})
    assert (await post_click(client, "prepare", click_form(order, 0)))["error"] == -8
