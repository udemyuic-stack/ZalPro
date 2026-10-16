from typing import Annotated

from fastapi import APIRouter, Query

from zalpro_api.api.deps import OwnerUser, SessionDep, SettingsDep
from zalpro_api.schemas.finance import MonthlyReportOut, MonthQuery
from zalpro_api.services import finance as finance_service
from zalpro_api.services import subscriptions as subscriptions_service

router = APIRouter(prefix="/finance", tags=["finance"])


@router.get("/monthly", response_model=MonthlyReportOut)
async def monthly_report(
    query: Annotated[MonthQuery, Query()],
    actor: OwnerUser,
    session: SessionDep,
    settings: SettingsDep,
) -> MonthlyReportOut:
    year, month = query.year_and_month
    return await finance_service.monthly_report(
        session, year, month, subscriptions_service.gym_zone(settings), query.gym_id
    )
