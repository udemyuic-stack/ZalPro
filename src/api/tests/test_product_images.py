import uuid
from collections.abc import Awaitable, Callable
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import FakeStorage
from zalpro_api.models import Product, User
from zalpro_api.models.photo import MAX_IMAGE_BYTES
from zalpro_api.models.product import MAX_PRODUCT_IMAGES
from zalpro_api.services.storage import UnconfiguredStorage

UserFactory = Callable[..., Awaitable[User]]
ProductFactory = Callable[..., Awaitable[Product]]
HeadersFactory = Callable[[User], dict[str, str]]

WRITE_ROLES = ["barmen", "admin", "owner"]
ALL_ROLES = ["user", "barmen", "admin", "owner"]
UPLOAD = {"size": 200_000, "content_type": "image/png"}


def images_url(product: Product) -> str:
    return f"/v1/products/{product.id}/images"


def new_key(product_id: str, extension: str = "jpg") -> str:
    return f"images/products/{product_id}/{uuid.uuid4().hex}.{extension}"


def get_url(key: str) -> str:
    content_type = {"jpg": "image/jpeg", "png": "image/png", "webp": "image/webp"}
    return f"https://storage.test/get/{key}?type={content_type[key.rsplit('.', 1)[-1]]}"


async def refresh(db_session: AsyncSession, product: Product) -> Product:
    await db_session.refresh(product)
    return product


@pytest.mark.parametrize("role", WRITE_ROLES)
async def test_shop_writer_gets_upload_url_for_product_prefix(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    role: str,
) -> None:
    actor = await make_user(role=role)
    product = await make_product()

    response = await client.post(
        f"{images_url(product)}/upload-url", headers=auth_headers(actor), json=UPLOAD
    )

    assert response.status_code == 201
    body = response.json()
    assert body["key"].startswith(f"images/products/{product.id}/")
    assert body["key"].endswith(".png")
    assert body["upload_url"].startswith("https://storage.test/put/")
    assert body["expires_in"] == 600
    assert storage.put_calls == [(body["key"], 200_000)]
    assert (await refresh(db_session, product)).image_keys == []


@pytest.mark.parametrize(
    "payload",
    [
        {"size": 0, "content_type": "image/png"},
        {"size": MAX_IMAGE_BYTES + 1, "content_type": "image/png"},
        {"size": 10, "content_type": "image/svg+xml"},
        {"size": 10},
    ],
)
async def test_upload_url_rejects_bad_payload(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    payload: dict[str, Any],
) -> None:
    actor = await make_user(role="admin")
    product = await make_product()

    response = await client.post(
        f"{images_url(product)}/upload-url", headers=auth_headers(actor), json=payload
    )

    assert response.status_code == 422
    assert storage.put_calls == []


async def test_trainee_cannot_manage_product_images(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="user")
    old = new_key("p1")
    product = await make_product(id="p1", image_keys=[old])
    headers = auth_headers(actor)

    responses = [
        await client.post(f"{images_url(product)}/upload-url", headers=headers, json=UPLOAD),
        await client.put(images_url(product), headers=headers, json={"keys": []}),
        await client.delete(images_url(product), headers=headers),
    ]

    assert [response.status_code for response in responses] == [403, 403, 403]
    assert storage.put_calls == []
    assert storage.deleted == []
    assert (await refresh(db_session, product)).image_keys == [old]


async def test_unknown_product_is_404_on_every_image_endpoint(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    auth_headers: HeadersFactory,
) -> None:
    headers = auth_headers(await make_user(role="admin"))
    url = "/v1/products/missing/images"

    responses = [
        await client.post(f"{url}/upload-url", headers=headers, json=UPLOAD),
        await client.put(url, headers=headers, json={"keys": []}),
        await client.delete(url, headers=headers),
    ]

    assert [response.status_code for response in responses] == [404, 404, 404]


async def test_upload_url_with_unconfigured_storage_is_503(
    client: AsyncClient,
    app: Any,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="barmen")
    product = await make_product()
    original = app.state.storage
    app.state.storage = UnconfiguredStorage()
    try:
        response = await client.post(
            f"{images_url(product)}/upload-url", headers=auth_headers(actor), json=UPLOAD
        )
    finally:
        app.state.storage = original

    assert response.status_code == 503
    assert response.json()["detail"]["code"] == "storage_unavailable"


async def test_put_sets_keys_in_order_and_returns_urls(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="barmen")
    product = await make_product()
    keys = [new_key(product.id, "webp"), new_key(product.id, "jpg")]
    for key in keys:
        storage.objects[key] = 100

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": keys}
    )

    assert response.status_code == 200
    body = response.json()
    assert body["image_urls"] == [get_url(key) for key in keys]
    assert body["image_keys"] == keys
    assert body["cost_price"] is not None
    assert (await refresh(db_session, product)).image_keys == keys
    assert storage.deleted == []


async def test_put_replaces_list_and_deletes_removed_keys(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    kept = new_key("p1")
    removed = new_key("p1")
    added = new_key("p1", "png")
    product = await make_product(id="p1", image_keys=[removed, kept])
    storage.objects[added] = 100

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": [kept, added]}
    )

    assert response.status_code == 200
    assert storage.deleted == [removed]
    assert (await refresh(db_session, product)).image_keys == [kept, added]


