import asyncio
from collections.abc import Awaitable, Callable
from datetime import UTC, date, datetime, timedelta
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Day, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]

TODAY = datetime.now(UTC).date()
DAY = TODAY.isoformat()
OTHER_DAY = (TODAY - timedelta(days=1)).isoformat()


def extra(at: int = 1000, **fields: Any) -> dict[str, Any]:
    return {"name": "Olma", "grams": 150.0, "kcal": 78.0, "protein": 0.4, "at": at, **fields}


def base(user: User, day: str = DAY) -> str:
    return f"/v1/users/{user.id}/days/{day}"


WRITE_CASES = [
    ("PUT", "/meals/3", {"done": True}),
    ("POST", "/extras", extra()),
    ("DELETE", "/extras/1000", None),
    ("PUT", "/workout/start", None),
    ("PUT", "/workout/exercises/Squat", {"done": True}),
    ("PUT", "/water", {"glasses": 3}),
]


async def call(
    client: AsyncClient,
    method: str,
    url: str,
    headers: dict[str, str] | None = None,
    json: Any = None,
) -> Any:
    return await client.request(method, url, headers=headers, json=json)


@pytest.fixture
async def student(make_user: UserFactory) -> User:
    return await make_user()


@pytest.mark.parametrize("who", ["self", "trainer", "owner"])
async def test_allowed_roles_read_a_day(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, who: str
) -> None:
    trainer = await make_user(role="admin")
    owner = await make_user(role="owner")
    student = await make_user(trainer_id=trainer.id)
    actor = {"self": student, "trainer": trainer, "owner": owner}[who]
    await client.put(f"{base(student)}/meals/2", headers=auth_headers(student), json={"done": True})

    response = await client.get(base(student), headers=auth_headers(actor))

    assert response.status_code == 200
    assert response.json()["done"] == [2]


@pytest.mark.parametrize("who", ["stranger", "other_trainer", "unassigned_staff", "barmen"])
async def test_other_roles_cannot_read_a_day(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, who: str
) -> None:
    trainer = await make_user(role="admin")
    student = await make_user(trainer_id=trainer.id)
    actors = {
        "stranger": await make_user(),
        "other_trainer": await make_user(role="admin"),
        "unassigned_staff": await make_user(role="admin", trainer_id=trainer.id),
        "barmen": await make_user(role="barmen"),
    }

    response = await client.get(base(student), headers=auth_headers(actors[who]))

    assert response.status_code == 403
    assert response.json()["detail"]["code"] == "forbidden"


async def test_anonymous_cannot_read_a_day(client: AsyncClient, student: User) -> None:
    response = await client.get(base(student))

    assert response.status_code == 401


async def test_reading_unknown_user_day_is_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.get(f"/v1/users/missing/days/{DAY}", headers=auth_headers(owner))

    assert response.status_code == 404
    assert response.json()["detail"]["code"] == "not_found"


