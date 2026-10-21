import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response

from zalpro_api.api.deps import CurrentUser, SessionDep, StaffUser
from zalpro_api.schemas.announcement import AnnouncementIn, AnnouncementOut
from zalpro_api.services import announcements as announcements_service
from zalpro_api.services.pagination import PageParams, page_params, set_next_cursor

router = APIRouter(prefix="/announcements", tags=["announcements"])


@router.get("", response_model=list[AnnouncementOut])
async def list_announcements(
    actor: CurrentUser,
    session: SessionDep,
    response: Response,
    page: Annotated[PageParams | None, Depends(page_params)],
) -> list[AnnouncementOut]:
    if page is not None:
        items, cursor = await announcements_service.list_active_page(session, actor, page)
        set_next_cursor(response, cursor)
        return items
    return await announcements_service.list_active(session, actor)


@router.post("", response_model=AnnouncementOut, status_code=201)
async def create_announcement(
    body: AnnouncementIn, actor: StaffUser, session: SessionDep
) -> AnnouncementOut:
    return await announcements_service.create(session, actor, body)


@router.delete("/{announcement_id}", status_code=204)
async def delete_announcement(
    announcement_id: uuid.UUID, actor: StaffUser, session: SessionDep
) -> Response:
    await announcements_service.delete(session, actor, announcement_id)
    return Response(status_code=204)
