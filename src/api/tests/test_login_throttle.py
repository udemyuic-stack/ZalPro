from typing import Any

import pytest
from httpx import AsyncClient

from tests.conftest import TEST_PASSWORD, UserFactory
from zalpro_api.services.login_throttle import LoginThrottle

WINDOW = 60
LIMIT = 3


class FakeClock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def clock(app: Any, monkeypatch: pytest.MonkeyPatch) -> FakeClock:
    fake = FakeClock()
    monkeypatch.setattr(app.state, "login_throttle", LoginThrottle(LIMIT, WINDOW, clock=fake))
    return fake


async def attempt(client: AsyncClient, phone: str, password: str) -> Any:
    return await client.post("/v1/auth/login", json={"phone": phone, "password": password})


async def fail_times(client: AsyncClient, phone: str, count: int) -> None:
    for _ in range(count):
        assert (await attempt(client, phone, "wrong-password")).status_code == 401


async def test_blocks_after_limit_even_with_correct_password(
    client: AsyncClient, make_user: UserFactory, clock: FakeClock
) -> None:
    user = await make_user()
    await fail_times(client, user.phone, LIMIT)
    response = await attempt(client, user.phone, TEST_PASSWORD)
    assert response.status_code == 429
    assert response.json()["detail"]["code"] == "too_many_attempts"


async def test_retry_after_header_counts_down(
    client: AsyncClient, make_user: UserFactory, clock: FakeClock
) -> None:
    user = await make_user()
    await fail_times(client, user.phone, LIMIT)
    clock.now += 20
    response = await attempt(client, user.phone, TEST_PASSWORD)
    assert response.status_code == 429
    assert response.headers["Retry-After"] == str(WINDOW - 20)


async def test_other_phone_is_not_affected(
    client: AsyncClient, make_user: UserFactory, clock: FakeClock
) -> None:
    blocked = await make_user()
    other = await make_user()
    await fail_times(client, blocked.phone, LIMIT)
    assert (await attempt(client, other.phone, TEST_PASSWORD)).status_code == 200


async def test_window_expiry_allows_login_again(
    client: AsyncClient, make_user: UserFactory, clock: FakeClock
) -> None:
    user = await make_user()
    await fail_times(client, user.phone, LIMIT)
    clock.now += WINDOW + 1
    assert (await attempt(client, user.phone, TEST_PASSWORD)).status_code == 200


async def test_success_clears_counter(
    client: AsyncClient, make_user: UserFactory, clock: FakeClock
) -> None:
    user = await make_user()
    await fail_times(client, user.phone, LIMIT - 1)
    assert (await attempt(client, user.phone, TEST_PASSWORD)).status_code == 200
    await fail_times(client, user.phone, LIMIT - 1)
    assert (await attempt(client, user.phone, TEST_PASSWORD)).status_code == 200


async def test_unknown_phone_is_throttled_too(client: AsyncClient, clock: FakeClock) -> None:
    await fail_times(client, "998900000000", LIMIT)
    response = await attempt(client, "998900000000", "whatever123")
    assert response.status_code == 429


async def test_failures_outside_window_do_not_accumulate(
    client: AsyncClient, make_user: UserFactory, clock: FakeClock
) -> None:
    user = await make_user()
    for _ in range(LIMIT):
        await fail_times(client, user.phone, 1)
        clock.now += WINDOW
    assert (await attempt(client, user.phone, TEST_PASSWORD)).status_code == 200


def test_throttle_reset_clears_everything() -> None:
    throttle = LoginThrottle(1, WINDOW)
    throttle.record_failure("a")
    throttle.reset()
    throttle.ensure_allowed("a")
