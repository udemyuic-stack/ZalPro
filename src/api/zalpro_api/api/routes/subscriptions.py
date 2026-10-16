from typing import Annotated

from fastapi import APIRouter, Query

from zalpro_api.api.deps import CurrentUser, OwnerUser, SessionDep, SettingsDep, StaffUser
from zalpro_api.schemas.subscription import PaidWindow, SubscriptionIn, SubscriptionOut
from zalpro_api.services import permissions
from zalpro_api.services import subscriptions as subscriptions_service
from zalpro_api.services import users as users_service

router = APIRouter(tags=["subscriptions"])


@router.get("/users/{user_id}/subscriptions", response_model=list[SubscriptionOut])
async def list_user_subscriptions(
    user_id: str, actor: CurrentUser, session: SessionDep, settings: SettingsDep
) -> list[SubscriptionOut]:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_read_user(actor, target)
    return await subscriptions_service.list_user_subscriptions(
        session, user_id, subscriptions_service.gym_zone(settings)
    )


@router.post("/users/{user_id}/subscriptions", response_model=SubscriptionOut, status_code=201)
async def add_subscription(
    user_id: str, body: SubscriptionIn, actor: StaffUser, session: SessionDep, settings: SettingsDep
) -> SubscriptionOut:
    target = await users_service.get_user_or_404(session, user_id)
    permissions.ensure_can_manage(actor, target)
    return await subscriptions_service.add_subscription(
        session, target, body, subscriptions_service.gym_zone(settings)
    )


@router.get("/subscriptions", response_model=list[SubscriptionOut])
async def list_paid_subscriptions(
    window: Annotated[PaidWindow, Query()],
    actor: OwnerUser,
    session: SessionDep,
    settings: SettingsDep,
) -> list[SubscriptionOut]:
    permissions.requires_window(actor, window.from_, window.to)
    return await subscriptions_service.list_paid_between(
        session, window.from_, window.to, subscriptions_service.gym_zone(settings)
    )
