from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Message, Reminder, User
from zalpro_api.services import auto_reminders, system_messages

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

NOW = datetime(2026, 10, 19, 9, 0, tzinfo=UTC)
LOCAL_MIDDAY = datetime(2026, 10, 19, 7, 0, tzinfo=UTC)


def expiry_for(days_left: int) -> datetime:
    return datetime(2026, 10, 19, 12, 0, tzinfo=UTC) + timedelta(days=days_left)


async def list_auto(session: AsyncSession) -> list[Reminder]:
    return list((await session.scalars(select(Reminder).order_by(Reminder.sent_at))).all())


async def list_chat(session: AsyncSession, chat_uid: str) -> list[Message]:
    statement = select(Message).where(Message.chat_uid == chat_uid)
    return list((await session.scalars(statement)).all())


@pytest.fixture
async def owner(make_user: UserFactory) -> User:
    return await make_user(role="owner")


@pytest.fixture
async def trainer(make_user: UserFactory) -> User:
    return await make_user(role="admin")


@pytest.mark.parametrize("days_left", [3, 0, -3])
async def test_run_once_sends_one_message_and_one_reminder_on_stage_days(
    db_session: AsyncSession, make_user: UserFactory, trainer: User, days_left: int
) -> None:
    student = await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(days_left))

    student_id = student.id

    sent = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    reminders = await list_auto(db_session)
    chat = await list_chat(db_session, student_id)
    assert sent == 1
    assert len(reminders) == 1
    assert reminders[0].auto is True
    assert reminders[0].days_left == days_left
    assert reminders[0].client_id == student_id
    assert len(chat) == 1
    assert chat[0].kind == "system"
    assert chat[0].text == system_messages.reminder_text(days_left)


@pytest.mark.parametrize("days_left", [4, 1, -2, -5])
async def test_run_once_ignores_non_stage_days(
    db_session: AsyncSession, make_user: UserFactory, trainer: User, days_left: int
) -> None:
    await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(days_left))

    sent = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    assert sent == 0
    assert await list_auto(db_session) == []


@pytest.mark.parametrize(("days_left", "stage"), [(2, 3), (-1, 0), (-4, -3)])
async def test_run_once_catches_up_one_day_after_missed_stage(
    db_session: AsyncSession, make_user: UserFactory, trainer: User, days_left: int, stage: int
) -> None:
    await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(days_left))

    sent = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    reminders = await list_auto(db_session)
    assert sent == 1
    assert reminders[0].auto_stage == stage
    assert reminders[0].days_left == days_left


async def test_run_once_does_not_resend_stage_already_sent(
    db_session: AsyncSession, make_user: UserFactory, trainer: User
) -> None:
    student = await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(3))
    student_id = student.id
    await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    next_day = await auto_reminders.run_once(db_session, LOCAL_MIDDAY + timedelta(days=1))

    assert next_day == 0
    assert len(await list_auto(db_session)) == 1
    assert len(await list_chat(db_session, student_id)) == 1


async def test_run_once_second_call_adds_nothing(
    db_session: AsyncSession, make_user: UserFactory, trainer: User
) -> None:
    student = await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(0))
    student_id = student.id

    first = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)
    second = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    assert (first, second) == (1, 0)
    assert len(await list_auto(db_session)) == 1
    assert len(await list_chat(db_session, student_id)) == 1


async def test_run_once_sends_stages_again_after_renewal(
    db_session: AsyncSession, make_user: UserFactory, trainer: User
) -> None:
    student = await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(3))
    await auto_reminders.run_once(db_session, LOCAL_MIDDAY)
    student.subscription_expires_at = expiry_for(33)
    await db_session.commit()

    later = LOCAL_MIDDAY + timedelta(days=30)
    sent = await auto_reminders.run_once(db_session, later)

    assert sent == 1
    assert len(await list_auto(db_session)) == 2


async def test_run_once_skips_users_without_subscription_and_non_user_roles(
    db_session: AsyncSession, make_user: UserFactory, trainer: User
) -> None:
    await make_user(trainer_id=trainer.id, subscription_expires_at=None)
    await make_user(role="admin", subscription_expires_at=expiry_for(3))
    await make_user(role="barmen", subscription_expires_at=expiry_for(0))

    sent = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    assert sent == 0
    assert await list_auto(db_session) == []


