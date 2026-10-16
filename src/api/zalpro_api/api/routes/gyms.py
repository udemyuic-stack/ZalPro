import uuid

from fastapi import APIRouter, Response
from sqlalchemy import delete, select

from zalpro_api.api.deps import CurrentUser, OwnerUser, SessionDep
from zalpro_api.models import Gym
from zalpro_api.schemas.gym import GymIn, GymOut
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/gyms", tags=["gyms"])


@router.get("", response_model=list[GymOut])
async def list_gyms(actor: CurrentUser, session: SessionDep) -> list[Gym]:
    return list((await session.scalars(select(Gym).order_by(Gym.name, Gym.id))).all())


@router.get("/{gym_id}", response_model=GymOut)
async def read_gym(gym_id: str, actor: CurrentUser, session: SessionDep) -> Gym:
    return await users_service.get_gym_or_404(session, gym_id)


@router.post("", response_model=GymOut, status_code=201)
async def create_gym(body: GymIn, actor: OwnerUser, session: SessionDep) -> Gym:
    gym = Gym(id=uuid.uuid4().hex, **body.model_dump())
    session.add(gym)
    await session.commit()
    return gym


@router.put("/{gym_id}", response_model=GymOut)
async def update_gym(gym_id: str, body: GymIn, actor: OwnerUser, session: SessionDep) -> Gym:
    gym = await users_service.get_gym_or_404(session, gym_id)
    for field, value in body.model_dump().items():
        setattr(gym, field, value)
    await session.commit()
    return gym


@router.delete("/{gym_id}", status_code=204)
async def delete_gym(gym_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    await users_service.get_gym_or_404(session, gym_id)
    await session.execute(delete(Gym).where(Gym.id == gym_id))
    await session.commit()
    return Response(status_code=204)