async def test_day_without_row_returns_zero_state(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    response = await client.get(base(student), headers=auth_headers(student))

    assert response.status_code == 200
    assert response.json() == {
        "day": DAY,
        "done": [],
        "extras": [],
        "gym_started": False,
        "gym_done": [],
        "water": 0,
    }
    assert await db_session.scalar(select(func.count()).select_from(Day)) == 0


@pytest.mark.parametrize(("method", "suffix", "body"), WRITE_CASES)
async def test_user_writes_own_day(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    method: str,
    suffix: str,
    body: Any,
) -> None:
    response = await call(client, method, base(student) + suffix, auth_headers(student), body)

    assert response.status_code == 200
    assert response.json()["day"] == DAY


@pytest.mark.parametrize(("method", "suffix", "body"), WRITE_CASES)
@pytest.mark.parametrize("who", ["trainer", "owner", "stranger", "barmen"])
async def test_nobody_but_the_user_writes_a_day(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    method: str,
    suffix: str,
    body: Any,
    who: str,
) -> None:
    trainer = await make_user(role="admin")
    student = await make_user(trainer_id=trainer.id)
    actors = {
        "trainer": trainer,
        "owner": await make_user(role="owner"),
        "stranger": await make_user(),
        "barmen": await make_user(role="barmen"),
    }

    response = await call(client, method, base(student) + suffix, auth_headers(actors[who]), body)

    assert response.status_code == 403
    assert await db_session.scalar(select(func.count()).select_from(Day)) == 0


@pytest.mark.parametrize(("method", "suffix", "body"), WRITE_CASES)
async def test_anonymous_cannot_write_a_day(
    client: AsyncClient, student: User, method: str, suffix: str, body: Any
) -> None:
    response = await call(client, method, base(student) + suffix, None, body)

    assert response.status_code == 401


async def test_barmen_writes_and_reads_own_day(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    barmen = await make_user(role="barmen")

    write = await client.put(
        f"{base(barmen)}/water", headers=auth_headers(barmen), json={"glasses": 4}
    )
    read = await client.get(base(barmen), headers=auth_headers(barmen))

    assert write.status_code == 200
    assert read.json()["water"] == 4


async def test_owner_writes_own_day(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")

    response = await client.put(
        f"{base(owner)}/meals/0", headers=auth_headers(owner), json={"done": True}
    )

    assert response.status_code == 200


async def test_meal_toggle_adds_removes_and_keeps_set_semantics(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)

    for index in (5, 1, 5, 3):
        response = await client.put(f"{url}/meals/{index}", headers=headers, json={"done": True})
    assert response.json()["done"] == [1, 3, 5]

    removed = await client.put(f"{url}/meals/3", headers=headers, json={"done": False})
    absent = await client.put(f"{url}/meals/40", headers=headers, json={"done": False})

    assert removed.json()["done"] == [1, 5]
    assert absent.json()["done"] == [1, 5]
    assert (await client.get(url, headers=headers)).json()["done"] == [1, 5]


async def test_meal_index_boundaries(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)

    low = await client.put(f"{base(student)}/meals/0", headers=headers, json={"done": True})
    high = await client.put(f"{base(student)}/meals/49", headers=headers, json={"done": True})

    assert low.status_code == 200
    assert high.json()["done"] == [0, 49]


@pytest.mark.parametrize("index", ["50", "-1", "abc", "1.5"])
async def test_meal_index_out_of_range_is_422(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, index: str
) -> None:
    response = await client.put(
        f"{base(student)}/meals/{index}", headers=auth_headers(student), json={"done": True}
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


@pytest.mark.parametrize("body", [{}, {"done": "maybe"}, {"done": True, "extra": 1}, None])
async def test_meal_body_is_validated(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, body: Any
) -> None:
    response = await client.put(
        f"{base(student)}/meals/1", headers=auth_headers(student), json=body
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "day",
    [
        "2020-13-01",
        "2024-02-30",
        "not-a-date",
        "20240101",
        "2024-1-1",
        "2019-12-31",
        (TODAY + timedelta(days=3)).isoformat(),
        "9999-12-31",
    ],
)
async def test_invalid_or_out_of_window_day_is_422(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, day: str
) -> None:
    headers = auth_headers(student)

    read = await client.get(base(student, day), headers=headers)
    write = await client.put(f"{base(student, day)}/water", headers=headers, json={"glasses": 1})

    assert read.status_code == 422
    assert write.status_code == 422
    assert read.json()["detail"]["code"] == "validation_error"
    assert read.json()["detail"]["errors"][0]["field"] == "path.day"


@pytest.mark.parametrize("day", ["2020-01-01", (TODAY + timedelta(days=2)).isoformat()])
async def test_day_window_edges_are_accepted(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, day: str
) -> None:
    response = await client.put(
        f"{base(student, day)}/water", headers=auth_headers(student), json={"glasses": 1}
    )

    assert response.status_code == 200
    assert response.json()["day"] == day


async def test_extras_add_remove_and_sort_by_at(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)

    await client.post(f"{url}/extras", headers=headers, json=extra(at=3000, name="C"))
    await client.post(f"{url}/extras", headers=headers, json=extra(at=1000, name="A"))
    added = await client.post(f"{url}/extras", headers=headers, json=extra(at=2000, name="B"))

    assert added.status_code == 200
    assert [item["name"] for item in added.json()["extras"]] == ["A", "B", "C"]
    assert added.json()["extras"][0] == extra(at=1000, name="A")

    removed = await client.delete(f"{url}/extras/2000", headers=headers)

    assert removed.status_code == 200
    assert [item["at"] for item in removed.json()["extras"]] == [1000, 3000]


async def test_duplicate_extra_at_is_409_and_keeps_original(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)
    await client.post(f"{url}/extras", headers=headers, json=extra(at=1000, name="First"))

    response = await client.post(f"{url}/extras", headers=headers, json=extra(at=1000, name="Dup"))

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "extra_exists"
    stored = (await client.get(url, headers=headers)).json()["extras"]
    assert [item["name"] for item in stored] == ["First"]


async def test_same_extra_at_on_different_days_is_allowed(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)

    first = await client.post(f"{base(student)}/extras", headers=headers, json=extra())
    second = await client.post(f"{base(student, OTHER_DAY)}/extras", headers=headers, json=extra())

    assert first.status_code == second.status_code == 200


async def test_removing_absent_extra_is_idempotent_200(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)
    await client.post(f"{url}/extras", headers=headers, json=extra(at=1000))

    missing_at = await client.delete(f"{url}/extras/9", headers=headers)
    missing_row = await client.delete(f"{base(student, OTHER_DAY)}/extras/9", headers=headers)

    assert missing_at.status_code == 200
    assert [item["at"] for item in missing_at.json()["extras"]] == [1000]
    assert missing_row.status_code == 200
    assert missing_row.json()["extras"] == []


async def test_extras_limit_is_50_per_day(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)
    results = await asyncio.gather(
        *(client.post(f"{url}/extras", headers=headers, json=extra(at=n)) for n in range(50))
    )
    assert {r.status_code for r in results} == {200}

    response = await client.post(f"{url}/extras", headers=headers, json=extra(at=999))

    assert response.status_code == 409
    assert response.json()["detail"]["code"] == "extras_limit"
    assert len((await client.get(url, headers=headers)).json()["extras"]) == 50


@pytest.mark.parametrize(
    "body",
    [
        extra(grams=-1),
        extra(kcal=-0.5),
        extra(protein=-1),
        extra(name=""),
        extra(name="x" * 81),
        extra(at=-1),
        extra(at="soon"),
        extra(at=1.5),
        {"name": "Olma", "grams": 1, "kcal": 1, "protein": 1},
        {**extra(), "unknown": 1},
        {},
    ],
)
async def test_invalid_extra_is_422(
    client: AsyncClient,
    student: User,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    body: dict[str, Any],
) -> None:
    response = await client.post(
        f"{base(student)}/extras", headers=auth_headers(student), json=body
    )

    assert response.status_code == 422
    assert await db_session.scalar(select(func.count()).select_from(Day)) == 0


async def test_extra_boundary_values_are_accepted(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    body = extra(name="x" * 80, grams=0, kcal=0, protein=0, at=0)

    response = await client.post(
        f"{base(student)}/extras", headers=auth_headers(student), json=body
    )

    assert response.status_code == 200
    assert response.json()["extras"][0]["name"] == "x" * 80


async def test_extra_at_must_be_an_integer_path(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.delete(f"{base(student)}/extras/abc", headers=auth_headers(student))

    assert response.status_code == 422


async def test_workout_start_sets_flag_and_keeps_other_fields(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)
    await client.put(f"{url}/water", headers=headers, json={"glasses": 5})

    response = await client.put(f"{url}/workout/start", headers=headers)

    assert response.status_code == 200
    assert response.json()["gym_started"] is True
    assert response.json()["water"] == 5
    assert response.json()["gym_done"] == []


async def test_exercise_toggle_sets_started_and_behaves_as_set(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)

    first = await client.put(f"{url}/workout/exercises/Squat", headers=headers, json={"done": True})
    again = await client.put(f"{url}/workout/exercises/Squat", headers=headers, json={"done": True})
    other = await client.put(f"{url}/workout/exercises/c:abc", headers=headers, json={"done": True})

    assert first.json()["gym_started"] is True
    assert again.json()["gym_done"] == ["Squat"]
    assert other.json()["gym_done"] == ["Squat", "c:abc"]

    removed = await client.put(
        f"{url}/workout/exercises/Squat", headers=headers, json={"done": False}
    )

    assert removed.json()["gym_done"] == ["c:abc"]
    assert removed.json()["gym_started"] is True


async def test_exercise_removal_on_missing_row_still_starts_workout(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        f"{base(student)}/workout/exercises/Squat",
        headers=auth_headers(student),
        json={"done": False},
    )

    assert response.status_code == 200
    assert response.json()["gym_done"] == []
    assert response.json()["gym_started"] is True


async def test_exercise_key_with_spaces_slash_and_unicode(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    key = "Yotib turib bosish / gantel o'g'il"

    response = await client.put(
        f"{base(student)}/workout/exercises/{key}",
        headers=auth_headers(student),
        json={"done": True},
    )

    assert response.status_code == 200
    assert response.json()["gym_done"] == [key]


async def test_exercise_key_length_limits(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = f"{base(student)}/workout/exercises"

    longest = await client.put(f"{url}/{'k' * 100}", headers=headers, json={"done": True})
    too_long = await client.put(f"{url}/{'k' * 101}", headers=headers, json={"done": True})
    empty = await client.put(f"{url}/", headers=headers, json={"done": True})

    assert longest.status_code == 200
    assert too_long.status_code == 422
    assert empty.status_code == 422


async def test_gym_done_limit_is_100_keys(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = f"{base(student)}/workout/exercises"
    results = await asyncio.gather(
        *(client.put(f"{url}/k{n}", headers=headers, json={"done": True}) for n in range(100))
    )
    assert {r.status_code for r in results} == {200}

    overflow = await client.put(f"{url}/extra", headers=headers, json={"done": True})
    existing = await client.put(f"{url}/k7", headers=headers, json={"done": True})
    removed = await client.put(f"{url}/k7", headers=headers, json={"done": False})
    added = await client.put(f"{url}/extra", headers=headers, json={"done": True})

    assert overflow.status_code == 409
    assert overflow.json()["detail"]["code"] == "gym_done_limit"
    assert existing.status_code == 200
    assert removed.status_code == 200
    assert added.status_code == 200
    assert len(added.json()["gym_done"]) == 100


async def test_water_set_overwrite_and_boundaries(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = f"{base(student)}/water"

    top = await client.put(url, headers=headers, json={"glasses": 30})
    reset = await client.put(url, headers=headers, json={"glasses": 0})

    assert top.json()["water"] == 30
    assert reset.json()["water"] == 0


@pytest.mark.parametrize(
    "body", [{"glasses": 31}, {"glasses": -1}, {"glasses": 1.5}, {"glasses": "x"}, {}, None]
)
async def test_invalid_water_is_422(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, body: Any
) -> None:
    response = await client.put(f"{base(student)}/water", headers=auth_headers(student), json=body)

    assert response.status_code == 422


async def test_writes_to_different_fields_share_one_row(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, db_session: AsyncSession
) -> None:
    headers = auth_headers(student)
    url = base(student)
    await client.put(f"{url}/meals/1", headers=headers, json={"done": True})
    await client.post(f"{url}/extras", headers=headers, json=extra())
    await client.put(f"{url}/water", headers=headers, json={"glasses": 2})
    final = await client.put(f"{url}/workout/exercises/Squat", headers=headers, json={"done": True})

    assert final.json() == {
        "day": DAY,
        "done": [1],
        "extras": [extra()],
        "gym_started": True,
        "gym_done": ["Squat"],
        "water": 2,
    }
    assert await db_session.scalar(select(func.count()).select_from(Day)) == 1


async def test_parallel_meal_toggles_on_a_new_day_all_persist(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)

    results = await asyncio.gather(
        *(
            client.put(f"{url}/meals/{index}", headers=headers, json={"done": True})
            for index in range(25)
        )
    )

    assert {r.status_code for r in results} == {200}
    stored = (await client.get(url, headers=headers)).json()["done"]
    assert stored == list(range(25))


async def test_parallel_mixed_toggles_on_existing_day_do_not_lose_updates(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)
    await client.put(f"{url}/meals/0", headers=headers, json={"done": True})
    await client.put(f"{url}/meals/1", headers=headers, json={"done": True})

    results = await asyncio.gather(
        client.put(f"{url}/meals/0", headers=headers, json={"done": False}),
        client.put(f"{url}/meals/2", headers=headers, json={"done": True}),
        client.put(f"{url}/meals/3", headers=headers, json={"done": True}),
        client.put(f"{url}/water", headers=headers, json={"glasses": 6}),
        client.post(f"{url}/extras", headers=headers, json=extra(at=5)),
        client.put(f"{url}/workout/exercises/Squat", headers=headers, json={"done": True}),
    )

    assert {r.status_code for r in results} == {200}
    state = (await client.get(url, headers=headers)).json()
    assert state["done"] == [1, 2, 3]
    assert state["water"] == 6
    assert [item["at"] for item in state["extras"]] == [5]
    assert state["gym_done"] == ["Squat"]


async def test_parallel_extras_with_distinct_at_all_persist(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)

    results = await asyncio.gather(
        *(client.post(f"{url}/extras", headers=headers, json=extra(at=n)) for n in range(10))
    )

    assert {r.status_code for r in results} == {200}
    stored = (await client.get(url, headers=headers)).json()["extras"]
    assert [item["at"] for item in stored] == list(range(10))


async def test_parallel_extras_with_same_at_yield_exactly_one_success(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = base(student)

    results = await asyncio.gather(
        *(client.post(f"{url}/extras", headers=headers, json=extra(at=7)) for _ in range(6))
    )

    assert sorted(r.status_code for r in results) == [200, 409, 409, 409, 409, 409]
    stored = (await client.get(url, headers=headers)).json()["extras"]
    assert len(stored) == 1


async def test_parallel_exercise_toggles_all_persist(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = f"{base(student)}/workout/exercises"

    results = await asyncio.gather(
        *(client.put(f"{url}/k{n}", headers=headers, json={"done": True}) for n in range(15))
    )

    assert {r.status_code for r in results} == {200}
    stored = (await client.get(base(student), headers=headers)).json()["gym_done"]
    assert sorted(stored) == sorted(f"k{n}" for n in range(15))


async def test_range_returns_existing_days_ordered_by_date(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    days = ["2026-03-05", "2026-03-01", "2026-03-03"]
    for day in days:
        await client.put(f"{base(student, day)}/water", headers=headers, json={"glasses": 1})
    await client.put(f"{base(student, '2026-04-01')}/water", headers=headers, json={"glasses": 1})

    response = await client.get(
        f"/v1/users/{student.id}/days",
        headers=headers,
        params={"from": "2026-03-01", "to": "2026-03-05"},
    )

    assert response.status_code == 200
    assert [item["day"] for item in response.json()] == ["2026-03-01", "2026-03-03", "2026-03-05"]


async def test_range_is_inclusive_and_empty_when_no_rows(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    await client.put(f"{base(student, '2026-03-01')}/water", headers=headers, json={"glasses": 1})

    single = await client.get(
        f"/v1/users/{student.id}/days",
        headers=headers,
        params={"from": "2026-03-01", "to": "2026-03-01"},
    )
    empty = await client.get(
        f"/v1/users/{student.id}/days",
        headers=headers,
        params={"from": "2026-02-01", "to": "2026-02-28"},
    )

    assert len(single.json()) == 1
    assert empty.json() == []


async def test_range_only_includes_the_requested_user(
    client: AsyncClient, make_user: UserFactory, student: User, auth_headers: HeadersFactory
) -> None:
    other = await make_user()
    await client.put(f"{base(other)}/water", headers=auth_headers(other), json={"glasses": 1})

    response = await client.get(
        f"/v1/users/{student.id}/days",
        headers=auth_headers(student),
        params={"from": DAY, "to": DAY},
    )

    assert response.json() == []


async def test_range_span_limit_is_400_days(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    headers = auth_headers(student)
    url = f"/v1/users/{student.id}/days"
    start = date(2025, 1, 1)

    allowed = await client.get(
        url,
        headers=headers,
        params={"from": start.isoformat(), "to": (start + timedelta(399)).isoformat()},
    )
    refused = await client.get(
        url,
        headers=headers,
        params={"from": start.isoformat(), "to": (start + timedelta(400)).isoformat()},
    )

    assert allowed.status_code == 200
    assert refused.status_code == 422
    assert refused.json()["detail"]["code"] == "validation_error"


@pytest.mark.parametrize(
    "params",
    [
        {},
        {"from": "2026-03-01"},
        {"to": "2026-03-01"},
        {"from": "2026-03-05", "to": "2026-03-01"},
        {"from": "bad", "to": "2026-03-01"},
        {"from": "2026-03-01", "to": "2026-02-30"},
        {"from": "20260301", "to": "20260302"},
        {"from": "2026-03-01", "to": "2026-03-02", "extra": "1"},
    ],
)
async def test_range_query_is_validated(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, params: dict[str, str]
) -> None:
    response = await client.get(
        f"/v1/users/{student.id}/days", headers=auth_headers(student), params=params
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "validation_error"


@pytest.mark.parametrize("who", ["trainer", "owner"])
async def test_range_is_readable_by_managers(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, who: str
) -> None:
    trainer = await make_user(role="admin")
    owner = await make_user(role="owner")
    student = await make_user(trainer_id=trainer.id)
    await client.put(f"{base(student)}/water", headers=auth_headers(student), json={"glasses": 1})

    response = await client.get(
        f"/v1/users/{student.id}/days",
        headers=auth_headers({"trainer": trainer, "owner": owner}[who]),
        params={"from": DAY, "to": DAY},
    )

    assert response.status_code == 200
    assert len(response.json()) == 1


@pytest.mark.parametrize("who", ["stranger", "other_trainer", "barmen"])
async def test_range_is_forbidden_for_others(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory, who: str
) -> None:
    trainer = await make_user(role="admin")
    student = await make_user(trainer_id=trainer.id)
    actors = {
        "stranger": await make_user(),
        "other_trainer": await make_user(role="admin"),
        "barmen": await make_user(role="barmen"),
    }

    response = await client.get(
        f"/v1/users/{student.id}/days",
        headers=auth_headers(actors[who]),
        params={"from": DAY, "to": DAY},
    )

    assert response.status_code == 403


async def test_range_anonymous_is_401_and_unknown_user_is_404(
    client: AsyncClient, student: User, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    owner = await make_user(role="owner")
    params = {"from": DAY, "to": DAY}

    anonymous = await client.get(f"/v1/users/{student.id}/days", params=params)
    unknown = await client.get("/v1/users/missing/days", headers=auth_headers(owner), params=params)

    assert anonymous.status_code == 401
    assert unknown.status_code == 404


async def test_days_are_removed_with_their_user(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user(role="owner")
    student = await make_user()
    await client.put(f"{base(student)}/water", headers=auth_headers(student), json={"glasses": 1})

    response = await client.delete(f"/v1/users/{student.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert await db_session.scalar(select(func.count()).select_from(Day)) == 0
