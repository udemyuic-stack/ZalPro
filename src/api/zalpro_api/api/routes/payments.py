from typing import Annotated

from fastapi import APIRouter, Header, Request

from zalpro_api.api.deps import CurrentUser, SessionDep, SettingsDep
from zalpro_api.schemas.payment import PaymentOptionsOut, PaymentOrderIn, PaymentOrderOut
from zalpro_api.services import click as click_service
from zalpro_api.services import payme as payme_service
from zalpro_api.services import payments as payments_service

router = APIRouter(prefix="/payments", tags=["payments"])


@router.get("/options", response_model=PaymentOptionsOut)
async def read_options(actor: CurrentUser, settings: SettingsDep) -> PaymentOptionsOut:
    return payments_service.options(settings)


@router.post("/orders", response_model=PaymentOrderOut, status_code=201)
async def create_order(
    body: PaymentOrderIn, actor: CurrentUser, session: SessionDep, settings: SettingsDep
) -> PaymentOrderOut:
    order = await payments_service.create_order(session, settings, actor, body)
    return await payments_service.to_out(session, settings, order)


@router.get("/orders/{order_id}", response_model=PaymentOrderOut)
async def read_order(
    order_id: str, actor: CurrentUser, session: SessionDep, settings: SettingsDep
) -> PaymentOrderOut:
    order = await payments_service.get_own_order(session, actor, order_id)
    return await payments_service.to_out(session, settings, order)


@router.post("/payme")
async def payme_callback(
    request: Request,
    session: SessionDep,
    settings: SettingsDep,
    authorization: Annotated[str | None, Header()] = None,
) -> dict:
    return await payme_service.handle(session, settings, authorization, await request.body())


async def click_form(request: Request) -> dict[str, str]:
    try:
        form = await request.form()
    except Exception:  # noqa: BLE001 - noto'g'ri tana Click xato kodi bilan javob olishi kerak
        return {}
    return {key: value for key, value in form.items() if isinstance(value, str)}


@router.post("/click/prepare")
async def click_prepare(request: Request, session: SessionDep, settings: SettingsDep) -> dict:
    return await click_service.prepare(session, settings, await click_form(request))


@router.post("/click/complete")
async def click_complete(request: Request, session: SessionDep, settings: SettingsDep) -> dict:
    return await click_service.complete(session, settings, await click_form(request))
