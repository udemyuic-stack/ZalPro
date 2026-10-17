import uuid

from fastapi import APIRouter, Response
from sqlalchemy import delete, select

from zalpro_api.api.deps import CurrentUser, SessionDep, SettingsDep, StaffUser, StorageDep
from zalpro_api.models import Food
from zalpro_api.schemas.food import FoodIn, FoodOut
from zalpro_api.schemas.image_upload import ImageConfirmIn, ImageUploadIn, ImageUploadOut
from zalpro_api.services import catalog, images

router = APIRouter(prefix="/foods", tags=["foods"])


@router.get("", response_model=list[FoodOut])
async def list_foods(
    actor: CurrentUser, session: SessionDep, storage: StorageDep, settings: SettingsDep
) -> list[FoodOut]:
    foods = await session.scalars(select(Food).order_by(Food.name, Food.id))
    return [
        await images.food_out(storage, food, settings.photo_url_seconds) for food in foods.all()
    ]


@router.get("/{food_id}", response_model=FoodOut)
async def read_food(
    food_id: str,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> FoodOut:
    food = await catalog.get_food_or_404(session, food_id)
    return await images.food_out(storage, food, settings.photo_url_seconds)


@router.post("", response_model=FoodOut, status_code=201)
async def create_food(
    body: FoodIn, actor: StaffUser, session: SessionDep, storage: StorageDep, settings: SettingsDep
) -> FoodOut:
    food = Food(id=uuid.uuid4().hex, **body.model_dump())
    session.add(food)
    await session.commit()
    return await images.food_out(storage, food, settings.photo_url_seconds)


@router.put("/{food_id}", response_model=FoodOut)
async def update_food(
    food_id: str,
    body: FoodIn,
    actor: StaffUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> FoodOut:
    food = await catalog.get_food_or_404(session, food_id)
    for field, value in body.model_dump().items():
        setattr(food, field, value)
    await session.commit()
    return await images.food_out(storage, food, settings.photo_url_seconds)


@router.delete("/{food_id}", status_code=204)
async def delete_food(
    food_id: str, actor: StaffUser, session: SessionDep, storage: StorageDep
) -> Response:
    food = await catalog.get_food_or_404(session, food_id)
    image_key = food.image_key
    await session.execute(delete(Food).where(Food.id == food_id))
    await session.commit()
    if image_key is not None:
        await storage.delete(image_key)
    return Response(status_code=204)


@router.post("/{food_id}/image/upload-url", response_model=ImageUploadOut, status_code=201)
async def create_image_upload_url(
    food_id: str,
    body: ImageUploadIn,
    actor: StaffUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> ImageUploadOut:
    food = await catalog.get_food_or_404(session, food_id)
    return await images.create_upload(
        storage,
        images.food_owner(food.id),
        body.size,
        body.content_type,
        settings.photo_url_seconds,
    )


@router.put("/{food_id}/image", response_model=FoodOut)
async def confirm_image(
    food_id: str,
    body: ImageConfirmIn,
    actor: StaffUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> FoodOut:
    food = await catalog.get_food_or_404(session, food_id)
    await images.confirm_food_image(session, storage, food, body.key)
    return await images.food_out(storage, food, settings.photo_url_seconds)


@router.delete("/{food_id}/image", status_code=204)
async def delete_image(
    food_id: str, actor: StaffUser, session: SessionDep, storage: StorageDep
) -> Response:
    food = await catalog.get_food_or_404(session, food_id)
    await images.remove_food_image(session, storage, food)
    return Response(status_code=204)
