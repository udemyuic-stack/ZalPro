import base64
import math
import re
from datetime import UTC, datetime, timedelta
from typing import Any

_TIMESTAMP = re.compile(
    r"^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?([Zz]|[+-]\d{2}:\d{2})$"
)
_SPECIAL_DOUBLES = {
    "NaN": math.nan,
    "Infinity": math.inf,
    "-Infinity": -math.inf,
}


def parse_timestamp(raw: str) -> datetime:
    match = _TIMESTAMP.match(raw)
    if match is None:
        raise ValueError(f"invalid timestamp: {raw!r}")
    year, month, day, hour, minute, second, fraction, zone = match.groups()
    micro = int((fraction or "0")[:6].ljust(6, "0"))
    value = datetime(
        int(year), int(month), int(day), int(hour), int(minute), int(second), micro, tzinfo=UTC
    )
    if zone in ("Z", "z"):
        return value
    sign = 1 if zone[0] == "+" else -1
    offset = timedelta(hours=int(zone[1:3]), minutes=int(zone[4:6]))
    return value - sign * offset


def decode_value(value: dict[str, Any]) -> Any:
    if len(value) != 1:
        raise ValueError(f"invalid value: {sorted(value)}")
    kind, raw = next(iter(value.items()))
    if kind == "nullValue":
        return None
    if kind in ("stringValue", "referenceValue", "booleanValue"):
        return raw
    if kind == "integerValue":
        return int(raw)
    if kind == "doubleValue":
        if isinstance(raw, str):
            if raw in _SPECIAL_DOUBLES:
                return _SPECIAL_DOUBLES[raw]
            return float(raw)
        return float(raw)
    if kind == "timestampValue":
        return parse_timestamp(raw)
    if kind == "bytesValue":
        return base64.b64decode(raw, validate=True)
    if kind == "geoPointValue":
        return {"latitude": raw.get("latitude", 0.0), "longitude": raw.get("longitude", 0.0)}
    if kind == "mapValue":
        return decode_fields(raw.get("fields", {}))
    if kind == "arrayValue":
        return [decode_value(item) for item in raw.get("values", [])]
    raise ValueError(f"unknown value type: {kind}")


def decode_fields(fields: dict[str, Any]) -> dict[str, Any]:
    return {name: decode_value(value) for name, value in fields.items()}


def document_id(name: str) -> str:
    return name.rsplit("/", 1)[-1]


def decode_document(document: dict[str, Any]) -> dict[str, Any]:
    decoded = decode_fields(document.get("fields", {}))
    decoded["_id"] = document_id(document["name"])
    return decoded