async def test_put_empty_list_deletes_all(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    keys = [new_key("p1"), new_key("p1")]
    product = await make_product(id="p1", image_keys=keys)

    response = await client.put(images_url(product), headers=auth_headers(actor), json={"keys": []})

    assert response.status_code == 200
    assert response.json()["image_urls"] == []
    assert storage.deleted == keys
    assert (await refresh(db_session, product)).image_keys == []


@pytest.mark.parametrize(
    "key",
    [
        "images/products/other/" + "a" * 32 + ".jpg",
        "images/foods/{id}/" + "a" * 32 + ".jpg",
        "images/{id}/" + "a" * 32 + ".jpg",
        "images/products/{id}/" + "a" * 32,
        "images/products/{id}/" + "a" * 32 + ".bmp",
        "images/products/{id}/../x/" + "a" * 32 + ".jpg",
        "https://img.example/a.jpg",
    ],
)
async def test_put_rejects_foreign_or_malformed_keys(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
    key: str,
) -> None:
    actor = await make_user(role="admin")
    old = new_key("p1")
    product = await make_product(id="p1", image_keys=[old])
    key = key.format(id=product.id)
    storage.objects[key] = 100

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": [key]}
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "image_key_invalid"
    assert (await refresh(db_session, product)).image_keys == [old]
    assert storage.deleted == []


async def test_put_rejects_other_products_key(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    product = await make_product()
    other = await make_product()
    key = new_key(other.id)
    storage.objects[key] = 100

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": [key]}
    )

    assert response.status_code == 422
    assert (await refresh(db_session, product)).image_keys == []


async def test_put_rejects_duplicates(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    product = await make_product()
    key = new_key(product.id)
    storage.objects[key] = 100

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": [key, key]}
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "image_keys_duplicate"


async def test_put_rejects_more_than_max_images(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    product = await make_product()
    keys = [new_key(product.id) for _ in range(MAX_PRODUCT_IMAGES + 1)]
    for key in keys:
        storage.objects[key] = 100

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": keys}
    )

    assert response.status_code == 422


async def test_put_accepts_max_images(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    product = await make_product()
    keys = [new_key(product.id) for _ in range(MAX_PRODUCT_IMAGES)]
    for key in keys:
        storage.objects[key] = 100

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": keys}
    )

    assert response.status_code == 200
    assert len(response.json()["image_urls"]) == MAX_PRODUCT_IMAGES


async def test_put_new_key_not_uploaded_is_422(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    product = await make_product()

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": [new_key(product.id)]}
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "image_not_uploaded"
    assert (await refresh(db_session, product)).image_keys == []


async def test_put_oversized_object_is_422_and_removed(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    old = new_key("p1")
    product = await make_product(id="p1", image_keys=[old])
    key = new_key(product.id)
    storage.objects[key] = MAX_IMAGE_BYTES + 1

    response = await client.put(
        images_url(product), headers=auth_headers(actor), json={"keys": [key]}
    )

    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "image_too_large"
    assert storage.deleted == [key]
    assert (await refresh(db_session, product)).image_keys == [old]


@pytest.mark.parametrize("role", ALL_ROLES)
async def test_every_role_sees_image_urls(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    role: str,
) -> None:
    actor = await make_user(role=role)
    keys = [new_key("p1"), new_key("p1", "webp")]
    product = await make_product(id="p1", name="A", image_keys=keys)
    without = await make_product(name="B")

    listing = await client.get("/v1/products", headers=auth_headers(actor))
    single = await client.get(f"/v1/products/{product.id}", headers=auth_headers(actor))

    urls = {item["id"]: item["image_urls"] for item in listing.json()}
    assert urls == {product.id: [get_url(key) for key in keys], without.id: []}
    assert single.json()["image_urls"] == [get_url(key) for key in keys]


async def test_delete_images_clears_list_and_deletes_objects(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="barmen")
    keys = [new_key("p1"), new_key("p1")]
    product = await make_product(id="p1", image_keys=keys)

    response = await client.delete(images_url(product), headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == keys
    assert (await refresh(db_session, product)).image_keys == []


async def test_delete_images_when_none_is_noop_204(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    product = await make_product()

    response = await client.delete(images_url(product), headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == []


async def test_delete_product_deletes_image_objects(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
) -> None:
    actor = await make_user(role="admin")
    keys = [new_key("p1"), new_key("p1")]
    product = await make_product(id="p1", image_keys=keys)

    response = await client.delete(f"/v1/products/{product.id}", headers=auth_headers(actor))

    assert response.status_code == 204
    assert storage.deleted == keys


async def test_product_patch_does_not_touch_image_keys(
    client: AsyncClient,
    storage: FakeStorage,
    make_user: UserFactory,
    make_product: ProductFactory,
    auth_headers: HeadersFactory,
    db_session: AsyncSession,
) -> None:
    actor = await make_user(role="admin")
    keys = [new_key("p1")]
    product = await make_product(id="p1", image_keys=keys)

    response = await client.patch(
        f"/v1/products/{product.id}", headers=auth_headers(actor), json={"name": "Yangi"}
    )

    assert response.status_code == 200
    assert response.json()["image_urls"] == [get_url(keys[0])]
    assert (await refresh(db_session, product)).image_keys == keys
    assert storage.deleted == []
