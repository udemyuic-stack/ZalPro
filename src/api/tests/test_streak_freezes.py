from collections.abc import Awaitable, Callable
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient

from zalpro_api.models import User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

GYM_TODAY = datetime.now(ZoneInfo("Asia/Tashkent")).date()
LAST_MONDAY = GYM_TODAY - timedelta(days=GYM_TODAY.weekday() + 7)


def url(user: User) -> str:
    return f"/v1/users/{user.id}/streak-freezes"


def mondays_in_one_month(count: int) -> list[date]:
    by_month: dict[tuple[int, int], list[date]] = {}
    for weeks_back in range(40):
        monday = LAST_MONDAY - timedelta(days=7 * weeks_back)
        by_month.setdefault((monday.year, monday.month), []).append(monday)
    return next(group for group in by_month.values() if len(group) >= count)[:count]


@pytest.fixture
async def staff(make_user: UserFactory) -> User:
    return await make_user(role="admin")


@pytest.fixture
async def student(make_user: UserFactory) -> User:
    return await make_user()


@pytest.fixture
async def stranger(make_user: UserFactory) -> User:
    return await make_user()


async def test_staff_grants_past_week(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        url(student),
        headers=auth_headers(staff),
        json={"week_start": LAST_MONDAY.isoformat()},
    )
    assert response.status_code == 200
    assert response.json() == {"week_start": LAST_MONDAY.isoformat(), "granted_by": staff.id}


async def test_student_cannot_grant_own_freeze(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        url(student),
        headers=auth_headers(student),
        json={"week_start": LAST_MONDAY.isoformat()},
    )
    assert response.status_code == 403


async def test_stranger_cannot_grant(
    client: AsyncClient, student: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        url(student),
        headers=auth_headers(stranger),
        json={"week_start": LAST_MONDAY.isoformat()},
    )
    assert response.status_code == 403


async def test_current_week_cannot_be_frozen(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    current_monday = GYM_TODAY - timedelta(days=GYM_TODAY.weekday())
    response = await client.post(
        url(student),
        headers=auth_headers(staff),
        json={"week_start": current_monday.isoformat()},
    )
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "freeze_not_allowed"


async def test_non_monday_rejected(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.post(
        url(student),
        headers=auth_headers(staff),
        json={"week_start": (LAST_MONDAY + timedelta(days=1)).isoformat()},
    )
    assert response.status_code == 422


async def test_duplicate_week_rejected(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    body = {"week_start": LAST_MONDAY.isoformat()}
    await client.post(url(student), headers=auth_headers(staff), json=body)
    response = await client.post(url(student), headers=auth_headers(staff), json=body)
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "freeze_exists"


async def test_monthly_limit_enforced(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    first, second, third = mondays_in_one_month(3)
    for week in (first, second):
        response = await client.post(
            url(student), headers=auth_headers(staff), json={"week_start": week.isoformat()}
        )
        assert response.status_code == 200
    response = await client.post(
        url(student), headers=auth_headers(staff), json={"week_start": third.isoformat()}
    )
    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "freeze_limit_reached"


async def test_student_reads_own_freezes(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    await client.post(
        url(student),
        headers=auth_headers(staff),
        json={"week_start": LAST_MONDAY.isoformat()},
    )
    window = {"from": (LAST_MONDAY - timedelta(days=7)).isoformat(), "to": GYM_TODAY.isoformat()}
    response = await client.get(url(student), headers=auth_headers(student), params=window)
    assert response.status_code == 200
    assert [row["week_start"] for row in response.json()] == [LAST_MONDAY.isoformat()]


async def test_stranger_cannot_read_freezes(
    client: AsyncClient, student: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    window = {"from": LAST_MONDAY.isoformat(), "to": GYM_TODAY.isoformat()}
    response = await client.get(url(student), headers=auth_headers(stranger), params=window)
    assert response.status_code == 403


async def test_revoke_then_not_found(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    await client.post(
        url(student),
        headers=auth_headers(staff),
        json={"week_start": LAST_MONDAY.isoformat()},
    )
    path = f"{url(student)}/{LAST_MONDAY.isoformat()}"
    response = await client.delete(path, headers=auth_headers(staff))
    assert response.status_code == 204
    response = await client.delete(path, headers=auth_headers(staff))
    assert response.status_code == 404


async def test_student_cannot_revoke(
    client: AsyncClient, staff: User, student: User, auth_headers: HeadersFactory
) -> None:
    await client.post(
        url(student),
        headers=auth_headers(staff),
        json={"week_start": LAST_MONDAY.isoformat()},
    )
    path = f"{url(student)}/{LAST_MONDAY.isoformat()}"
    response = await client.delete(path, headers=auth_headers(student))
    assert response.status_code == 403
