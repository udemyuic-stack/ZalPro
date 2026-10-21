from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from zalpro_api.api.deps import CurrentUser, HubDep, OwnerUser, SessionDep, SettingsDep
from zalpro_api.models import Order
from zalpro_api.schemas.order import OrderIn, OrderListQuery, OrderOut, OrderStatusIn
from zalpro_api.services import orders as orders_service
from zalpro_api.services import permissions
from zalpro_api.services.messages import publish_staged
from zalpro_api.services.pagination import PageParams, page_params, set_next_cursor

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderOut, status_code=201)
async def create_order(
    body: OrderIn, actor: CurrentUser, session: SessionDep, hub: HubDep
) -> Order:
    order = await orders_service.create_order(session, actor, body)
    publish_staged(session, hub)
    return order


@router.get("", response_model=list[OrderOut])
async def list_orders(
    query: Annotated[OrderListQuery, Query()],
    actor: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
    response: Response,
    page: Annotated[PageParams | None, Depends(page_params)],
) -> list[Order]:
    permissions.requires_window(actor, query.from_, query.to)
    if page is not None:
        orders, cursor = await orders_service.list_orders_page(
            session,
            permissions.order_scope(actor),
            query.from_,
            query.to,
            query.status,
            settings.gym_timezone,
            page,
        )
        set_next_cursor(response, cursor)
        return orders
    return await orders_service.list_orders(
        session,
        permissions.order_scope(actor),
        query.from_,
        query.to,
        query.status,
        settings.gym_timezone,
    )


@router.get("/{order_id}", response_model=OrderOut)
async def get_order(order_id: str, actor: CurrentUser, session: SessionDep) -> Order:
    order = await orders_service.get_order_or_404(session, order_id)
    permissions.ensure_can_read_order(actor, order)
    return order


@router.patch("/{order_id}/status", response_model=OrderOut)
async def set_order_status(
    order_id: str, body: OrderStatusIn, actor: CurrentUser, session: SessionDep, hub: HubDep
) -> Order:
    order = await orders_service.set_status(session, actor, order_id, body.status)
    publish_staged(session, hub)
    return order


@router.delete("/{order_id}", status_code=204)
async def delete_order(order_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    await orders_service.delete_order(session, order_id)
    return Response(status_code=204)
