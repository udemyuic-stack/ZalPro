import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path


class AuthExportError(Exception):
    pass


@dataclass(frozen=True)
class AuthRecord:
    uid: str
    email: str
    password_hash: str | None
    salt: str | None
    algo: str | None
    created_at: datetime | None
    disabled: bool


def detect_algo(password_hash: str | None, salt: str | None) -> str | None:
    if not password_hash:
        return None
    if password_hash.startswith(("$2a$", "$2b$", "$2y$")):
        return "bcrypt"
    if salt:
        return "scrypt"
    return None


def parse_created_at(raw: object) -> datetime | None:
    if raw in (None, ""):
        return None
    try:
        return datetime.fromtimestamp(int(str(raw)) / 1000, tz=UTC)
    except (ValueError, OverflowError, OSError):
        return None


def load_auth_export(path: Path) -> dict[str, AuthRecord]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise AuthExportError(f"cannot read auth export: {type(error).__name__}") from None
    users = payload.get("users")
    if not isinstance(users, list):
        raise AuthExportError("auth export has no users list")
    records: dict[str, AuthRecord] = {}
    for row in users:
        uid = row.get("localId")
        if not uid:
            raise AuthExportError("auth export row without localId")
        password_hash = row.get("passwordHash") or None
        salt = row.get("salt") or None
        records[uid] = AuthRecord(
            uid=uid,
            email=row.get("email") or "",
            password_hash=password_hash,
            salt=salt,
            algo=detect_algo(password_hash, salt),
            created_at=parse_created_at(row.get("createdAt")),
            disabled=bool(row.get("disabled", False)),
        )
    return records
