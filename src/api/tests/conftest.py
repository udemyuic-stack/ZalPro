import itertools
import os
import uuid
from collections.abc import AsyncIterator, Awaitable, Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest_asyncio
from dotenv import dotenv_values
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from zalpro_api.core.config import Settings
from zalpro_api.core.security import create_access_token, hash_password
from zalpro_api.main import create_app
from zalpro_api.models import (
    Exercise,
    Food,
    Gym,
    Membership,
    Message,
    Order,
    Photo,
    Plan,
    Product,
    Subscription,
    Trainer,
    User,
)

TEST_PASSWORD = "password123"

UserFactory = Callable[..., Awaitable[User]]


@pytest_asyncio.fixture(scope="session")
async def settings() -> Settings:
    for key, value in dotenv_values(Path(__file__).parent.parent / ".env.test").items():
        if value is not None:
            os.environ.setdefault(key, value)
    return Settings()


@pytest_asyncio.fixture(scope="session")
async def app(settings: Settings) -> AsyncIterator[Any]:
    application = create_app(settings)
    async with application.router.lifespan_context(application):
        yield application


@pytest_asyncio.fixture(scope="session")
async def password_hash() -> str:
    return await hash_password(TEST_PASSWORD)


@pytest_asyncio.fixture(autouse=True)
async def clean_database(app: Any) -> None:
    app.state.login_throttle.reset()
    async with app.state.engine.begin() as connection:
        await connection.execute(
            text(
                "TRUNCATE push_tokens, messages, photos, orders, products, reminders, attendance, "
                "memberships, "
                "subscriptions, "
                "weights, days, exercises, plans, foods, refresh_tokens, trainers, users, gyms "
                "RESTART IDENTITY CASCADE"
            )
        )


@pytest_asyncio.fixture
async def client(app: Any) -> AsyncIterator[AsyncClient]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
        yield http


@pytest_asyncio.fixture
async def db_session(app: Any) -> AsyncIterator[AsyncSession]:
    sessionmaker: async_sessionmaker[AsyncSession] = app.state.sessionmaker
    async with sessionmaker() as session:
        yield session


@pytest_asyncio.fixture
async def make_user(db_session: AsyncSession, password_hash: str) -> UserFactory:
    counter = itertools.count(1)

    async def factory(role: str = "user", **fields: Any) -> User:
        number = next(counter)
        values = {
            "id": uuid.uuid4().hex,
            "name": f"{role} {number}",
            "phone": f"99890{number:07d}",
            "password_hash": password_hash,
            "role": role,
        }
        user = User(**{**values, **fields})
        db_session.add(user)
        await db_session.commit()
        return user

    return factory


@pytest_asyncio.fixture
async def make_trainer(db_session: AsyncSession) -> Callable[..., Awaitable[Trainer]]:
    async def factory(user: User, **fields: Any) -> Trainer:
        values = {"id": user.id, "name": user.name, "gym_id": user.gym_id}
        trainer = Trainer(**{**values, **fields})
        db_session.add(trainer)
        await db_session.commit()
        return trainer

    return factory


@pytest_asyncio.fixture
async def make_gym(db_session: AsyncSession) -> Callable[..., Awaitable[Gym]]:
    async def factory(**fields: Any) -> Gym:
        gym = Gym(**{"id": uuid.uuid4().hex, "name": "Gym", **fields})
        db_session.add(gym)
        await db_session.commit()
        return gym

    return factory


@pytest_asyncio.fixture
async def make_food(db_session: AsyncSession) -> Callable[..., Awaitable[Food]]:
    async def factory(**fields: Any) -> Food:
        values = {"id": uuid.uuid4().hex, "name": "Food", "kcal": 100.0}
        food = Food(**{**values, **fields})
        db_session.add(food)
        await db_session.commit()
        return food

    return factory


@pytest_asyncio.fixture
async def make_plan(db_session: AsyncSession) -> Callable[..., Awaitable[Plan]]:
    async def factory(**fields: Any) -> Plan:
        plan = Plan(**{**{"id": uuid.uuid4().hex, "title": "Plan"}, **fields})
        db_session.add(plan)
        await db_session.commit()
        return plan

    return factory


@pytest_asyncio.fixture
async def make_subscription(db_session: AsyncSession) -> Callable[..., Awaitable[Subscription]]:
    async def factory(user_id: str, **fields: Any) -> Subscription:
        values = {
            "user_id": user_id,
            "start_date": datetime(2026, 10, 1, tzinfo=UTC),
            "months": 1,
            "price": 500000,
        }
        subscription = Subscription(**{**values, **fields})
        db_session.add(subscription)
        await db_session.commit()
        return subscription

    return factory


