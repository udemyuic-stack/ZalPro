from typing import Any

from fastapi.exceptions import RequestValidationError
from pydantic import ValidationError
from sqlalchemy import case, select
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.errors import not_found
from zalpro_api.models import Product, User
from zalpro_api.models.product import PRODUCT_CATEGORIES
from zalpro_api.schemas.product import ProductIn, ProductOut, ProductPatch
from zalpro_api.services import images, permissions
from zalpro_api.services.storage import Storage

INPUT_FIELDS = tuple(ProductIn.model_fields)


async def get_product_or_404(session: AsyncSession, product_id: str) -> Product:
    product = await session.get(Product, product_id)
    if product is None:
        raise not_found("Tovar topilmadi")
    return product


async def get_product_for_update_or_404(session: AsyncSession, product_id: str) -> Product:
    product = await session.scalar(
        select(Product)
        .where(Product.id == product_id)
        .with_for_update()
        .execution_options(populate_existing=True)
    )
    if product is None:
        raise not_found("Tovar topilmadi")
    return product


async def list_products(session: AsyncSession) -> list[Product]:
    order = case(
        {name: index for index, name in enumerate(PRODUCT_CATEGORIES)}, value=Product.category
    )
    result = await session.scalars(select(Product).order_by(order, Product.name, Product.id))
    return list(result.all())


async def to_out(storage: Storage, product: Product, actor: User, expires: int) -> ProductOut:
    out = ProductOut.model_validate(product)
    update: dict[str, Any] = {"image_urls": await images.product_urls(storage, product, expires)}
    if not permissions.can_see_cost_price(actor):
        update["cost_price"] = None
    return out.model_copy(update=update)


def merge_patch(product: Product, patch: ProductPatch) -> ProductIn:
    data: dict[str, Any] = {field: getattr(product, field) for field in INPUT_FIELDS}
    changes = patch.model_dump(exclude_unset=True)
    data.update(changes)
    if data["sizes"] and "stock" not in changes:
        data.pop("stock")
    try:
        return ProductIn.model_validate(data)
    except ValidationError as error:
        raise RequestValidationError(error.errors()) from error


def apply(product: Product, values: ProductIn) -> None:
    for field, value in values.model_dump().items():
        setattr(product, field, value)
