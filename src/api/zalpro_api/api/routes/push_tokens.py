from fastapi import APIRouter, Response

from zalpro_api.api.deps import CurrentUser, SessionDep
from zalpro_api.schemas.push_token import PushTokenIn, PushTokenValue
from zalpro_api.services import push_tokens as push_tokens_service

router = APIRouter(prefix="/users/me/push-tokens", tags=["push-tokens"])


@router.post("", status_code=204)
async def register_push_token(
    body: PushTokenIn, actor: CurrentUser, session: SessionDep
) -> Response:
    await push_tokens_service.register_token(session, actor.id, body.token, body.platform)
    return Response(status_code=204)


@router.delete("/{token}", status_code=204)
async def delete_push_token(
    token: PushTokenValue, actor: CurrentUser, session: SessionDep
) -> Response:
    await push_tokens_service.remove_token(session, actor.id, token)
    return Response(status_code=204)
