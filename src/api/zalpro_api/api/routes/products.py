import uuid

from fastapi import APIRouter, Response
from sqlalchemy import delete

from zalpro_api.api.deps import CurrentUser, SessionDep, SettingsDep, ShopWriter, StorageDep
from zalpro_api.models import Product
from zalpro_api.schemas.image_upload import ImagesConfirmIn, ImageUploadIn, ImageUploadOut
from zalpro_api.schemas.product import ProductIn, ProductOut, ProductPatch
from zalpro_api.services import images, products

router = APIRouter(prefix="/products", tags=["products"])


@router.get("", response_model=list[ProductOut])
async def list_products(
    actor: CurrentUser, session: SessionDep, storage: StorageDep, settings: SettingsDep
) -> list[ProductOut]:
    return [
        await products.to_out(storage, item, actor, settings.photo_url_seconds)
        for item in await products.list_products(session)
    ]


@router.get("/{product_id}", response_model=ProductOut)
async def read_product(
    product_id: str,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> ProductOut:
    product = await products.get_product_or_404(session, product_id)
    return await products.to_out(storage, product, actor, settings.photo_url_seconds)


@router.post("", response_model=ProductOut, status_code=201)
async def create_product(
    body: ProductIn,
    actor: ShopWriter,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> ProductOut:
    product = Product(id=uuid.uuid4().hex)
    products.apply(product, body)
    session.add(product)
    await session.commit()
    return await products.to_out(storage, product, actor, settings.photo_url_seconds)


@router.patch("/{product_id}", response_model=ProductOut)
async def update_product(
    product_id: str,
    body: ProductPatch,
    actor: ShopWriter,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> ProductOut:
    product = await products.get_product_for_update_or_404(session, product_id)
    products.apply(product, products.merge_patch(product, body))
    await session.commit()
    return await products.to_out(storage, product, actor, settings.photo_url_seconds)


@router.delete("/{product_id}", status_code=204)
async def delete_product(
    product_id: str, actor: ShopWriter, session: SessionDep, storage: StorageDep
) -> Response:
    product = await products.get_product_or_404(session, product_id)
    image_keys = list(product.image_keys)
    await session.execute(delete(Product).where(Product.id == product.id))
    await session.commit()
    for key in image_keys:
        await storage.delete(key)
    return Response(status_code=204)


@router.post("/{product_id}/images/upload-url", response_model=ImageUploadOut, status_code=201)
async def create_image_upload_url(
    product_id: str,
    body: ImageUploadIn,
    actor: ShopWriter,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> ImageUploadOut:
    product = await products.get_product_or_404(session, product_id)
    return await images.create_upload(
        storage,
        images.product_owner(product.id),
        body.size,
        body.content_type,
        settings.photo_url_seconds,
    )


@router.put("/{product_id}/images", response_model=ProductOut)
async def replace_images(
    product_id: str,
    body: ImagesConfirmIn,
    actor: ShopWriter,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> ProductOut:
    product = await products.get_product_for_update_or_404(session, product_id)
    await images.replace_product_images(session, storage, product, body.keys)
    return await products.to_out(storage, product, actor, settings.photo_url_seconds)


@router.delete("/{product_id}/images", status_code=204)
async def delete_images(
    product_id: str, actor: ShopWriter, session: SessionDep, storage: StorageDep
) -> Response:
    product = await products.get_product_for_update_or_404(session, product_id)
    await images.remove_product_images(session, storage, product)
    return Response(status_code=204)
