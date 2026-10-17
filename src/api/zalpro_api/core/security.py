import asyncio
import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from zalpro_api.core.config import Settings
from zalpro_api.core.errors import unauthorized

JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_TYPE = "access"
CHECKIN_TOKEN_TYPE = "checkin"
CHECKIN_TOKEN_SECONDS = 60

_hasher = PasswordHasher()

DUMMY_PASSWORD_HASH = _hasher.hash(secrets.token_urlsafe(16))


async def hash_password(password: str) -> str:
    return await asyncio.to_thread(_hasher.hash, password)


def _verify_password_sync(password_hash: str, password: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


async def verify_password(password_hash: str, password: str) -> bool:
    return await asyncio.to_thread(_verify_password_sync, password_hash, password)


def _create_token(user_id: str, token_type: str, settings: Settings, lifetime: timedelta) -> str:
    now = datetime.now(UTC)
    claims = {"sub": user_id, "typ": token_type, "iat": now, "exp": now + lifetime}
    return jwt.encode(claims, settings.jwt_secret, algorithm=JWT_ALGORITHM)


def _decode_claims(token: str, token_type: str, settings: Settings) -> dict[str, Any]:
    try:
        claims = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[JWT_ALGORITHM],
            options={"require": ["exp", "sub"]},
        )
    except jwt.ExpiredSignatureError as error:
        raise unauthorized("token_expired", "Sessiya muddati tugagan") from error
    except jwt.InvalidTokenError as error:
        raise unauthorized("invalid_token", "Token yaroqsiz") from error
    if claims.get("typ") != token_type:
        raise unauthorized("invalid_token", "Token yaroqsiz")
    return claims


def create_access_token(user_id: str, settings: Settings, lifetime: timedelta | None = None) -> str:
    expires_in = lifetime or timedelta(minutes=settings.access_token_minutes)
    return _create_token(user_id, ACCESS_TOKEN_TYPE, settings, expires_in)


def decode_access_claims(token: str, settings: Settings) -> tuple[str, datetime]:
    claims = _decode_claims(token, ACCESS_TOKEN_TYPE, settings)
    return claims["sub"], datetime.fromtimestamp(claims["exp"], UTC)


def decode_access_token(token: str, settings: Settings) -> str:
    return decode_access_claims(token, settings)[0]


def create_checkin_token(
    user_id: str, settings: Settings, lifetime: timedelta | None = None
) -> str:
    expires_in = lifetime or timedelta(seconds=CHECKIN_TOKEN_SECONDS)
    return _create_token(user_id, CHECKIN_TOKEN_TYPE, settings, expires_in)


def decode_checkin_token(token: str, settings: Settings) -> str:
    return _decode_claims(token, CHECKIN_TOKEN_TYPE, settings)["sub"]


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
