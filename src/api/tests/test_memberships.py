from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.models import Gym, Membership, Subscription, User

UserFactory = Callable[..., Awaitable[User]]
HeadersFactory = Callable[[User], dict[str, str]]
MembershipFactory = Callable[..., Awaitable[Membership]]
SubscriptionFactory = Callable[..., Awaitable[Subscription]]
GymFactory = Callable[..., Awaitable[Gym]]

MEMBERSHIP_KEYS = {
    "user_id",
    "name",
    "gym_id",
    "months",
    "days",
    "price",
    "currency",
    "paid_date",
    "expires_at",
    "updated_at",
}


async def ids_for(client: AsyncClient, actor_headers: dict[str, str]) -> list[str]:
    response = await client.get("/v1/memberships", headers=actor_headers)
    assert response.status_code == 200
    return [item["user_id"] for item in response.json()]


async def seed_two_gyms(
    make_user: UserFactory, make_gym: GymFactory, make_membership: MembershipFactory
) -> tuple[Gym, Gym, User, User, User]:
    gym_a = await make_gym()
    gym_b = await make_gym()
    client_a = await make_user()
    client_b = await make_user()
    client_none = await make_user()
    await make_membership(client_a.id, gym_id=gym_a.id)
    await make_membership(client_b.id, gym_id=gym_b.id)
    await make_membership(client_none.id, gym_id="")
    return gym_a, gym_b, client_a, client_b, client_none


