import uuid

from fastapi import APIRouter, Response
from sqlalchemy import delete, select

from zalpro_api.api.deps import CurrentUser, SessionDep, StaffUser
from zalpro_api.models import Plan
from zalpro_api.schemas.plan import PlanIn, PlanOut
from zalpro_api.services import catalog

router = APIRouter(prefix="/plans", tags=["plans"])


@router.get("", response_model=list[PlanOut])
async def list_plans(actor: CurrentUser, session: SessionDep) -> list[Plan]:
    return list((await session.scalars(select(Plan).order_by(Plan.title, Plan.id))).all())


@router.get("/{plan_id}", response_model=PlanOut)
async def read_plan(plan_id: str, actor: CurrentUser, session: SessionDep) -> Plan:
    return await catalog.get_plan_or_404(session, plan_id)


@router.post("", response_model=PlanOut, status_code=201)
async def create_plan(body: PlanIn, actor: StaffUser, session: SessionDep) -> Plan:
    plan = Plan(id=uuid.uuid4().hex, **body.model_dump())
    session.add(plan)
    await session.commit()
    return plan


@router.put("/{plan_id}", response_model=PlanOut)
async def update_plan(plan_id: str, body: PlanIn, actor: StaffUser, session: SessionDep) -> Plan:
    plan = await catalog.get_plan_or_404(session, plan_id)
    for field, value in body.model_dump().items():
        setattr(plan, field, value)
    await session.commit()
    return plan


@router.delete("/{plan_id}", status_code=204)
async def delete_plan(plan_id: str, actor: StaffUser, session: SessionDep) -> Response:
    await catalog.get_plan_or_404(session, plan_id)
    await session.execute(delete(Plan).where(Plan.id == plan_id))
    await session.commit()
    return Response(status_code=204)
