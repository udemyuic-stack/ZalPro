from typing import Annotated

from fastapi import APIRouter, Query

from zalpro_api.api.deps import CurrentUser, SessionDep
from zalpro_api.models import Weight
from zalpro_api.schemas.weight import MAX_WEIGHTS_LIMIT, WeightIn, WeightOut
from zalpro_api.services import permissions
from zalpro_api.services import users as users_service
from zalpro_api.services import weights as weights_service

router = APIRouter(prefix="/users", tags=["weights"])


@router.get("/{user_id}/weights", response_model=list[WeightOut])
async def list_weights(
    user_id: str,
    actor: CurrentUser,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=MAX_WEIGHTS_LIMIT)] = MAX_WEIGHTS_LIMIT,
) -> list[Weight]:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return await weights_service.list_weights(session, user_id, limit)


@router.post("/{user_id}/weights", response_model=WeightOut, status_code=201)
async def add_weight(
    user_id: str, body: WeightIn, actor: CurrentUser, session: SessionDep
) -> Weight:
    permissions.ensure_self(actor, user_id)
    return await weights_service.record_weight(session, user_id, body.weight)