async def test_owner_lists_every_membership(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    _, _, client_a, client_b, client_none = await seed_two_gyms(
        make_user, make_gym, make_membership
    )

    ids = await ids_for(client, auth_headers(owner))

    assert sorted(ids) == sorted([client_a.id, client_b.id, client_none.id])


@pytest.mark.parametrize("role", ["admin", "barmen"])
async def test_staff_and_barmen_list_only_their_own_gym(
    role: str,
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym_a, _, client_a, _, _ = await seed_two_gyms(make_user, make_gym, make_membership)
    actor = await make_user(role, gym_id=gym_a.id)

    ids = await ids_for(client, auth_headers(actor))

    assert ids == [client_a.id]


@pytest.mark.parametrize("role", ["admin", "barmen"])
async def test_gymless_staff_and_barmen_get_an_empty_list(
    role: str,
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    await seed_two_gyms(make_user, make_gym, make_membership)
    actor = await make_user(role)

    ids = await ids_for(client, auth_headers(actor))

    assert ids == []


async def test_user_cannot_list_memberships_and_anonymous_is_401(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    forbidden = await client.get("/v1/memberships", headers=auth_headers(student))
    anonymous = await client.get("/v1/memberships")

    assert forbidden.status_code == 403
    assert anonymous.status_code == 401


async def test_list_items_have_the_documented_shape(
    client: AsyncClient,
    make_user: UserFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_membership(student.id, name="Aziz", currency="USD", price=70)

    response = await client.get("/v1/memberships", headers=auth_headers(owner))

    item = response.json()[0]
    assert set(item) == MEMBERSHIP_KEYS
    assert (item["name"], item["currency"], item["price"]) == ("Aziz", "USD", 70)


@pytest.mark.parametrize("actor_kind", ["self", "owner", "staff", "barmen"])
async def test_allowed_actors_read_a_single_membership(
    actor_kind: str,
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    student = await make_user()
    await make_membership(student.id, gym_id=gym.id)
    actors = {
        "self": student,
        "owner": await make_user("owner"),
        "staff": await make_user("admin", gym_id=gym.id),
        "barmen": await make_user("barmen", gym_id=gym.id),
    }

    response = await client.get(
        f"/v1/memberships/{student.id}", headers=auth_headers(actors[actor_kind])
    )

    assert response.status_code == 200
    assert set(response.json()) == MEMBERSHIP_KEYS
    assert response.json()["user_id"] == student.id


@pytest.mark.parametrize("actor_kind", ["other_gym_staff", "other_gym_barmen", "gymless_staff"])
async def test_actors_outside_the_gym_get_403_for_a_single_membership(
    actor_kind: str,
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    gym = await make_gym()
    other_gym = await make_gym()
    student = await make_user()
    await make_membership(student.id, gym_id=gym.id)
    actors = {
        "other_gym_staff": await make_user("admin", gym_id=other_gym.id),
        "other_gym_barmen": await make_user("barmen", gym_id=other_gym.id),
        "gymless_staff": await make_user("admin"),
    }

    response = await client.get(
        f"/v1/memberships/{student.id}", headers=auth_headers(actors[actor_kind])
    )

    assert response.status_code == 403


async def test_gymless_staff_cannot_read_a_gymless_membership(
    client: AsyncClient,
    make_user: UserFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    student = await make_user()
    await make_membership(student.id, gym_id="")
    staff = await make_user("admin")

    response = await client.get(f"/v1/memberships/{student.id}", headers=auth_headers(staff))

    assert response.status_code == 403


async def test_other_user_cannot_read_a_membership_and_anonymous_is_401(
    client: AsyncClient,
    make_user: UserFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    student = await make_user()
    other = await make_user()
    await make_membership(student.id)

    forbidden = await client.get(f"/v1/memberships/{student.id}", headers=auth_headers(other))
    anonymous = await client.get(f"/v1/memberships/{student.id}")

    assert forbidden.status_code == 403
    assert anonymous.status_code == 401


async def test_reading_a_missing_membership_is_404(
    client: AsyncClient, make_user: UserFactory, auth_headers: HeadersFactory
) -> None:
    student = await make_user()

    own = await client.get(f"/v1/memberships/{student.id}", headers=auth_headers(student))
    unknown = await client.get("/v1/memberships/missing", headers=auth_headers(student))

    assert own.status_code == 404
    assert unknown.status_code == 404
    assert own.json()["detail"]["code"] == "not_found"


async def test_owner_deletes_a_membership_and_keeps_subscriptions_and_profile(
    client: AsyncClient,
    make_user: UserFactory,
    make_membership: MembershipFactory,
    make_subscription: SubscriptionFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_membership(student.id)
    await make_subscription(student.id)

    response = await client.delete(f"/v1/memberships/{student.id}", headers=auth_headers(owner))
    again = await client.delete(f"/v1/memberships/{student.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert response.content == b""
    assert again.status_code == 404
    assert await db_session.get(Membership, student.id) is None
    count = await db_session.scalar(select(func.count()).select_from(Subscription))
    assert count == 1
    assert await db_session.get(User, student.id) is not None


@pytest.mark.parametrize("actor_kind", ["staff", "barmen", "self", "other_user"])
async def test_non_owner_delete_is_403_and_keeps_the_row(
    actor_kind: str,
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym = await make_gym()
    student = await make_user()
    await make_membership(student.id, gym_id=gym.id)
    actors = {
        "staff": await make_user("admin", gym_id=gym.id),
        "barmen": await make_user("barmen", gym_id=gym.id),
        "self": student,
        "other_user": await make_user(),
    }

    response = await client.delete(
        f"/v1/memberships/{student.id}", headers=auth_headers(actors[actor_kind])
    )

    assert response.status_code == 403
    assert await db_session.get(Membership, student.id) is not None


async def test_anonymous_delete_is_401(client: AsyncClient, make_user: UserFactory) -> None:
    student = await make_user()

    response = await client.delete(f"/v1/memberships/{student.id}")

    assert response.status_code == 401


async def test_deleting_the_user_removes_the_membership(
    client: AsyncClient,
    make_user: UserFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_membership(student.id)

    response = await client.delete(f"/v1/users/{student.id}", headers=auth_headers(owner))

    assert response.status_code == 204
    assert await db_session.get(Membership, student.id) is None


async def test_membership_is_not_writable_through_the_api(
    client: AsyncClient,
    make_user: UserFactory,
    make_membership: MembershipFactory,
    auth_headers: HeadersFactory,
) -> None:
    owner = await make_user("owner")
    student = await make_user()
    await make_membership(student.id)
    body: dict[str, Any] = {"price": 1}

    put = await client.put(f"/v1/memberships/{student.id}", headers=auth_headers(owner), json=body)
    patch = await client.patch(
        f"/v1/memberships/{student.id}", headers=auth_headers(owner), json=body
    )
    post = await client.post("/v1/memberships", headers=auth_headers(owner), json=body)

    assert {put.status_code, patch.status_code, post.status_code} == {405}


async def test_membership_mirror_follows_the_trainer_gym_after_a_new_subscription(
    client: AsyncClient,
    make_user: UserFactory,
    make_gym: GymFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    gym_a = await make_gym()
    gym_b = await make_gym()
    owner = await make_user("owner")
    trainer = await make_user("admin", gym_id=gym_a.id)
    student = await make_user(trainer_id=trainer.id)
    barmen_a = await make_user("barmen", gym_id=gym_a.id)
    barmen_b = await make_user("barmen", gym_id=gym_b.id)
    body = {
        "start_date": "2026-10-01T00:00:00+05:00",
        "months": 1,
        "price": 100,
        "currency": "UZS",
    }
    url = f"/v1/users/{student.id}/subscriptions"

    await client.post(url, headers=auth_headers(owner), json=body)
    assert await ids_for(client, auth_headers(barmen_a)) == [student.id]
    assert await ids_for(client, auth_headers(barmen_b)) == []

    trainer.gym_id = gym_b.id
    await db_session.commit()
    await client.post(url, headers=auth_headers(owner), json=body)

    assert await ids_for(client, auth_headers(barmen_a)) == []
    assert await ids_for(client, auth_headers(barmen_b)) == [student.id]


async def test_membership_keeps_the_name_copy_from_payment_time(
    client: AsyncClient,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    owner = await make_user("owner")
    student = await make_user(name="Old Name")
    body = {
        "start_date": datetime(2026, 10, 1, tzinfo=UTC).isoformat(),
        "months": 1,
        "price": 100,
        "currency": "UZS",
    }

    await client.post(
        f"/v1/users/{student.id}/subscriptions", headers=auth_headers(owner), json=body
    )
    student.name = "New Name"
    await db_session.commit()

    response = await client.get(f"/v1/memberships/{student.id}", headers=auth_headers(owner))

    assert response.json()["name"] == "Old Name"
