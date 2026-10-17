from collections.abc import Awaitable, Callable
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Attendance, Day, Trainer, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

ZONE = ZoneInfo("Asia/Tashkent")


def today() -> date:
    return datetime.now(ZONE).date()


def ago(days: int) -> date:
    return today() - timedelta(days=days)


def at(day: date, hour: int = 12) -> datetime:
    return datetime.combine(day, time(hour), tzinfo=ZONE).astimezone(UTC)


async def visit(session: AsyncSession, user: User, *days_ago: int) -> None:
    session.add_all(
        Attendance(user_id=user.id, day=ago(offset), present=True, marked_by=user.id)
        for offset in days_ago
    )
    await session.commit()


async def churn(client: AsyncClient, actor: User, headers: HeadersFactory) -> list[dict]:
    response = await client.get("/v1/analytics/churn", headers=headers(actor))
    assert response.status_code == 200, response.text
    return response.json()["items"]


def window(start: date, end: date) -> dict[str, str]:
    return {"from": start.isoformat(), "to": end.isoformat()}


async def test_silent_student_is_listed_with_score_three(
    client: AsyncClient,
    make_user: UserFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user(created_at=at(ago(90)))
    await visit(db_session, student, 20, 22)

    items = await churn(client, owner, auth_headers)

    assert [(i["user_id"], i["reasons"], i["score"]) for i in items] == [
        (student.id, ["silent"], 3)
    ]
    assert items[0]["last_visit"] == ago(20).isoformat()
    assert items[0]["visits_last14"] == 0
    assert items[0]["visits_prev14"] == 2


@pytest.mark.parametrize(
    ("last", "prev", "reasons"),
    [(3, 6, ["drop"]), (4, 6, []), (0, 3, ["silent"]), (0, 0, [])],
)
async def test_drop_rule_boundaries(
    client: AsyncClient,
    make_user: UserFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
    last: int,
    prev: int,
    reasons: list[str],
) -> None:
    owner = await make_user("owner")
    student = await make_user(created_at=at(ago(90)))
    await visit(db_session, student, *range(last), *range(14, 14 + prev))

    items = await churn(client, owner, auth_headers)

    assert [i["reasons"] for i in items] == ([reasons] if reasons else [])


@pytest.mark.parametrize(
    ("offset", "reason"),
    [(7, "expiring"), (8, None), (0, "expiring"), (-1, "expired"), (-30, "expired"), (-31, None)],
)
async def test_subscription_expiry_boundaries(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    offset: int,
    reason: str | None,
) -> None:
    owner = await make_user("owner")
    await make_user(
        created_at=at(ago(90)), subscription_expires_at=at(today() + timedelta(days=offset))
    )

    items = await churn(client, owner, auth_headers)

    assert [i["reasons"] for i in items] == ([[reason]] if reason else [])


async def test_young_member_skips_visit_rules_but_keeps_expiry(
    client: AsyncClient,
    make_user: UserFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user(
        created_at=at(ago(10)), subscription_expires_at=at(today() + timedelta(days=3))
    )
    await visit(db_session, student, 12)

    items = await churn(client, owner, auth_headers)

    assert [i["reasons"] for i in items] == [["expiring"]]


async def test_churn_order_excludes_non_students_and_scores_zero(
    client: AsyncClient,
    make_user: UserFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    healthy = await make_user(created_at=at(ago(90)))
    await visit(db_session, healthy, 1, 2, 3, 15, 16)
    await make_user("admin", created_at=at(ago(90)), subscription_expires_at=at(ago(2)))
    both = await make_user(created_at=at(ago(90)), subscription_expires_at=at(ago(2)))
    await visit(db_session, both, 20)
    only_expired = await make_user(created_at=at(ago(90)), subscription_expires_at=at(ago(2)))

    items = await churn(client, owner, auth_headers)

    assert [i["user_id"] for i in items] == [both.id, only_expired.id]
    assert [i["score"] for i in items] == [6, 3]


async def test_admin_sees_only_own_students_and_trainerless_stay_owner_only(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    admin = await make_user("admin")
    other = await make_user("admin")
    expired = at(ago(2))
    mine = await make_user(
        trainer_id=admin.id, created_at=at(ago(90)), subscription_expires_at=expired
    )
    await make_user(trainer_id=other.id, created_at=at(ago(90)), subscription_expires_at=expired)
    free = await make_user(created_at=at(ago(90)), subscription_expires_at=expired)

    own = await churn(client, admin, auth_headers)
    everyone = await churn(client, owner, auth_headers)
    forbidden = [
        await client.get("/v1/analytics/churn", headers=auth_headers(await make_user(role)))
        for role in ("barmen", "user")
    ]
    anonymous = await client.get("/v1/analytics/churn")

    assert [i["user_id"] for i in own] == [mine.id]
    assert free.id in {i["user_id"] for i in everyone}
    assert len(everyone) == 3
    assert [r.status_code for r in forbidden] == [403, 403]
    assert anonymous.status_code == 401


async def test_churn_exposes_only_documented_fields(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user("owner")
    await make_user(created_at=at(ago(90)), subscription_expires_at=at(ago(2)))

    items = await churn(client, owner, auth_headers)

    assert set(items[0]) == {
        "user_id",
        "name",
        "phone",
        "trainer_id",
        "trainer_name",
        "reasons",
        "score",
        "last_visit",
        "visits_last14",
        "visits_prev14",
        "expires_at",
    }


async def test_retention_counts_eligible_and_retained_by_trainer(
    client: AsyncClient,
    make_user: UserFactory,
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    trainer = await make_user("admin")
    joined = ago(120)
    kept = await make_user(trainer_id=trainer.id, created_at=at(joined))
    lost = await make_user(created_at=at(joined))
    young = await make_user(created_at=at(ago(40)))
    await visit(db_session, kept, 120 - 30, 120 - 43)
    await visit(db_session, lost, 120 - 29, 120 - 44)
    assert young.id

    response = await client.get(
        "/v1/analytics/retention", headers=auth_headers(owner), params=window(ago(130), ago(1))
    )

    assert response.status_code == 200
    by_day = {c["day"]: c for c in response.json()["cohorts"]}
    assert by_day[30] == {
        "day": 30,
        "eligible": 2,
        "retained": 1,
        "rate": 0.5,
        "with_trainer": {"eligible": 1, "retained": 1},
        "without_trainer": {"eligible": 1, "retained": 0},
    }
    assert by_day[60]["eligible"] == 2
    assert by_day[60]["retained"] == 0


@pytest.mark.parametrize(("joined_ago", "eligible"), [(44, 1), (43, 0)])
async def test_retention_eligibility_edge(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    joined_ago: int,
    eligible: int,
) -> None:
    owner = await make_user("owner")
    await make_user(created_at=at(ago(joined_ago)))

    response = await client.get(
        "/v1/analytics/retention",
        headers=auth_headers(owner),
        params=window(ago(joined_ago), ago(joined_ago)),
    )

    cohort = response.json()["cohorts"][0]
    assert cohort["eligible"] == eligible
    assert cohort["rate"] is None if not eligible else cohort["rate"] == 0.0


async def test_trainer_rows_visits_and_hard_share(
    client: AsyncClient,
    make_user: UserFactory,
    make_trainer: Callable[..., Awaitable[Trainer]],
    db_session: AsyncSession,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    coach = await make_user("admin", name="Coach")
    await make_trainer(coach)
    first = await make_user(trainer_id=coach.id)
    second = await make_user(trainer_id=coach.id)
    free = await make_user()
    await visit(db_session, first, 1, 2, 3, 4)
    await visit(db_session, free, 1)
    db_session.add_all(
        [
            Day(user_id=first.id, day=ago(1), feedback=3),
            Day(user_id=first.id, day=ago(2), feedback=1),
            Day(user_id=second.id, day=ago(3), feedback=3),
            Day(user_id=second.id, day=ago(4), feedback=3),
            Day(user_id=second.id, day=ago(5)),
        ]
    )
    await db_session.commit()

    response = await client.get(
        "/v1/analytics/trainers", headers=auth_headers(owner), params=window(ago(6), ago(0))
    )

    rows = {row["trainer_id"]: row for row in response.json()["rows"]}
    assert rows[coach.id] == {
        "trainer_id": coach.id,
        "name": "Coach",
        "students": 2,
        "active_students": 1,
        "visits_per_student_week": 2.0,
        "feedback_count": 4,
        "hard_count": 3,
        "hard_share": 0.75,
    }
    assert rows[None]["students"] == 1
    assert rows[None]["hard_share"] is None
    assert rows[None]["visits_per_student_week"] == 1.0


@pytest.mark.parametrize("path", ["retention", "trainers"])
async def test_owner_only_reports_and_bad_windows(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, path: str
) -> None:
    owner = await make_user("owner")
    url = f"/v1/analytics/{path}"
    good = window(ago(30), ago(0))

    denied = [
        await client.get(url, headers=auth_headers(await make_user(role)), params=good)
        for role in ("admin", "barmen", "user")
    ]
    bad = [
        await client.get(url, headers=auth_headers(owner), params=params)
        for params in (
            window(ago(0), ago(30)),
            window(ago(400), ago(0)),
            {"from": "nope", "to": "2026-10-01"},
            {},
        )
    ]
    anonymous = await client.get(url, params=good)

    assert [r.status_code for r in denied] == [403, 403, 403]
    assert [r.status_code for r in bad] == [422, 422, 422, 422]
    assert anonymous.status_code == 401
