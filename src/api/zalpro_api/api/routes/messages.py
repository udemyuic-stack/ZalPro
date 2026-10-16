from typing import Annotated

from fastapi import APIRouter, Query
from pydantic import AwareDatetime

from zalpro_api.api.deps import CurrentUser, HubDep, SessionDep
from zalpro_api.models import Message
from zalpro_api.schemas.message import (
    DEFAULT_MESSAGES_LIMIT,
    MAX_MESSAGES_LIMIT,
    MessageIn,
    MessageOut,
)
from zalpro_api.services import messages as messages_service
from zalpro_api.services import permissions
from zalpro_api.services import users as users_service

router = APIRouter(prefix="/chats", tags=["messages"])


@router.get("/{uid}/messages", response_model=list[MessageOut])
async def list_messages(
    uid: str,
    actor: CurrentUser,
    session: SessionDep,
    limit: Annotated[int, Query(ge=1, le=MAX_MESSAGES_LIMIT)] = DEFAULT_MESSAGES_LIMIT,
    before: Annotated[AwareDatetime | None, Query()] = None,
) -> list[Message]:
    chat_owner = await users_service.get_user_or_404(session, uid)
    permissions.ensure_can_read_chat(actor, chat_owner)
    return await messages_service.list_messages(session, uid, limit, before)


@router.post("/{uid}/messages", response_model=MessageOut, status_code=201)
async def post_message(
    uid: str, body: MessageIn, actor: CurrentUser, session: SessionDep, hub: HubDep
) -> Message:
    chat_owner = await users_service.get_user_or_404(session, uid)
    permissions.ensure_can_post_chat(actor, chat_owner)
    return await messages_service.post_message(session, hub, uid, actor.id, body.text)
