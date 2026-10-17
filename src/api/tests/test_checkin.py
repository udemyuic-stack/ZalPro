from collections.abc import Awaitable, Callable
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import jwt
import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.errors import ApiError
from zalpro_api.core.security import (
    CHECKIN_TOKEN_SECONDS,
    JWT_ALGORITHM,
    create_access_token,
    create_checkin_token,
    decode_access_claims,
    decode_checkin_token,
)
from zalpro_api.models import Attendance, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

TOKEN_URL = "/v1/users/me/checkin-token"
SCAN_URL = "/v1/attendance/scan"


def gym_today(settings: Settings) -> date:
    return datetime.now(ZoneInfo(settings.gym_timezone)).date()


def expiry_in_days(settings: Settings, days: int) -> datetime:
    day = gym_today(settings) + timedelta(days=days)
    return datetime.combine(day, time.min, tzinfo=ZoneInfo(settings.gym_timezone)).astimezone(UTC)


async def scan(client: AsyncClient, headers: dict[str, str], token: str) -> object:
    return await client.post(SCAN_URL, headers=headers, json={"token": token})


async def attendance_rows(session: AsyncSession, user: User) -> list[Attendance]:
    statement = (
        select(Attendance)
        .where(Attendance.user_id == user.id)
        .execution_options(populate_existing=True)
    )
    return list((await session.scalars(statement)).all())


@pytest.fixture
async def member(make_user: UserFactory, settings: Settings) -> User:
    return await make_user(subscription_expires_at=expiry_in_days(settings, 5))


async def test_checkin_token_endpoint_returns_token_and_expiry(
    client: AsyncClient, member: User, auth_headers: HeadersFactory, settings: Settings
) -> None:
    response = await client.get(TOKEN_URL, headers=auth_headers(member))

    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"token", "expires_in"}
    assert body["expires_in"] == CHECKIN_TOKEN_SECONDS == 60
    claims = jwt.decode(body["token"], settings.jwt_secret, algorithms=[JWT_ALGORITHM])
    assert claims["sub"] == member.id
    assert claims["typ"] == "checkin"
    assert claims["exp"] - claims["iat"] == 60


@pytest.mark.parametrize("role", ["user", "admin", "owner", "barmen"])
async def test_every_role_can_get_checkin_token(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, role: str
) -> None:
    user = await make_user(role=role)

    response = await client.get(TOKEN_URL, headers=auth_headers(user))

    assert response.status_code == 200


async def test_checkin_token_requires_authentication(client: AsyncClient) -> None:
    response = await client.get(TOKEN_URL)

    assert response.status_code == 401


