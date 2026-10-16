from pathlib import Path
from typing import Any

from scripts.migrate_firestore.extract import (
    CHAT_COLLECTION,
    TOP_LEVEL,
    USER_SUBCOLLECTIONS,
    read_jsonl,
)
from scripts.migrate_firestore.firestore_values import decode_document, parse_timestamp

KINDS = (*TOP_LEVEL, *USER_SUBCOLLECTIONS, CHAT_COLLECTION)


def decode_record(raw: dict[str, Any]) -> dict[str, Any]:
    decoded = decode_document(raw)
    create_time = raw.get("createTime")
    decoded["_create_time"] = parse_timestamp(create_time) if create_time else None
    if "photoBytes" in raw:
        decoded["photoBytes"] = raw["photoBytes"]
    return decoded


def load_source(directory: Path) -> dict[str, list[tuple[str | None, dict[str, Any]]]]:
    source: dict[str, list[tuple[str | None, dict[str, Any]]]] = {}
    for kind in KINDS:
        source[kind] = [(parent, decode_record(raw)) for parent, raw in read_jsonl(directory, kind)]
    return source
