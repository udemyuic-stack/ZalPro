from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Message, Order, Product, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
ProductFactory = Callable[..., Awaitable[Product]]
OrderFactory = Callable[..., Awaitable[Order]]


async def messages_of(session: AsyncSession, chat_uid: str) -> list[Message]:
    statement = (
        select(Message)
        .where(Message.chat_uid == chat_uid)
        .order_by(Message.created_at, Message.id)
        .execution_options(populate_existing=True)
    )
    return list((await session.scalars(statement)).all())


@pytest.fixture
async def trainer(make_user: UserFactory) -> User:
    return await make_user(role="admin")


@pytest.fixture
async def student(make_user: UserFactory, trainer: User) -> User:
    return await make_user(trainer_id=trainer.id, name="Aziz")


async def test_order_creation_posts_system_message_from_client(
    client: AsyncClient,
    student: User,
    make_product: ProductFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(name="Venum", price=450000)

    response = await client.post(
        "/v1/orders",
        headers=auth_headers(student),
        json={"product_id": product.id, "qty": 2},
    )

    assert response.status_code == 201
    [message] = await messages_of(db_session, student.id)
    assert message.sender_id == student.id
    assert message.kind == "system"
    assert message.text == "🛒 Buyurtma: Venum × 2 — 900 000 so'm"


async def test_order_message_includes_size_color_and_dollar_currency(
    client: AsyncClient,
    student: User,
    make_product: ProductFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(
        name="Komplekt",
        price=35,
        currency="USD",
        sizes=["XL"],
        size_stock={"XL": 3},
        stock=3,
    )

    response = await client.post(
        "/v1/orders",
        headers=auth_headers(student),
        json={"product_id": product.id, "qty": 1, "size": "XL", "color": "sariq"},
    )

    assert response.status_code == 201
    [message] = await messages_of(db_session, student.id)
    assert message.text == "🛒 Buyurtma: Komplekt (XL, sariq) × 1 — 35 $"


async def test_failed_order_creation_posts_no_message(
    client: AsyncClient,
    student: User,
    make_product: ProductFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(active=False)

    response = await client.post(
        "/v1/orders", headers=auth_headers(student), json={"product_id": product.id, "qty": 1}
    )

    assert response.status_code == 409
    assert await messages_of(db_session, student.id) == []


@pytest.mark.parametrize(
    ("status", "text"),
    [
        ("given", "✅ Buyurtma berildi: Venum × 2 — 900 000 so'm"),
        ("canceled", "❌ Buyurtma bekor qilindi: Venum"),
    ],
)
async def test_status_change_posts_system_message_from_actor(
    client: AsyncClient,
    trainer: User,
    student: User,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
    status: str,
    text: str,
) -> None:
    product = await make_product(name="Venum", price=450000, stock=5)
    order = await make_order(
        student.id,
        product_id=product.id,
        product_name="Venum",
        price=450000,
        qty=2,
        trainer_id=trainer.id,
    )

    response = await client.patch(
        f"/v1/orders/{order.id}/status", headers=auth_headers(trainer), json={"status": status}
    )

    assert response.status_code == 200
    [message] = await messages_of(db_session, student.id)
    assert message.sender_id == trainer.id
    assert message.kind == "system"
    assert message.text == text


async def test_client_cancelling_own_order_posts_no_message(
    client: AsyncClient,
    student: User,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    order = await make_order(student.id)

    response = await client.patch(
        f"/v1/orders/{order.id}/status", headers=auth_headers(student), json={"status": "canceled"}
    )

    assert response.status_code == 200
    assert await messages_of(db_session, student.id) == []


async def test_status_change_failure_posts_no_message(
    client: AsyncClient,
    trainer: User,
    student: User,
    make_product: ProductFactory,
    make_order: OrderFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    product = await make_product(stock=1)
    order = await make_order(student.id, product_id=product.id, qty=5, trainer_id=trainer.id)

    response = await client.patch(
        f"/v1/orders/{order.id}/status", headers=auth_headers(trainer), json={"status": "given"}
    )

    assert response.status_code == 409
    assert await messages_of(db_session, student.id) == []


@pytest.mark.parametrize(
    ("days_left", "text"),
    [
        (3, "⏰ Abonementingiz 3 kundan keyin tugaydi"),
        (0, "⏰ Abonementingiz tugadi — yangilang"),
        (-2, "⏰ Abonementingiz tugadi — yangilang"),
    ],
)
async def test_reminder_posts_system_message_from_actor(
    client: AsyncClient,
    trainer: User,
    student: User,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
    days_left: int,
    text: str,
) -> None:
    response = await client.post(
        "/v1/reminders",
        headers=auth_headers(trainer),
        json={"client_id": student.id, "days_left": days_left},
    )

    assert response.status_code == 201
    [message] = await messages_of(db_session, student.id)
    assert message.sender_id == trainer.id
    assert message.kind == "system"
    assert message.text == text


async def test_forbidden_reminder_posts_no_message(
    client: AsyncClient,
    student: User,
    make_user: UserFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    other = await make_user()

    response = await client.post(
        "/v1/reminders",
        headers=auth_headers(other),
        json={"client_id": student.id, "days_left": 3},
    )

    assert response.status_code == 403
    assert await messages_of(db_session, student.id) == []


async def test_system_message_reaches_hub_subscribers_after_commit(
    app: Any,
    client: AsyncClient,
    trainer: User,
    student: User,
    auth_headers: HeadersFactory,
) -> None:
    queue = app.state.hub.subscribe(student.id)
    try:
        response = await client.post(
            "/v1/reminders",
            headers=auth_headers(trainer),
            json={"client_id": student.id, "days_left": 3},
        )
        payload = queue.get_nowait()
    finally:
        app.state.hub.unsubscribe(student.id, queue)

    assert response.status_code == 201
    assert payload["chat_uid"] == student.id
    assert payload["sender_id"] == trainer.id
    assert payload["kind"] == "system"
    assert payload["text"] == "⏰ Abonementingiz 3 kundan keyin tugaydi"
    assert app.state.hub.subscriber_count(student.id) == 0
