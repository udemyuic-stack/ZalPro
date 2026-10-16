from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Request, Response
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from zalpro_api.api.deps import CurrentUser, LoginThrottleDep, SessionDep, SettingsDep
from zalpro_api.core.config import Settings
from zalpro_api.core.errors import bad_request, unauthorized
from zalpro_api.core.security import (
    DUMMY_PASSWORD_HASH,
    create_access_token,
    generate_refresh_token,
    hash_password,
    hash_refresh_token,
    verify_password,
)
from zalpro_api.models import RefreshToken, User
from zalpro_api.schemas.auth import (
    ChangePasswordRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPair,
)
from zalpro_api.services import users as users_service
from zalpro_api.services.legacy_password import clear_legacy, verify_legacy_password
from zalpro_api.services.login_throttle import throttle_key
from zalpro_api.services.refresh_tokens import revoke_all_refresh_tokens

router = APIRouter(prefix="/auth", tags=["auth"])


async def issue_token_pair(session: AsyncSession, settings: Settings, user: User) -> TokenPair:
    refresh_token = generate_refresh_token()
    session.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_refresh_token(refresh_token),
            expires_at=datetime.now(UTC) + timedelta(days=settings.refresh_token_days),
        )
    )
    await session.commit()
    return TokenPair(
        access_token=create_access_token(user.id, settings),
        refresh_token=refresh_token,
        expires_in=settings.access_token_minutes * 60,
    )


@router.post("/register", response_model=TokenPair, status_code=201)
async def register(body: RegisterRequest, session: SessionDep, settings: SettingsDep) -> TokenPair:
    password_hash = await hash_password(body.password)
    user = await users_service.create_user(
        session, name=body.name, phone=body.phone, password_hash=password_hash
    )
    return await issue_token_pair(session, settings, user)


async def check_credentials(user: User | None, password: str, settings: Settings) -> bool:
    if user is None:
        await verify_password(DUMMY_PASSWORD_HASH, password)
        return False
    if await verify_password(user.password_hash, password):
        return True
    if user.legacy_hash is None or not await verify_legacy_password(user, password, settings):
        return False
    user.password_hash = await hash_password(password)
    clear_legacy(user)
    return True


@router.post("/login", response_model=TokenPair)
async def login(
    body: LoginRequest,
    request: Request,
    session: SessionDep,
    settings: SettingsDep,
    throttle: LoginThrottleDep,
) -> TokenPair:
    key = throttle_key(body.phone, request.client.host if request.client else None)
    throttle.ensure_allowed(key)
    user = await session.scalar(select(User).where(User.phone == body.phone))
    if not await check_credentials(user, body.password, settings) or user is None:
        throttle.record_failure(key)
        raise unauthorized("invalid_credentials", "Telefon raqami yoki parol noto'g'ri")
    throttle.clear(key)
    return await issue_token_pair(session, settings, user)


@router.post("/refresh", response_model=TokenPair)
async def refresh(body: RefreshRequest, session: SessionDep, settings: SettingsDep) -> TokenPair:
    now = datetime.now(UTC)
    stored = await session.scalar(
        select(RefreshToken)
        .where(RefreshToken.token_hash == hash_refresh_token(body.refresh_token))
        .with_for_update()
    )
    if stored is None or stored.revoked_at is not None or stored.expires_at <= now:
        raise unauthorized("invalid_refresh_token", "Qayta kirish kerak")
    stored.revoked_at = now
    user = await users_service.get_user_or_404(session, stored.user_id)
    return await issue_token_pair(session, settings, user)


@router.post("/logout", status_code=204)
async def logout(body: RefreshRequest, actor: CurrentUser, session: SessionDep) -> Response:
    await session.execute(
        update(RefreshToken)
        .where(
            RefreshToken.token_hash == hash_refresh_token(body.refresh_token),
            RefreshToken.user_id == actor.id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=datetime.now(UTC))
    )
    await session.commit()
    return Response(status_code=204)


@router.post("/change-password", status_code=204)
async def change_password(
    body: ChangePasswordRequest, actor: CurrentUser, session: SessionDep
) -> Response:
    if not await verify_password(actor.password_hash, body.current_password):
        raise bad_request("wrong_password", "Joriy parol noto'g'ri")
    actor.password_hash = await hash_password(body.new_password)
    await revoke_all_refresh_tokens(session, actor.id)
    await session.commit()
    return Response(status_code=204)