async def test_run_once_uses_tashkent_day_boundary(
    db_session: AsyncSession, make_user: UserFactory, trainer: User
) -> None:
    expires = datetime(2026, 10, 22, 19, 30, tzinfo=UTC)
    await make_user(trainer_id=trainer.id, subscription_expires_at=expires)
    before_midnight = datetime(2026, 10, 19, 18, 59, tzinfo=UTC)

    assert await auto_reminders.run_once(db_session, before_midnight) == 0
    local_next_day = datetime(2026, 10, 19, 19, 30, tzinfo=UTC)
    assert await auto_reminders.run_once(db_session, local_next_day) == 1
    reminders = await list_auto(db_session)
    assert reminders[0].days_left == 3


async def test_run_once_with_trainer_uses_trainer_as_sender(
    db_session: AsyncSession, make_user: UserFactory, trainer: User, owner: User
) -> None:
    student = await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(3))
    student_id, trainer_id = student.id, trainer.id

    await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    reminder = (await list_auto(db_session))[0]
    chat = await list_chat(db_session, student_id)
    assert reminder.trainer_id == trainer_id
    assert reminder.sent_by == trainer_id
    assert chat[0].sender_id == trainer_id


async def test_run_once_without_trainer_uses_owner_as_sender(
    db_session: AsyncSession, make_user: UserFactory, owner: User
) -> None:
    student = await make_user(subscription_expires_at=expiry_for(3))
    student_id, owner_id = student.id, owner.id

    await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    reminder = (await list_auto(db_session))[0]
    chat = await list_chat(db_session, student_id)
    assert reminder.trainer_id == ""
    assert reminder.sent_by == owner_id
    assert chat[0].sender_id == owner_id


async def test_run_once_without_trainer_and_owner_sends_nothing(
    db_session: AsyncSession, make_user: UserFactory
) -> None:
    await make_user(subscription_expires_at=expiry_for(3))

    sent = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    assert sent == 0
    assert await list_auto(db_session) == []


async def test_run_once_failure_for_one_student_does_not_stop_others(
    db_session: AsyncSession,
    make_user: UserFactory,
    trainer: User,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    broken = await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(3))
    healthy = await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(0))
    broken_id, healthy_id = broken.id, healthy.id
    original = auto_reminders.stage_message

    async def flaky(session: AsyncSession, chat_uid: str, *args: Any) -> Message:
        if chat_uid == broken_id:
            raise RuntimeError("boom")
        return await original(session, chat_uid, *args)

    monkeypatch.setattr(auto_reminders, "stage_message", flaky)

    sent = await auto_reminders.run_once(db_session, LOCAL_MIDDAY)

    reminders = await list_auto(db_session)
    assert sent == 1
    assert [reminder.client_id for reminder in reminders] == [healthy_id]


async def test_manual_reminders_stay_not_auto_in_api(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    trainer: User,
) -> None:
    student = await make_user(trainer_id=trainer.id)

    response = await client.post(
        "/v1/reminders",
        json={"client_id": student.id, "days_left": 3},
        headers=auth_headers(trainer),
    )

    assert response.status_code == 201
    assert response.json()["auto"] is False


async def test_auto_reminder_is_listed_with_auto_flag(
    client: AsyncClient,
    db_session: AsyncSession,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    owner: User,
    trainer: User,
) -> None:
    await make_user(trainer_id=trainer.id, subscription_expires_at=expiry_for(3))
    await auto_reminders.run_once(db_session, LOCAL_MIDDAY)
    today = datetime.now(UTC).date()
    window = {
        "from": (today - timedelta(days=1)).isoformat(),
        "to": (today + timedelta(days=1)).isoformat(),
    }

    response = await client.get("/v1/reminders", params=window, headers=auth_headers(owner))

    assert response.status_code == 200
    assert [item["auto"] for item in response.json()] == [True]


async def test_worker_runs_after_nine_local_once_per_day(app: Any) -> None:
    worker = auto_reminders.AutoReminderWorker(app.state)
    before_nine = datetime(2026, 10, 19, 3, 59, tzinfo=UTC)
    at_nine = datetime(2026, 10, 19, 4, 0, tzinfo=UTC)

    assert worker.is_due(before_nine) is False
    assert worker.is_due(at_nine) is True
    await worker.tick(at_nine)
    assert worker.is_due(at_nine + timedelta(hours=3)) is False
    assert worker.is_due(at_nine + timedelta(days=1)) is True
