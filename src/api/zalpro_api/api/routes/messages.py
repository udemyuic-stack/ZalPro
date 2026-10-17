from typing import Annotated

from fastapi import APIRouter, Query
from pydantic import AwareDatetime

from zalpro_api.api.deps import (
    CurrentUser,
    HubDep,
    SessionDep,
    SettingsDep,
    StorageDep,
    VideoWorkerDep,
)
from zalpro_api.schemas.chat_media import ChatMediaUploadIn
from zalpro_api.schemas.image_upload import ImageUploadOut
from zalpro_api.schemas.message import (
    DEFAULT_MESSAGES_LIMIT,
    MAX_MESSAGES_LIMIT,
    MessageIn,
    MessageOut,
)
from zalpro_api.services import chat_media, permissions
from zalpro_api.services import messages as messages_service
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/chats", tags=["messages"])


@router.get("/{uid}/messages", response_model=list[MessageOut])
async def list_messages(
    uid: str,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
    limit: Annotated[int, Query(ge=1, le=MAX_MESSAGES_LIMIT)] = DEFAULT_MESSAGES_LIMIT,
    before: Annotated[AwareDatetime | None, Query()] = None,
) -> list[MessageOut]:
    chat_owner = await users_service.get_user_or_404(session, uid)
    permissions.ensure_can_read_chat(actor, chat_owner)
    return await messages_service.list_messages_out(session, storage, settings, uid, limit, before)


@router.post("/{uid}/messages", response_model=MessageOut, status_code=201)
async def post_message(
    uid: str,
    body: MessageIn,
    actor: CurrentUser,
    session: SessionDep,
    hub: HubDep,
    storage: StorageDep,
    settings: SettingsDep,
    worker: VideoWorkerDep,
) -> MessageOut:
    chat_owner = await users_service.get_user_or_404(session, uid)
    permissions.ensure_can_post_chat(actor, chat_owner)
    return await messages_service.post_message(
        session, hub, storage, settings, worker, uid, actor.id, body
    )


@router.post("/{uid}/media/upload-url", response_model=ImageUploadOut, status_code=201)
async def create_media_upload_url(
    uid: str,
    body: ChatMediaUploadIn,
    actor: CurrentUser,
    session: SessionDep,
    storage: StorageDep,
    settings: SettingsDep,
) -> ImageUploadOut:
    chat_owner = await users_service.get_user_or_404(session, uid)
    permissions.ensure_can_post_chat(actor, chat_owner)
    expires = settings.video_url_seconds if body.kind == "video" else settings.photo_url_seconds
    return await chat_media.create_upload(storage, uid, body, expires)
