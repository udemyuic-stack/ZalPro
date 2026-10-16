from zalpro_api.core.config import Settings
from zalpro_api.models import User
from zalpro_api.services.legacy_password import clear_legacy, verify_legacy_password

SIGNER_KEY = (
    "jxspr8Ki0RYycVU8zykbdLGjFQ3McFUH0uiiTvC8pVMXAn210wjLNmdZJzxUECKbm0QsEmYUSDzZvpjeJ9WmXA=="
)
SALT_SEPARATOR = "Bw=="
SALT = "42xEC+ixf3L2lw=="
PASSWORD = "user1password"
HASH = "lSrfV15cpx95/sZS2W9c9Kp6i/LVgQNDNC/qzrCnh1SAyZvqmZqAjTdn3aoItz+VHjoZilo78198JAdRuid5lQ=="


def make_settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "database_url": "postgresql+asyncpg://x:x@localhost/x",
        "jwt_secret": "x" * 32,
        "legacy_scrypt_signer_key": SIGNER_KEY,
        "legacy_scrypt_salt_separator": SALT_SEPARATOR,
        "legacy_scrypt_rounds": 8,
        "legacy_scrypt_mem_cost": 14,
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)


def make_legacy_user(**overrides: object) -> User:
    values: dict[str, object] = {
        "id": "u1",
        "phone": "998901112233",
        "password_hash": "x",
        "legacy_hash": HASH,
        "legacy_salt": SALT,
        "legacy_algo": "scrypt",
    }
    values.update(overrides)
    return User(**values)


async def test_firebase_vector_matches() -> None:
    assert await verify_legacy_password(make_legacy_user(), PASSWORD, make_settings())


async def test_wrong_password_fails() -> None:
    assert not await verify_legacy_password(make_legacy_user(), "wrong", make_settings())


async def test_unconfigured_settings_fail() -> None:
    settings = make_settings(legacy_scrypt_signer_key="", legacy_scrypt_salt_separator="")
    assert not await verify_legacy_password(make_legacy_user(), PASSWORD, settings)


async def test_user_without_legacy_hash_fails() -> None:
    user = make_legacy_user(legacy_hash=None, legacy_salt=None, legacy_algo=None)
    assert not await verify_legacy_password(user, PASSWORD, make_settings())


async def test_bcrypt_algo_not_verified_by_scrypt() -> None:
    user = make_legacy_user(legacy_algo="bcrypt")
    assert not await verify_legacy_password(user, PASSWORD, make_settings())


async def test_malformed_hash_fails() -> None:
    user = make_legacy_user(legacy_hash="@@@not-base64@@@")
    assert not await verify_legacy_password(user, PASSWORD, make_settings())


def test_clear_legacy_nulls_columns() -> None:
    user = make_legacy_user()
    clear_legacy(user)
    assert (user.legacy_hash, user.legacy_salt, user.legacy_algo) == (None, None, None)
