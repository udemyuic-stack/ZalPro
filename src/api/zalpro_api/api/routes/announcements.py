import uuid

from fastapi import APIRouter, Response

from zalpro_api.api.deps import CurrentUser, SessionDep, StaffUser
from zalpro_api.schemas.announcement import AnnouncementIn, AnnouncementOut
from zalpro_api.services import announcements as announcements_service

router = APIRouter(prefix="/announcements", tags=["announcements"])


@router.get("", response_model=list[AnnouncementOut])
async def list_announcements(actor: CurrentUser, session: SessionDep) -> list[AnnouncementOut]:
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
