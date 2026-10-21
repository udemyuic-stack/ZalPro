from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from zalpro_api.api.deps import CurrentUser, HubDep, OwnerUser, SessionDep, SettingsDep
from zalpro_api.models import Reminder
from zalpro_api.schemas.day import OptionalDayRange
from zalpro_api.schemas.reminder import ReminderIn, ReminderOut
from zalpro_api.services import permissions
from zalpro_api.services import reminders as reminders_service
from zalpro_api.services import users as users_service
from zalpro_api.services.messages import publish_staged
from zalpro_api.services.pagination import PageParams, page_params, set_next_cursor

router = APIRouter(prefix="/reminders", tags=["reminders"])


@router.post("", response_model=ReminderOut, status_code=201)
async def create_reminder(
    body: ReminderIn, actor: CurrentUser, session: SessionDep, hub: HubDep
) -> Reminder:
    permissions.ensure_staff(actor)
    client = await users_service.get_user_or_404(session, body.client_id)
    permissions.ensure_can_create_reminder(actor, client)
    reminder = await reminders_service.create_reminder(session, actor, client, body.days_left)
    publish_staged(session, hub)
    return reminder


@router.get("", response_model=list[ReminderOut])
async def list_reminders(
    window: Annotated[OptionalDayRange, Query()],
    actor: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
    response: Response,
    page: Annotated[PageParams | None, Depends(page_params)],
) -> list[Reminder]:
    permissions.requires_window(actor, window.from_, window.to)
    if page is not None:
        reminders, cursor = await reminders_service.list_reminders_page(
            session,
            permissions.reminder_trainer_scope(actor),
            window.from_,
            window.to,
            settings.gym_timezone,
            page,
        )
        set_next_cursor(response, cursor)
        return reminders
    return await reminders_service.list_reminders(
        session,
        permissions.reminder_trainer_scope(actor),
        window.from_,
        window.to,
        settings.gym_timezone,
    )


@router.delete("/{reminder_id}", status_code=204)
async def delete_reminder(reminder_id: str, actor: OwnerUser, session: SessionDep) -> Response:
    await reminders_service.delete_reminder(session, reminder_id)
    return Response(status_code=204)
