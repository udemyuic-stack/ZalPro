from collections.abc import Awaitable, Callable
from datetime import date, timedelta

import pytest
from httpx import AsyncClient

from zalpro_api.models import Gym, User

UserFactory = Callable[..., Awaitable[User]]
GymFactory = Callable[..., Awaitable[Gym]]
HeadersFactory = Callable[[User], dict[str, str]]

TODAY = date.today()
YESTERDAY = TODAY - timedelta(days=1)
EXERCISE = "bench"


def url(user: User, day: date, exercise: str = EXERCISE) -> str:
    return f"/v1/users/{user.id}/exercise-sets/{day.isoformat()}/{exercise}"


def sets_body(*items: tuple[int, float | None, int | None]) -> dict[str, object]:
    return {"sets": [{"set_no": n, "weight_kg": w, "reps": r} for n, w, r in items]}


@pytest.fixture
async def student(make_user: UserFactory) -> User:
    return await make_user()


@pytest.fixture
async def stranger(make_user: UserFactory) -> User:
    return await make_user()


async def test_user_replaces_and_reads_own_sets(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    put = await client.put(
        url(student, TODAY),
        headers=auth_headers(student),
        json=sets_body((2, 62.5, 8), (1, 60, 10)),
    )
    assert put.status_code == 200
    assert put.json()["sets"] == [
        {"set_no": 1, "weight_kg": 60.0, "reps": 10},
        {"set_no": 2, "weight_kg": 62.5, "reps": 8},
    ]
    again = await client.put(
        url(student, TODAY), headers=auth_headers(student), json=sets_body((1, 65, 5))
    )
    assert again.json()["sets"] == [{"set_no": 1, "weight_kg": 65.0, "reps": 5}]
    read = await client.get(url(student, TODAY), headers=auth_headers(student))
    assert read.json()["sets"] == [{"set_no": 1, "weight_kg": 65.0, "reps": 5}]


async def test_previous_returns_latest_earlier_day(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    older = TODAY - timedelta(days=5)
    await client.put(
        url(student, older), headers=auth_headers(student), json=sets_body((1, 50, 12))
    )
    await client.put(
        url(student, YESTERDAY), headers=auth_headers(student), json=sets_body((1, 60, 10))
    )
    await client.put(url(student, TODAY), headers=auth_headers(student), json=sets_body((1, 70, 6)))
    response = await client.get(
        f"/v1/users/{student.id}/exercise-sets/{EXERCISE}/previous",
        params={"before": TODAY.isoformat()},
        headers=auth_headers(student),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["day"] == YESTERDAY.isoformat()
    assert body["sets"] == [{"set_no": 1, "weight_kg": 60.0, "reps": 10}]


async def test_previous_empty_without_history(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(
        f"/v1/users/{student.id}/exercise-sets/{EXERCISE}/previous",
        params={"before": TODAY.isoformat()},
        headers=auth_headers(student),
    )
    assert response.status_code == 200
    assert response.json()["sets"] == []


async def test_stranger_cannot_read_or_write(
    client: AsyncClient, student: User, stranger: User, auth_headers: HeadersFactory
) -> None:
    read = await client.get(url(student, TODAY), headers=auth_headers(stranger))
    assert read.status_code == 403
    write = await client.put(
        url(student, TODAY), headers=auth_headers(stranger), json=sets_body((1, 1, 1))
    )
    assert write.status_code == 403
    previous = await client.get(
        f"/v1/users/{student.id}/exercise-sets/{EXERCISE}/previous",
        params={"before": TODAY.isoformat()},
        headers=auth_headers(stranger),
    )
    assert previous.status_code == 403


async def test_assigned_trainer_reads_but_cannot_write(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    admin = await make_user(role="admin", gym_id=gym.id)
    member = await make_user(gym_id=gym.id, trainer_id=admin.id)
    await client.put(url(member, TODAY), headers=auth_headers(member), json=sets_body((1, 60, 10)))
    read = await client.get(url(member, TODAY), headers=auth_headers(admin))
    assert read.status_code == 200
    write = await client.put(
        url(member, TODAY), headers=auth_headers(admin), json=sets_body((1, 1, 1))
    )
    assert write.status_code == 403


async def test_unassigned_staff_cannot_read(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
) -> None:
    first = await make_gym()
    second = await make_gym()
    member = await make_user(gym_id=first.id)
    admin = await make_user(role="admin", gym_id=second.id)
    read = await client.get(url(member, TODAY), headers=auth_headers(admin))
    assert read.status_code == 403


@pytest.mark.parametrize("set_no", [0, 21])
async def test_set_no_out_of_range_rejected(
    client: AsyncClient, student: User, auth_headers: HeadersFactory, set_no: int
) -> None:
    response = await client.put(
        url(student, TODAY), headers=auth_headers(student), json=sets_body((set_no, 10, 10))
    )
    assert response.status_code == 422


async def test_duplicate_set_no_rejected(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        url(student, TODAY),
        headers=auth_headers(student),
        json=sets_body((1, 10, 10), (1, 20, 5)),
    )
    assert response.status_code == 422


async def test_extra_field_rejected(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.put(
        url(student, TODAY),
        headers=auth_headers(student),
        json={"sets": [{"set_no": 1, "weight_kg": 1, "reps": 1, "rpe": 9}]},
    )
    assert response.status_code == 422


async def test_unknown_user_404(
    client: AsyncClient, student: User, auth_headers: HeadersFactory
) -> None:
    response = await client.get(
        f"/v1/users/missing/exercise-sets/{TODAY.isoformat()}/{EXERCISE}",
        headers=auth_headers(student),
    )
    assert response.status_code == 404
