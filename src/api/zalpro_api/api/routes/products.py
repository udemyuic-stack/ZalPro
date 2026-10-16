import uuid

from fastapi import APIRouter, Response
from sqlalchemy import delete

from zalpro_api.api.deps import CurrentUser, SessionDep, ShopWriter
from zalpro_api.models import Product
from zalpro_api.schemas.product import ProductIn, ProductOut, ProductPatch
from zalpro_api.services import products

router = APIRouter(prefix="/products", tags=["products"])


@router.get("", response_model=list[ProductOut])
async def list_products(actor: CurrentUser, session: SessionDep) -> list[ProductOut]:
    return [products.to_out(item, actor) for item in await products.list_products(session)]


@router.get("/{product_id}", response_model=ProductOut)
async def read_product(product_id: str, actor: CurrentUser, session: SessionDep) -> ProductOut:
    return products.to_out(await products.get_product_or_404(session, product_id), actor)


@router.post("", response_model=ProductOut, status_code=201)
async def create_product(body: ProductIn, actor: ShopWriter, session: SessionDep) -> ProductOut:
    product = Product(id=uuid.uuid4().hex)
    products.apply(product, body)
    session.add(product)
    await session.commit()
    return products.to_out(product, actor)


@router.patch("/{product_id}", response_model=ProductOut)
async def update_product(
    product_id: str, body: ProductPatch, actor: ShopWriter, session: SessionDep
) -> ProductOut:
    product = await products.get_product_for_update_or_404(session, product_id)
    products.apply(product, products.merge_patch(product, body))
    await session.commit()
    return products.to_out(product, actor)


@router.delete("/{product_id}", status_code=204)
async def delete_product(product_id: str, actor: ShopWriter, session: SessionDep) -> Response:
    product = await products.get_product_or_404(session, product_id)
    await session.execute(delete(Product).where(Product.id == product.id))
    await session.commit()
    return Response(status_code=204)
