from typing import Annotated

from fastapi import APIRouter, Query

from zalpro_api.api.deps import OwnerUser, SessionDep, SettingsDep, StaffUser
from zalpro_api.schemas.analytics import (
    AnalyticsRange,
    ChurnOut,
    RetentionOut,
    ShopAnalyticsOut,
    TrainersOut,
)
from zalpro_api.services import analytics as analytics_service
from zalpro_api.services import permissions

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/shop", response_model=ShopAnalyticsOut)
async def shop_analytics(
    query: Annotated[AnalyticsRange, Query()],
    actor: StaffUser,
    session: SessionDep,
    settings: SettingsDep,
) -> ShopAnalyticsOut:
    return await analytics_service.shop_analytics(
        session, permissions.order_scope(actor), query.from_, query.to, settings.gym_timezone
    )


@router.get("/churn", response_model=ChurnOut)
async def churn(actor: StaffUser, session: SessionDep, settings: SettingsDep) -> ChurnOut:
    return await analytics_service.churn_list(session, actor, settings.gym_timezone)


@router.get("/retention", response_model=RetentionOut)
async def retention(
    query: Annotated[AnalyticsRange, Query()],
    actor: OwnerUser,
    session: SessionDep,
    settings: SettingsDep,
) -> RetentionOut:
    return await analytics_service.retention(session, query.from_, query.to, settings.gym_timezone)


@router.get("/trainers", response_model=TrainersOut)
async def trainers(
    query: Annotated[AnalyticsRange, Query()],
    actor: OwnerUser,
    session: SessionDep,
    settings: SettingsDep,
) -> TrainersOut:
    return await analytics_service.trainer_effectiveness(
        session, query.from_, query.to, settings.gym_timezone
    )
