import uuid

from fastapi import APIRouter, Response
from sqlalchemy import delete, select

from zalpro_api.api.deps import CurrentUser, SessionDep, StaffUser
from zalpro_api.models import Food
from zalpro_api.schemas.food import FoodIn, FoodOut
from zalpro_api.services import catalog

router = APIRouter(prefix="/foods", tags=["foods"])


@router.get("", response_model=list[FoodOut])
async def list_foods(actor: CurrentUser, session: SessionDep) -> list[Food]:
    return list((await session.scalars(select(Food).order_by(Food.name, Food.id))).all())


@router.get("/{food_id}", response_model=FoodOut)
async def read_food(food_id: str, actor: CurrentUser, session: SessionDep) -> Food:
    return await catalog.get_food_or_404(session, food_id)


@router.post("", response_model=FoodOut, status_code=201)
async def create_food(body: FoodIn, actor: StaffUser, session: SessionDep) -> Food:
    food = Food(id=uuid.uuid4().hex, **body.model_dump())
    session.add(food)
    await session.commit()
    return food


@router.put("/{food_id}", response_model=FoodOut)
async def update_food(food_id: str, body: FoodIn, actor: StaffUser, session: SessionDep) -> Food:
    food = await catalog.get_food_or_404(session, food_id)
    for field, value in body.model_dump().items():
        setattr(food, field, value)
    await session.commit()
    return food


@router.delete("/{food_id}", status_code=204)
async def delete_food(food_id: str, actor: StaffUser, session: SessionDep) -> Response:
    await catalog.get_food_or_404(session, food_id)
    await session.execute(delete(Food).where(Food.id == food_id))
    await session.commit()
    return Response(status_code=204)
