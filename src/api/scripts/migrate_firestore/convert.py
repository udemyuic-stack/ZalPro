import uuid
from datetime import UTC, date, datetime
from typing import Any

NAMESPACE = uuid.UUID("5c1f3a52-7b0e-4f0c-9a41-2d6b8e7a0c11")
EPOCH_MS_THRESHOLD = 100_000_000_000


def stable_uuid(kind: str, *parts: str) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, ":".join((kind, *parts)))


def text(value: Any, default: str = "") -> str:
    if value is None:
        return default
    if isinstance(value, str):
        return value
    if isinstance(value, bool):
        return default
    if isinstance(value, int | float):
        return str(value)
    return default


def integer(value: Any, default: int = 0) -> int:
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if value != value or value in (float("inf"), float("-inf")):
            return default
        return int(round(value))
    if isinstance(value, str):
        try:
            return int(float(value))
        except ValueError:
            return default
    return default


def number(value: Any, default: float = 0.0) -> float:
    if isinstance(value, bool):
        return default
    if isinstance(value, int | float):
        result = float(value)
        if result != result or result in (float("inf"), float("-inf")):
            return default
        return result
    if isinstance(value, str):
        try:
            return number(float(value), default)
        except ValueError:
            return default
    return default


def optional_number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    result = number(value, float("nan"))
    return None if result != result else result


def optional_integer(value: Any) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int | float | str):
        parsed = number(value, float("nan"))
        return None if parsed != parsed else int(round(parsed))
    return None


def boolean(value: Any, default: bool = False) -> bool:
    return value if isinstance(value, bool) else default


def when(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=UTC)
    if isinstance(value, bool):
        return None
    if isinstance(value, int | float):
        try:
            seconds = value / 1000 if abs(value) >= EPOCH_MS_THRESHOLD else value
            return datetime.fromtimestamp(seconds, tz=UTC)
        except (OverflowError, OSError, ValueError):
            return None
    return None


def day_from_key(key: str) -> date | None:
    try:
        return date.fromisoformat(key)
    except ValueError:
        return None


def string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in (text(entry) for entry in value) if item != ""]


def int_list(value: Any) -> list[int]:
    if not isinstance(value, list):
        return []
    sentinel = -(2**62)
    parsed = [integer(entry, sentinel) for entry in value if isinstance(entry, int | float | str)]
    return [entry for entry in parsed if entry != sentinel]


def jsonable(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, bytes):
        raise ValueError("bytes are not json serialisable")
    if isinstance(value, dict):
        return {str(key): jsonable(item) for key, item in value.items()}
    if isinstance(value, list):
        return [jsonable(item) for item in value]
    if isinstance(value, float) and (value != value or value in (float("inf"), float("-inf"))):
        return None
    return value
