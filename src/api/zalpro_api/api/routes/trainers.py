from fastapi import APIRouter, Response
from sqlalchemy import delete, select

from zalpro_api.api.deps import CurrentUser, OwnerUser, SessionDep
from zalpro_api.core.errors import conflict
from zalpro_api.models import Trainer
from zalpro_api.schemas.trainer import TrainerCreate, TrainerOut, TrainerUpdate
from zalpro_api.services import permissions
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/trainers", tags=["trainers"])

TRAINER_SELF_FIELDS = ("name", "bio", "accepting")


@router.get("", response_model=list[TrainerOut])
async def list_trainers(actor: CurrentUser, session: SessionDep) -> list[Trainer]:
    return list((await session.scalars(select(Trainer).order_by(Trainer.name, Trainer.id))).all())


@router.post("/{trainer_id}", response_model=TrainerOut, status_code=201)
async def create_trainer(
    trainer_id: str, body: TrainerCreate, actor: CurrentUser, session: SessionDep
) -> Trainer:
    permissions.ensure_can_create_trainer(actor, trainer_id)
    user = await users_service.get_user_or_404(session, trainer_id)
    if user.role != "admin":
        raise conflict("not_a_trainer", "Foydalanuvchi trener emas")
    if await session.get(Trainer, trainer_id) is not None:
        raise conflict("trainer_exists", "Trener yozuvi allaqachon mavjud")
    trainer = Trainer(
        id=user.id,
        name=body.name or user.name or user.phone[:60],
        bio=body.bio,
        accepting=body.accepting,
        gym_id=user.gym_id,
    )
    session.add(trainer)
    await session.commit()
    return trainer


@router.put("/{trainer_id}", response_model=TrainerOut)
async def update_trainer(
    trainer_id: str, body: TrainerUpdate, actor: CurrentUser, session: SessionDep
) -> Trainer:
    changes = body.model_dump(exclude_unset=True)
    is_self = permissions.ensure_can_update_trainer(actor, trainer_id, changes)
    trainer = await users_service.get_trainer_or_404(session, trainer_id)
    if is_self:
        for field in TRAINER_SELF_FIELDS:
            if field in changes:
                setattr(trainer, field, changes[field])
    elif "gym_id" in changes:
        user = await users_service.get_user_or_404(session, trainer_id)
        await users_service.apply_gym(session, user, changes["gym_id"])
        trainer.gym_id = changes["gym_id"]
    await session.commit()
    return trainer


@router.delete("/{trainer_id}", status_code=204)
async def delete_trainer(trainer_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    await users_service.get_trainer_or_404(session, trainer_id)
    await session.execute(delete(Trainer).where(Trainer.id == trainer_id))
    await session.commit()
    return Response(status_code=204)
