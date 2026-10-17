import re

from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import ApiError
from zalpro_api.models import Food, Product
from zalpro_api.models.photo import MAX_IMAGE_BYTES
from zalpro_api.schemas.food import FoodOut
from zalpro_api.schemas.image_upload import ImageUploadOut
from zalpro_api.services.storage import Storage, build_key

IMAGE_EXTENSIONS = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}
EXTENSION_TYPES = {extension: kind for kind, extension in IMAGE_EXTENSIONS.items()}
KEY_NAME = r"[0-9a-f]{32}\.(?:" + "|".join(EXTENSION_TYPES) + r")"


def food_owner(food_id: str) -> str:
    return f"foods/{food_id}"


def product_owner(product_id: str) -> str:
    return f"products/{product_id}"


def owner_prefix(owner: str) -> str:
    return f"images/{owner}/"


async def create_upload(
    storage: Storage, owner: str, size: int, content_type: str, expires: int
) -> ImageUploadOut:
    key = f"{build_key('image', owner)}.{IMAGE_EXTENSIONS[content_type]}"
    upload_url = await storage.presign_put(key, size, expires)
    return ImageUploadOut(key=key, upload_url=upload_url, expires_in=expires)


async def presign(storage: Storage, key: str, expires: int) -> str:
    content_type = EXTENSION_TYPES.get(key.rsplit(".", 1)[-1])
    return await storage.presign_get(key, expires, content_type)


def ensure_owned(owner: str, key: str) -> None:
    if re.fullmatch(re.escape(owner_prefix(owner)) + KEY_NAME, key) is None:
        raise ApiError(422, "image_key_invalid", "Rasm kaliti bu yozuvga tegishli emas")


async def ensure_uploaded(storage: Storage, key: str) -> None:
    size = await storage.head(key)
    if size is None:
        raise ApiError(422, "image_not_uploaded", "Rasm yuklanmagan")
    if size > MAX_IMAGE_BYTES:
        await storage.delete(key)
        raise ApiError(422, "image_too_large", "Rasm hajmi chegaradan katta")


async def food_out(storage: Storage, food: Food, expires: int) -> FoodOut:
    out = FoodOut.model_validate(food)
    if food.image_key is None:
        return out
    return out.model_copy(update={"image_url": await presign(storage, food.image_key, expires)})


async def confirm_food_image(session: AsyncSession, storage: Storage, food: Food, key: str) -> None:
    ensure_owned(food_owner(food.id), key)
    await ensure_uploaded(storage, key)
    previous = food.image_key
    food.image_key = key
    await session.commit()
    if previous is not None and previous != key:
        await storage.delete(previous)


async def remove_food_image(session: AsyncSession, storage: Storage, food: Food) -> None:
    key = food.image_key
    if key is None:
        return
    food.image_key = None
    await session.commit()
    await storage.delete(key)


async def product_urls(storage: Storage, product: Product, expires: int) -> list[str]:
    return [await presign(storage, key, expires) for key in product.image_keys]


async def replace_product_images(
    session: AsyncSession, storage: Storage, product: Product, keys: list[str]
) -> None:
    kept = set(keys)
    if len(kept) != len(keys):
        raise ApiError(422, "image_keys_duplicate", "Rasm kalitlari takrorlanmasligi kerak")
    owner = product_owner(product.id)
    for key in keys:
        ensure_owned(owner, key)
    current = set(product.image_keys)
    for key in keys:
        if key not in current:
            await ensure_uploaded(storage, key)
    removed = [key for key in product.image_keys if key not in kept]
    product.image_keys = list(keys)
    await session.commit()
    for key in removed:
        await storage.delete(key)


async def remove_product_images(session: AsyncSession, storage: Storage, product: Product) -> None:
    keys = list(product.image_keys)
    if not keys:
        return
    product.image_keys = []
    await session.commit()
    for key in keys:
        await storage.delete(key)
