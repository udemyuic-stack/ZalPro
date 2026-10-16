from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.core.config import Settings
from zalpro_api.core.errors import unauthorized
from zalpro_api.core.security import decode_access_token
from zalpro_api.models import User
from zalpro_api.services import permissions
from zalpro_api.services.chat_hub import ChatHub
from zalpro_api.services.login_throttle import LoginThrottle
from zalpro_api.services.storage import Storage

bearer_scheme = HTTPBearer(auto_error=False)


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


async def get_session(request: Request) -> AsyncIterator[AsyncSession]:
    async with request.app.state.sessionmaker() as session:
        yield session


def get_hub(request: Request) -> ChatHub:
    return request.app.state.hub


def get_login_throttle(request: Request) -> LoginThrottle:
    return request.app.state.login_throttle


def get_storage(request: Request) -> Storage:
    return request.app.state.storage


SettingsDep = Annotated[Settings, Depends(get_settings)]
SessionDep = Annotated[AsyncSession, Depends(get_session)]
HubDep = Annotated[ChatHub, Depends(get_hub)]
LoginThrottleDep = Annotated[LoginThrottle, Depends(get_login_throttle)]
StorageDep = Annotated[Storage, Depends(get_storage)]


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
    session: SessionDep,
    settings: SettingsDep,
) -> User:
    if credentials is None:
        raise unauthorized()
    user_id = decode_access_token(credentials.credentials, settings)
    user = await session.get(User, user_id)
    if user is None:
        raise unauthorized("invalid_token", "Token yaroqsiz")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


async def require_owner(actor: CurrentUser) -> User:
    permissions.ensure_owner(actor)
    return actor


async def require_staff(actor: CurrentUser) -> User:
    permissions.ensure_staff(actor)
    return actor


async def require_shop_writer(actor: CurrentUser) -> User:
    permissions.ensure_can_write_products(actor)
    return actor


OwnerUser = Annotated[User, Depends(require_owner)]
StaffUser = Annotated[User, Depends(require_staff)]
ShopWriter = Annotated[User, Depends(require_shop_writer)]
