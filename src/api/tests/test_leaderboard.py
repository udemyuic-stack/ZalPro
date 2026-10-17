import datetime
from collections.abc import Awaitable, Callable
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Attendance, Day, Gym, User
from zalpro_api.services.leaderboard import PERIOD_DAYS, score

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
GymFactory = Callable[..., Awaitable[Gym]]

URL = "/v1/leaderboard"
ZONE = ZoneInfo("Asia/Tashkent")
MONDAY = datetime.date(2026, 3, 2)


def today() -> datetime.date:
    return datetime.datetime.now(ZONE).date()


def ago(days: int) -> datetime.date:
    return today() - datetime.timedelta(days=days)


@pytest.fixture
async def mark(db_session: AsyncSession) -> Callable[..., Awaitable[None]]:
    async def present(user: User, day: datetime.date) -> None:
        db_session.add(Attendance(user_id=user.id, day=day, present=True, marked_by=user.id))
        await db_session.commit()

    return present


@pytest.fixture
async def train(db_session: AsyncSession) -> Callable[..., Awaitable[None]]:
    async def workout(user: User, day: datetime.date, exercises: int = 3) -> None:
        db_session.add(
            Day(
                user_id=user.id,
                day=day,
                gym_started=True,
                gym_done=[f"e{i}" for i in range(exercises)],
            )
        )
        await db_session.commit()

    return workout


def test_score_present_only() -> None:
    assert score({MONDAY}, set()) == (10, 1)


def test_score_workout_only() -> None:
    assert score(set(), {MONDAY}) == (5, 1)


def test_score_both_on_one_day() -> None:
    assert score({MONDAY}, {MONDAY}) == (15, 1)


def test_score_week_bonus_at_three_active_days() -> None:
    days = {MONDAY + datetime.timedelta(days=i) for i in range(3)}
    assert score(days, set()) == (30 + 15, 3)


def test_score_no_bonus_under_three_active_days() -> None:
    days = {MONDAY, MONDAY + datetime.timedelta(days=1)}
    assert score(days, set()) == (20, 2)


def test_score_bonus_per_iso_week() -> None:
    first = {MONDAY + datetime.timedelta(days=i) for i in range(3)}
    second = {MONDAY + datetime.timedelta(days=7 + i) for i in range(3)}
    assert score(first | second, set()) == (60 + 30, 6)


def test_score_week_split_across_weeks_gets_no_bonus() -> None:
    sunday = MONDAY + datetime.timedelta(days=6)
    days = {sunday - datetime.timedelta(days=1), sunday, sunday + datetime.timedelta(days=1)}
    assert score(days, set()) == (30 + 0, 3)


async def test_requires_login(client: AsyncClient) -> None:
    assert (await client.get(URL)).status_code == 401


