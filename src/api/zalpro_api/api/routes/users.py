from typing import Annotated

from fastapi import APIRouter, Query, Response

from zalpro_api.api.deps import CurrentUser, OwnerUser, SessionDep
from zalpro_api.core.security import hash_password
from zalpro_api.models import User
from zalpro_api.schemas.leaderboard import LeaderboardVisibility
from zalpro_api.schemas.user import (
    GymAssignment,
    PasswordReset,
    Role,
    RoleUpdate,
    TrainerAssignment,
    UserCreate,
    UserOut,
    UserPatch,
)
from zalpro_api.services import permissions
from zalpro_api.services import users as users_service
from zalpro_api.services.legacy_password import clear_legacy
from zalpro_api.services.refresh_tokens import revoke_all_refresh_tokens

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
async def read_me(actor: CurrentUser) -> User:
    return actor


@router.put("/me/leaderboard", response_model=UserOut)
async def set_leaderboard_visibility(
    body: LeaderboardVisibility, actor: CurrentUser, session: SessionDep
) -> User:
    actor.show_in_leaderboard = body.visible
    await session.commit()
    return actor


@router.get("", response_model=list[UserOut])
async def list_users(
    actor: CurrentUser,
    session: SessionDep,
    role: Annotated[list[Role] | None, Query()] = None,
    trainer_id: Annotated[str | None, Query(min_length=1, max_length=64)] = None,
    gym_id: Annotated[str | None, Query(min_length=1, max_length=64)] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[User]:
    return await users_service.list_users(
        session,
        actor,
        roles=role or [],
        trainer_id=trainer_id,
        gym_id=gym_id,
        limit=limit,
        offset=offset,
    )


@router.post("", response_model=UserOut, status_code=201)
async def create_staff_user(body: UserCreate, actor: OwnerUser, session: SessionDep) -> User:
    password_hash = await hash_password(body.password)
    return await users_service.create_user(
        session,
        name=body.name,
        phone=body.phone,
        password_hash=password_hash,
        role=body.role,
        gym_id=body.gym_id,
    )


@router.get("/{user_id}", response_model=UserOut)
async def read_user(user_id: str, actor: CurrentUser, session: SessionDep) -> User:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return target


@router.patch("/{user_id}", response_model=UserOut)
async def patch_user(
    user_id: str, body: UserPatch, actor: CurrentUser, session: SessionDep
) -> User:
    target = await users_service.get_user_or_404(session, user_id)
    changes = body.model_dump(exclude_unset=True)
    permissions.check_user_patch(actor, target, changes)
    await users_service.apply_user_changes(session, target, changes)
    await session.commit()
    return target


@router.put("/{user_id}/role", response_model=UserOut)
async def set_role(user_id: str, body: RoleUpdate, actor: OwnerUser, session: SessionDep) -> User:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_set_role(actor, target, body.role)
    await users_service.apply_role(session, target, body.role)
    await session.commit()
    return target


@router.put("/{user_id}/gym", response_model=UserOut)
async def set_gym(user_id: str, body: GymAssignment, actor: OwnerUser, session: SessionDep) -> User:
    target = await users_service.get_user_or_404(session, user_id)
    await users_service.apply_gym(session, target, body.gym_id)
    await session.commit()
    return target


@router.put("/{user_id}/trainer", response_model=UserOut)
async def set_trainer(
    user_id: str, body: TrainerAssignment, actor: CurrentUser, session: SessionDep
) -> User:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_assign_trainer(actor, target)
    trainer = None
    if body.trainer_id is not None:
        trainer = await users_service.get_trainer_or_404(session, body.trainer_id)
    permissions.ensure_trainer_choice(actor, trainer)
    target.trainer_id = body.trainer_id
    await session.commit()
    return target


@router.delete("/{user_id}", status_code=204)
async def delete_user(user_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_delete_user(actor, target)
    await users_service.delete_user(session, target.id)
    await session.commit()
    return Response(status_code=204)


@router.post("/{user_id}/reset-password", status_code=204)
async def reset_password(
    user_id: str, body: PasswordReset, actor: OwnerUser, session: SessionDep
) -> Response:
    target = await users_service.get_user_or_404(session, user_id)
    target.password_hash = await hash_password(body.new_password)
    clear_legacy(target)
    await revoke_all_refresh_tokens(session, target.id)
    await session.commit()
    return Response(status_code=204)
