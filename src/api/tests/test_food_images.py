import uuid
from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import FakeStorage
from zalpro_api.models import Food, User
from zalpro_api.models.photo import MAX_IMAGE_BYTES
from zalpro_api.services.storage import UnconfiguredStorage

UserFactory = Callable[..., Awaitable[User]]
FoodFactory = Callable[..., Awaitable[Food]]
HeadersFactory = Callable[[User], dict[str, str]]

STAFF_ROLES = ["admin", "owner"]
NON_STAFF_ROLES = ["user", "barmen"]
ALL_ROLES = ["user", "barmen", "admin", "owner"]
UPLOAD = {"size": 200_000, "content_type": "image/jpeg"}


def image_url(food: Food) -> str:
    return f"/v1/foods/{food.id}/image"


def new_key(food: Food, extension: str = "jpg") -> str:
    return f"images/foods/{food.id}/{uuid.uuid4().hex}.{extension}"


async def refresh(db_session: AsyncSession, food: Food) -> Food:
    await db_session.refresh(food)
    return food


@pytest.mark.parametrize("role", STAFF_ROLES)
@pytest.mark.parametrize(
    ("content_type", "extension"),
    [("image/jpeg", "jpg"), ("image/png", "png"), ("image/webp", "webp")],
)
async def test_staff_gets_upload_url_for_food_prefix(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
    content_type: str,
    extension: str,
) -> None:
    actor = await make_user(role=role)
    food = await make_food()

    response = await client.post(
        f"{image_url(food)}/upload-url",
        headers=auth_headers(actor),
        json={"size": 300_000, "content_type": content_type},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["key"].startswith(f"images/foods/{food.id}/")
    assert body["key"].endswith(f".{extension}")
    assert body["upload_url"].startswith("https://storage.test/put/")
    assert body["expires_in"] == 600
    assert storage.put_calls == [(body["key"], 300_000)]
    assert (await refresh(db_session, food)).image_key is None


@pytest.mark.parametrize(
    "payload",
    [
        {"size": 0, "content_type": "image/jpeg"},
        {"size": MAX_IMAGE_BYTES + 1, "content_type": "image/jpeg"},
        {"size": "10", "content_type": "image/jpeg"},
        {"size": 10, "content_type": "image/gif"},
        {"size": 10, "content_type": "video/mp4"},
        {"size": 10},
        {"content_type": "image/jpeg"},
        {"size": 10, "content_type": "image/jpeg", "url": "https://x"},
    ],
)
async def test_upload_url_rejects_bad_payload(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()

    response = await client.post(
        f"{image_url(food)}/upload-url", headers=auth_headers(actor), json=payload
    )

    assert response.status_code == 422
    assert storage.put_calls == []


@pytest.mark.parametrize("role", NON_STAFF_ROLES)
async def test_non_staff_cannot_manage_food_image(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    actor = await make_user(role=role)
    food = await make_food()
    headers = auth_headers(actor)

    responses = [
        await client.post(f"{image_url(food)}/upload-url", headers=headers, json=UPLOAD),
        await client.put(image_url(food), headers=headers, json={"key": new_key(food)}),
        await client.delete(image_url(food), headers=headers),
    ]

    assert [response.status_code for response in responses] == [403, 403, 403]
    assert storage.put_calls == []
    assert storage.deleted == []


async def test_unknown_food_is_404_on_every_image_endpoint(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    headers = auth_headers(await make_user(role="admin"))
    url = "/v1/foods/missing/image"

    responses = [
        await client.post(f"{url}/upload-url", headers=headers, json=UPLOAD),
        await client.put(url, headers=headers, json={"key": "images/foods/missing/x.jpg"}),
        await client.delete(url, headers=headers),
    ]

    assert [response.status_code for response in responses] == [404, 404, 404]


async def test_upload_url_with_unconfigured_storage_is_503(
    client: AsyncClient,
    app: Any,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    original = app.state.storage
    app.state.storage = UnconfiguredStorage()
    try:
        response = await client.post(
            f"{image_url(food)}/upload-url", headers=auth_headers(actor), json=UPLOAD
        )
    finally:
        app.state.storage = original

    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "storage_unavailable"


@pytest.mark.parametrize(
    ("extension", "content_type"), [("jpg", "image/jpeg"), ("webp", "image/webp")]
)
async def test_confirm_sets_image_key_and_returns_presigned_url(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    extension: str,
    content_type: str,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    key = new_key(food, extension)
    storage.objects[key] = 200_000

    response = await client.put(image_url(food), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 200
    body = response.json()
    assert body["image_url"] == f"https://storage.test/get/{key}?type={content_type}"
    assert "image_key" not in body
    assert "image" not in body
    assert (await refresh(db_session, food)).image_key == key


async def test_confirm_without_uploaded_object_is_422(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()

    response = await client.put(
        image_url(food), headers=auth_headers(actor), json={"key": new_key(food)}
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "image_not_uploaded"
    assert (await refresh(db_session, food)).image_key is None


@pytest.mark.parametrize(
    "key",
    [
        "images/foods/other/" + "a" * 32 + ".jpg",
        "images/products/{id}/" + "a" * 32 + ".jpg",
        "images/{id}/" + "a" * 32 + ".jpg",
        "videos/{id}/" + "a" * 32,
        "images/foods/{id}/" + "a" * 32,
        "images/foods/{id}/" + "a" * 32 + ".gif",
        "images/foods/{id}/" + "A" * 32 + ".jpg",
        "images/foods/{id}/short.jpg",
        "images/foods/{id}/../other/" + "a" * 32 + ".jpg",
        "images/foods/{id}/" + "a" * 32 + ".jpg/extra",
        "https://img.example/a.jpg",
    ],
)
async def test_confirm_rejects_foreign_or_malformed_keys(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    key: str,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    key = key.format(id=food.id)
    storage.objects[key] = 100

    response = await client.put(image_url(food), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "image_key_invalid"
    assert (await refresh(db_session, food)).image_key is None


async def test_confirm_rejects_other_foods_key(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    other = await make_food()
    key = new_key(other)
    storage.objects[key] = 100

    response = await client.put(image_url(food), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 422
    assert (await refresh(db_session, food)).image_key is None
    assert storage.deleted == []


async def test_confirm_oversized_object_is_422_and_removed(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    key = new_key(food)
    storage.objects[key] = MAX_IMAGE_BYTES + 1

    response = await client.put(image_url(food), headers=auth_headers(actor), json={"key": key})

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "image_too_large"
    assert storage.deleted == [key]
    assert (await refresh(db_session, food)).image_key is None


async def test_replacing_image_deletes_old_object(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    old = new_key(food)
    new = new_key(food, "png")
    food.image_key = old
    await db_session.commit()
    storage.objects[new] = 100

    response = await client.put(image_url(food), headers=auth_headers(actor), json={"key": new})

    assert response.status_code == 200
    assert storage.deleted == [old]
    assert (await refresh(db_session, food)).image_key == new


async def test_confirming_same_key_twice_does_not_delete_it(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    key = new_key(food)
    storage.objects[key] = 100

    for _ in range(2):
        response = await client.put(image_url(food), headers=auth_headers(actor), json={"key": key})
        assert response.status_code == 200

    assert storage.deleted == []


@pytest.mark.parametrize("role", ALL_ROLES)
async def test_every_role_sees_image_url_in_list_and_read(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    actor = await make_user(role=role)
    food_id = uuid.uuid4().hex
    with_image_key = f"images/foods/{food_id}/{uuid.uuid4().hex}.jpg"
    with_image = await make_food(id=food_id, name="A", image_key=with_image_key)
    without = await make_food(name="B", image="https://legacy/b.png")

    listing = await client.get("/v1/foods", headers=auth_headers(actor))
    single = await client.get(f"/v1/foods/{with_image.id}", headers=auth_headers(actor))

    urls = {item["id"]: item["image_url"] for item in listing.json()}
    expected = f"https://storage.test/get/{with_image_key}?type=image/jpeg"
    assert urls == {with_image.id: expected, without.id: None}
    assert single.json()["image_url"] == expected
    assert "https://legacy" not in listing.text


async def test_delete_image_clears_key_and_deletes_object(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    key = new_key(food)
    food.image_key = key
    await db_session.commit()

    response = await client.delete(image_url(food), headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == [key]
    assert (await refresh(db_session, food)).image_key is None


async def test_delete_image_when_none_is_noop_204(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()

    response = await client.delete(image_url(food), headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == []


async def test_delete_food_deletes_image_object(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    key = new_key(food)
    food.image_key = key
    await db_session.commit()

    response = await client.delete(f"/v1/foods/{food.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == [key]


async def test_food_update_does_not_touch_image_key(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_food: FoodFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    food = await make_food()
    key = new_key(food)
    food.image_key = key
    await db_session.commit()

    response = await client.put(
        f"/v1/foods/{food.id}", headers=auth_headers(actor), json={"name": "Renamed"}
    )

    assert response.status_code == 200
    assert response.json()["image_url"] is not None
    assert (await refresh(db_session, food)).image_key == key
    assert storage.deleted == []