async def test_empty(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    me = await make_user()
    body = (await client.get(URL, headers=auth_headers(me))).json()
    assert body == {"period_days": PERIOD_DAYS, "top": [], "me": None}


async def test_points_and_me(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
    train: Callable[..., Awaitable[None]],
) -> None:
    me = await make_user(name="Ali")
    await mark(me, ago(0))
    await train(me, ago(0))
    await train(me, ago(1), exercises=2)
    body = (await client.get(URL, headers=auth_headers(me))).json()
    assert body["top"] == [
        {"rank": 1, "user_id": me.id, "name": "Ali", "points": 15, "active_days": 1}
    ]
    assert body["me"] == {"rank": 1, "points": 15, "active_days": 1}


async def test_window_boundary(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    inside = await make_user(name="Inside")
    outside = await make_user(name="Outside")
    await mark(inside, ago(PERIOD_DAYS - 1))
    await mark(outside, ago(PERIOD_DAYS))
    body = (await client.get(URL, headers=auth_headers(inside))).json()
    assert [row["name"] for row in body["top"]] == ["Inside"]


async def test_future_days_ignored(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    me = await make_user()
    await mark(me, ago(-1))
    assert (await client.get(URL, headers=auth_headers(me))).json()["top"] == []


async def test_not_present_does_not_count(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    me = await make_user()
    db_session.add(Attendance(user_id=me.id, day=ago(0), present=False, marked_by=me.id))
    await db_session.commit()
    assert (await client.get(URL, headers=auth_headers(me))).json()["top"] == []


async def test_workout_needs_started_flag(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    me = await make_user()
    db_session.add(Day(user_id=me.id, day=ago(0), gym_started=False, gym_done=["a", "b", "c"]))
    await db_session.commit()
    assert (await client.get(URL, headers=auth_headers(me))).json()["top"] == []


async def test_top_limited_to_ten_and_ordered(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    users = []
    for index in range(12):
        user = await make_user(name=f"U{index:02d}")
        for offset in range(index + 1 if index < 2 else 1):
            await mark(user, ago(offset))
        users.append(user)
    last = users[0]
    body = (await client.get(URL, headers=auth_headers(last))).json()
    assert len(body["top"]) == 10
    assert [row["rank"] for row in body["top"]] == list(range(1, 11))
    points = [row["points"] for row in body["top"]]
    assert points == sorted(points, reverse=True)
    assert body["top"][0]["name"] == "U01"


async def test_ties_break_by_active_days_then_name(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
    train: Callable[..., Awaitable[None]],
) -> None:
    b = await make_user(name="Bobur")
    a = await make_user(name="Aziz")
    c = await make_user(name="Carlos")
    await mark(a, ago(0))
    await mark(b, ago(0))
    await train(c, ago(0))
    await train(c, ago(1))
    body = (await client.get(URL, headers=auth_headers(a))).json()
    assert [row["name"] for row in body["top"]] == ["Carlos", "Aziz", "Bobur"]
    assert [row["points"] for row in body["top"]] == [10, 10, 10]


async def test_more_active_days_wins_tie(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
    train: Callable[..., Awaitable[None]],
) -> None:
    two = await make_user(name="Zed")
    one = await make_user(name="Abe")
    await train(two, ago(0))
    await train(two, ago(1))
    await mark(one, ago(0))
    body = (await client.get(URL, headers=auth_headers(one))).json()
    assert [row["name"] for row in body["top"]] == ["Zed", "Abe"]
    assert body["top"][0]["points"] == body["top"][1]["points"] == 10


async def test_me_outside_top_ten_has_real_rank(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    for index in range(10):
        leader = await make_user(name=f"L{index}")
        await mark(leader, ago(0))
        await mark(leader, ago(1))
    me = await make_user(name="Me")
    await mark(me, ago(0))
    body = (await client.get(URL, headers=auth_headers(me))).json()
    assert len(body["top"]) == 10
    assert all(row["user_id"] != me.id for row in body["top"])
    assert body["me"] == {"rank": 11, "points": 10, "active_days": 1}


async def test_other_gym_and_roles_excluded(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    mine = await make_gym()
    theirs = await make_gym()
    me = await make_user(name="Me", gym_id=mine.id)
    mate = await make_user(name="Mate", gym_id=mine.id)
    stranger = await make_user(name="Stranger", gym_id=theirs.id)
    trainer = await make_user(role="admin", name="Coach", gym_id=mine.id)
    for user in (me, mate, stranger, trainer):
        await mark(user, ago(0))
    body = (await client.get(URL, headers=auth_headers(me))).json()
    assert sorted(row["name"] for row in body["top"]) == ["Mate", "Me"]


async def test_trainer_and_trainerless_share_one_list(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    coach = await make_user(role="admin")
    with_trainer = await make_user(name="With", trainer_id=coach.id)
    alone = await make_user(name="Alone")
    await mark(with_trainer, ago(0))
    await mark(alone, ago(0))
    for viewer in (with_trainer, alone):
        body = (await client.get(URL, headers=auth_headers(viewer))).json()
        assert sorted(row["name"] for row in body["top"]) == ["Alone", "With"]
        assert body["me"]["points"] == 10


async def test_staff_can_view_but_has_no_rank(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    owner = await make_user(role="owner")
    student = await make_user(name="S")
    await mark(student, ago(0))
    await mark(owner, ago(0))
    body = (await client.get(URL, headers=auth_headers(owner))).json()
    assert [row["name"] for row in body["top"]] == ["S"]
    assert body["me"] is None


async def test_opted_out_hidden(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    hidden = await make_user(name="Hidden", show_in_leaderboard=False)
    shown = await make_user(name="Shown")
    await mark(hidden, ago(0))
    await mark(shown, ago(0))
    body = (await client.get(URL, headers=auth_headers(hidden))).json()
    assert [row["name"] for row in body["top"]] == ["Shown"]
    assert body["me"] is None


async def test_response_exposes_only_public_fields(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    me = await make_user(name="Me", weight=80.0)
    await mark(me, ago(0))
    body = (await client.get(URL, headers=auth_headers(me))).json()
    assert set(body) == {"period_days", "top", "me"}
    assert set(body["top"][0]) == {"rank", "user_id", "name", "points", "active_days"}
    assert set(body["me"]) == {"rank", "points", "active_days"}


async def test_set_visibility(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    mark: Callable[..., Awaitable[None]],
) -> None:
    me = await make_user()
    await mark(me, ago(0))
    headers = auth_headers(me)
    off = await client.put("/v1/users/me/leaderboard", json={"visible": False}, headers=headers)
    assert off.status_code == 200
    assert off.json()["show_in_leaderboard"] is False
    assert (await client.get(URL, headers=headers)).json()["top"] == []
    on = await client.put("/v1/users/me/leaderboard", json={"visible": True}, headers=headers)
    assert on.json()["show_in_leaderboard"] is True
    assert len((await client.get(URL, headers=headers)).json()["top"]) == 1


async def test_default_visible(make_user: UserFactory) -> None:
    assert (await make_user()).show_in_leaderboard is True


@pytest.mark.parametrize("value", ["yes", 1, 0, "true", None, "", []])
async def test_set_visibility_rejects_non_bool(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, value: object
) -> None:
    me = await make_user()
    response = await client.put(
        "/v1/users/me/leaderboard", json={"visible": value}, headers=auth_headers(me)
    )
    assert response.status_code == 422


async def test_set_visibility_rejects_extra_and_missing(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    me = await make_user()
    headers = auth_headers(me)
    assert (
        await client.put("/v1/users/me/leaderboard", json={}, headers=headers)
    ).status_code == 422
    extra = {"visible": True, "id": "x"}
    assert (
        await client.put("/v1/users/me/leaderboard", json=extra, headers=headers)
    ).status_code == 422


async def test_set_visibility_requires_login(client: AsyncClient) -> None:
    response = await client.put("/v1/users/me/leaderboard", json={"visible": True})
    assert response.status_code == 401