@pytest_asyncio.fixture
async def make_membership(db_session: AsyncSession) -> Callable[..., Awaitable[Membership]]:
    async def factory(user_id: str, **fields: Any) -> Membership:
        values = {
            "user_id": user_id,
            "name": "Client",
            "months": 1,
            "price": 500000,
            "paid_date": datetime(2026, 10, 1, tzinfo=UTC),
            "expires_at": datetime(2026, 11, 1, tzinfo=UTC),
        }
        membership = Membership(**{**values, **fields})
        db_session.add(membership)
        await db_session.commit()
        return membership

    return factory


@pytest_asyncio.fixture
async def make_exercise(db_session: AsyncSession) -> Callable[..., Awaitable[Exercise]]:
    async def factory(**fields: Any) -> Exercise:
        values = {
            "id": uuid.uuid4().hex,
            "name": "Exercise",
            "muscle": "chest",
            "created_by": "creator",
        }
        exercise = Exercise(**{**values, **fields})
        db_session.add(exercise)
        await db_session.commit()
        return exercise

    return factory


@pytest_asyncio.fixture
async def auth_headers(settings: Settings) -> Callable[[User], dict[str, str]]:
    def build(user: User) -> dict[str, str]:
        return {"Authorization": f"Bearer {create_access_token(user.id, settings)}"}

    return build


@pytest_asyncio.fixture
async def make_product(db_session: AsyncSession) -> Callable[..., Awaitable[Product]]:
    async def factory(**fields: Any) -> Product:
        values = {
            "id": uuid.uuid4().hex,
            "category": "Forma",
            "name": "Product",
            "price": 100000,
            "stock": 10,
            "cost_price": 60000,
        }
        product = Product(**{**values, **fields})
        db_session.add(product)
        await db_session.commit()
        return product

    return factory


@pytest_asyncio.fixture
async def make_order(db_session: AsyncSession) -> Callable[..., Awaitable[Order]]:
    async def factory(client_id: str, **fields: Any) -> Order:
        values = {
            "id": uuid.uuid4().hex,
            "client_id": client_id,
            "product_id": "product",
            "product_name": "Product",
            "category": "Forma",
            "price": 100000,
            "qty": 1,
        }
        order = Order(**{**values, **fields})
        db_session.add(order)
        await db_session.commit()
        return order

    return factory


class FakeStorage:
    def __init__(self) -> None:
        self.deleted: list[str] = []
        self.put_calls: list[tuple[str, int]] = []
        self.objects: dict[str, int] = {}

    async def presign_put(self, key: str, size: int, expires: int) -> str:
        self.put_calls.append((key, size))
        return f"https://storage.test/put/{key}?size={size}"

    async def presign_get(self, key: str, expires: int, content_type: str | None = None) -> str:
        suffix = f"?type={content_type}" if content_type else ""
        return f"https://storage.test/get/{key}{suffix}"

    async def head(self, key: str) -> int | None:
        return self.objects.get(key)

    async def delete(self, key: str) -> None:
        self.deleted.append(key)


@pytest_asyncio.fixture
async def storage(app: Any) -> AsyncIterator[FakeStorage]:
    fake = FakeStorage()
    original = app.state.storage
    app.state.storage = fake
    yield fake
    app.state.storage = original


@pytest_asyncio.fixture
async def make_message(db_session: AsyncSession) -> Callable[..., Awaitable[Message]]:
    async def factory(chat_uid: str, **fields: Any) -> Message:
        values = {
            "id": uuid.uuid4(),
            "chat_uid": chat_uid,
            "sender_id": chat_uid,
            "kind": "user",
            "text": "salom",
        }
        message = Message(**{**values, **fields})
        db_session.add(message)
        await db_session.commit()
        await db_session.refresh(message)
        return message

    return factory


@pytest_asyncio.fixture
async def make_photo(db_session: AsyncSession) -> Callable[..., Awaitable[Photo]]:
    async def factory(user_id: str, **fields: Any) -> Photo:
        photo_id = uuid.uuid4()
        values = {
            "id": photo_id,
            "user_id": user_id,
            "key": f"images/{user_id}/{photo_id.hex}",
            "taken_at": datetime.now(UTC),
            "weight": 80.0,
            "size": 1000,
        }
        photo = Photo(**{**values, **fields})
        db_session.add(photo)
        await db_session.commit()
        return photo

    return factory