async def test_checkin_token_is_rejected_as_bearer(
    client: AsyncClient, member: User, settings: Settings
) -> None:
    token = create_checkin_token(member.id, settings)

    response = await client.get("/v1/users/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


def test_decode_access_claims_rejects_checkin_token(settings: Settings) -> None:
    token = create_checkin_token("user-1", settings)

    with pytest.raises(ApiError) as caught:
        decode_access_claims(token, settings)

    assert caught.value.code == "invalid_token"


def test_decode_checkin_token_rejects_access_token(settings: Settings) -> None:
    token = create_access_token("user-1", settings)

    with pytest.raises(ApiError) as caught:
        decode_checkin_token(token, settings)

    assert caught.value.code == "invalid_token"


def test_decode_checkin_token_returns_subject(settings: Settings) -> None:
    assert decode_checkin_token(create_checkin_token("user-1", settings), settings) == "user-1"


async def test_scan_rejects_access_token_as_checkin_token(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    staff = await make_user(role="admin")
    token = create_access_token(member.id, settings)

    response = await scan(client, auth_headers(staff), token)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_scan_rejects_expired_token(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    staff = await make_user(role="admin")
    token = create_checkin_token(member.id, settings, lifetime=timedelta(seconds=-5))

    response = await scan(client, auth_headers(staff), token)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "token_expired"
    assert await attendance_rows(db_session, member) == []


async def test_scan_rejects_tampered_token(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    staff = await make_user(role="admin")
    token = create_checkin_token(member.id, settings)
    tampered = token[:-4] + ("AAAA" if not token.endswith("AAAA") else "BBBB")

    response = await scan(client, auth_headers(staff), tampered)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_scan_rejects_token_signed_with_other_secret(
    client: AsyncClient, make_user: UserFactory, member: User, auth_headers: HeadersFactory
) -> None:
    staff = await make_user(role="admin")
    now = datetime.now(UTC)
    claims = {"sub": member.id, "typ": "checkin", "iat": now, "exp": now + timedelta(seconds=60)}
    token = jwt.encode(claims, "x" * 64, algorithm=JWT_ALGORITHM)

    response = await scan(client, auth_headers(staff), token)

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


async def test_scan_rejects_garbage_token(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    staff = await make_user(role="admin")

    response = await scan(client, auth_headers(staff), "not-a-jwt")

    assert response.status_code == 401
    assert response.json()["detail"]["code"] == "invalid_token"


@pytest.mark.parametrize("body", [{}, {"token": ""}, {"token": "a", "extra": 1}])
async def test_scan_validates_body(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, body: dict
) -> None:
    staff = await make_user(role="admin")

    response = await client.post(SCAN_URL, headers=auth_headers(staff), json=body)

    assert response.status_code == 422


async def test_scan_requires_authentication(client: AsyncClient, settings: Settings) -> None:
    response = await client.post(SCAN_URL, json={"token": create_checkin_token("u", settings)})

    assert response.status_code == 401


async def test_user_role_cannot_scan(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    other = await make_user()

    response = await scan(client, auth_headers(other), create_checkin_token(member.id, settings))

    assert response.status_code == 403
    assert await attendance_rows(db_session, member) == []


@pytest.mark.parametrize("role", ["admin", "owner", "barmen"])
async def test_scanner_roles_mark_attendance_for_today(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
    role: str,
) -> None:
    scanner = await make_user(role=role)

    response = await scan(client, auth_headers(scanner), create_checkin_token(member.id, settings))

    assert response.status_code == 200
    rows = await attendance_rows(db_session, member)
    assert len(rows) == 1
    assert rows[0].day == gym_today(settings)
    assert rows[0].present is True
    assert rows[0].marked_by == scanner.id


async def test_scan_scans_any_member_regardless_of_trainer(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    trainer = await make_user(role="admin")
    stranger_scanner = await make_user(role="admin")
    student = await make_user(trainer_id=trainer.id)

    response = await scan(
        client, auth_headers(stranger_scanner), create_checkin_token(student.id, settings)
    )

    assert response.status_code == 200
    assert len(await attendance_rows(db_session, student)) == 1


async def test_scan_response_shape_for_active_subscription(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    staff = await make_user(role="owner")

    response = await scan(client, auth_headers(staff), create_checkin_token(member.id, settings))

    assert response.status_code == 200
    body = response.json()
    assert set(body) == {
        "user_id",
        "name",
        "day",
        "already_present",
        "subscription_expires_at",
        "days_left",
        "subscription",
    }
    assert body["user_id"] == member.id
    assert body["name"] == member.name
    assert body["day"] == gym_today(settings).isoformat()
    assert body["already_present"] is False
    assert body["subscription"] == "active"
    assert body["days_left"] == 5
    assert datetime.fromisoformat(body["subscription_expires_at"]) == expiry_in_days(settings, 5)


async def test_second_scan_is_idempotent_and_keeps_marked_at(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    first_scanner = await make_user(role="admin")
    second_scanner = await make_user(role="barmen")

    first = await scan(
        client, auth_headers(first_scanner), create_checkin_token(member.id, settings)
    )
    marked_at = (await attendance_rows(db_session, member))[0].marked_at
    second = await scan(
        client, auth_headers(second_scanner), create_checkin_token(member.id, settings)
    )

    assert first.json()["already_present"] is False
    assert second.status_code == 200
    assert second.json()["already_present"] is True
    rows = await attendance_rows(db_session, member)
    assert len(rows) == 1
    assert rows[0].marked_at == marked_at
    assert rows[0].marked_by == first_scanner.id


async def test_scan_marks_again_when_attendance_was_unmarked(
    client: AsyncClient,
    make_user: UserFactory,
    member: User,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    headers = auth_headers(owner)
    await scan(client, headers, create_checkin_token(member.id, settings))
    day = gym_today(settings).isoformat()
    unmark = await client.put(
        f"/v1/users/{member.id}/attendance/{day}", headers=headers, json={"present": False}
    )

    response = await scan(client, headers, create_checkin_token(member.id, settings))

    assert unmark.status_code == 200
    assert response.json()["already_present"] is False
    assert (await attendance_rows(db_session, member))[0].present is True


async def test_scan_expiring_today_reports_zero_days_left(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
) -> None:
    staff = await make_user(role="admin")
    user = await make_user(subscription_expires_at=expiry_in_days(settings, 0))

    response = await scan(client, auth_headers(staff), create_checkin_token(user.id, settings))

    body = response.json()
    assert body["subscription"] == "active"
    assert body["days_left"] == 0


async def test_scan_with_expired_subscription_still_marks_attendance(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    staff = await make_user(role="admin")
    user = await make_user(subscription_expires_at=expiry_in_days(settings, -1))

    response = await scan(client, auth_headers(staff), create_checkin_token(user.id, settings))

    assert response.status_code == 200
    body = response.json()
    assert body["subscription"] == "expired"
    assert body["days_left"] is None
    assert body["subscription_expires_at"] is not None
    assert body["already_present"] is False
    assert len(await attendance_rows(db_session, user)) == 1


async def test_scan_without_subscription_marks_attendance(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    staff = await make_user(role="admin")
    user = await make_user()

    response = await scan(client, auth_headers(staff), create_checkin_token(user.id, settings))

    assert response.status_code == 200
    body = response.json()
    assert body["subscription"] == "none"
    assert body["days_left"] is None
    assert body["subscription_expires_at"] is None
    assert len(await attendance_rows(db_session, user)) == 1


async def test_scan_unknown_user_returns_404(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
) -> None:
    staff = await make_user(role="admin")

    response = await scan(client, auth_headers(staff), create_checkin_token("missing", settings))

    assert response.status_code == 404
    count = await db_session.scalar(select(func.count()).select_from(Attendance))
    assert count == 0


@pytest.mark.parametrize("role", ["admin", "owner", "barmen"])
async def test_scan_token_of_non_member_returns_422(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    settings: Settings,
    db_session: AsyncSession,
    role: str,
) -> None:
    staff = await make_user(role="admin")
    subject = await make_user(role=role)

    response = await scan(client, auth_headers(staff), create_checkin_token(subject.id, settings))

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "checkin_not_member"
    assert await attendance_rows(db_session, subject) == []
