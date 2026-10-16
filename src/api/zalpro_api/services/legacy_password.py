import asyncio
import base64
import binascii
import hashlib
import hmac

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

from zalpro_api.core.config import Settings
from zalpro_api.models import User

SCRYPT_KEY_LENGTH = 32
SCRYPT_MEMORY_HEADROOM = 2


def _scrypt_hash(password: str, salt: str, settings: Settings) -> bytes:
    salt_bytes = base64.b64decode(salt) + base64.b64decode(settings.legacy_scrypt_salt_separator)
    cost = 2**settings.legacy_scrypt_mem_cost
    block_size = settings.legacy_scrypt_rounds
    derived = hashlib.scrypt(
        password.encode(),
        salt=salt_bytes,
        n=cost,
        r=block_size,
        p=1,
        maxmem=128 * cost * block_size * SCRYPT_MEMORY_HEADROOM,
        dklen=SCRYPT_KEY_LENGTH,
    )
    encryptor = Cipher(algorithms.AES256(derived), modes.CTR(bytes(16))).encryptor()
    signer_key = base64.b64decode(settings.legacy_scrypt_signer_key)
    return encryptor.update(signer_key) + encryptor.finalize()


def _verify_sync(user: User, password: str, settings: Settings) -> bool:
    if user.legacy_hash is None or user.legacy_algo != "scrypt" or user.legacy_salt is None:
        return False
    if not settings.legacy_scrypt_configured:
        return False
    try:
        expected = base64.b64decode(user.legacy_hash)
        actual = _scrypt_hash(password, user.legacy_salt, settings)
    except (binascii.Error, ValueError):
        return False
    return hmac.compare_digest(expected, actual)


async def verify_legacy_password(user: User, password: str, settings: Settings) -> bool:
    return await asyncio.to_thread(_verify_sync, user, password, settings)


def clear_legacy(user: User) -> None:
    user.legacy_hash = None
    user.legacy_salt = None
    user.legacy_algo = None
