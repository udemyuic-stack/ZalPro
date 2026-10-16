from fastapi import APIRouter, Response

from zalpro_api.api.deps import CurrentUser, OwnerUser, SessionDep
from zalpro_api.models import Membership
from zalpro_api.schemas.membership import MembershipOut
from zalpro_api.services import memberships as memberships_service
from zalpro_api.services import permissions

router = APIRouter(prefix="/memberships", tags=["memberships"])


@router.get("", response_model=list[MembershipOut])
async def list_memberships(actor: CurrentUser, session: SessionDep) -> list[Membership]:
    scope = permissions.membership_scope(actor)
    return await memberships_service.list_memberships(session, scope)


@router.get("/{user_id}", response_model=MembershipOut)
async def read_membership(user_id: str, actor: CurrentUser, session: SessionDep) -> Membership:
    membership = await memberships_service.get_membership_or_404(session, user_id)
    permissions.ensure_can_read_membership(actor, membership)
    return membership


@router.delete("/{user_id}", status_code=204)
async def delete_membership(user_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    await memberships_service.delete_membership(session, user_id)
    return Response(status_code=204)
