import base64
import binascii
import json
import uuid
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import date, datetime
from typing import Annotated, Any

from fastapi import Query, Response
from sqlalchemy import and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select

from zalpro_api.core.errors import ApiError

NEXT_CURSOR_HEADER = "X-Next-Cursor"
MAX_LIMIT = 100

PARSERS: dict[type, Callable[[str], Any]] = {
    datetime: datetime.fromisoformat,
    date: date.fromisoformat,
    uuid.UUID: uuid.UUID,
    str: str,
}


@dataclass(frozen=True)
class Key:
    column: Any
    attr: str
    kind: type
    desc: bool = False


@dataclass(frozen=True)
class PageParams:
    limit: int
    cursor: str | None


def page_params(
    limit: Annotated[int | None, Query(ge=1, le=MAX_LIMIT)] = None,
    cursor: Annotated[str | None, Query(max_length=512)] = None,
) -> PageParams | None:
    if limit is None:
        if cursor is not None:
            raise invalid_cursor()
        return None
    return PageParams(limit=limit, cursor=cursor)


def invalid_cursor() -> ApiError:
    return ApiError(422, "invalid_cursor", "Kursor noto'g'ri")


def encode_cursor(values: Sequence[Any]) -> str:
    raw = json.dumps(
        [
            value.isoformat() if isinstance(value, datetime | date) else str(value)
            for value in values
        ]
    )
    return base64.urlsafe_b64encode(raw.encode()).decode().rstrip("=")


def decode_cursor(cursor: str, keys: Sequence[Key]) -> list[Any]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        raw = json.loads(base64.urlsafe_b64decode(padded.encode()))
        if not isinstance(raw, list) or len(raw) != len(keys):
            raise invalid_cursor()
        return [PARSERS[key.kind](value) for key, value in zip(keys, raw, strict=True)]
    except (binascii.Error, ValueError, TypeError, UnicodeError):
        raise invalid_cursor() from None


def after(keys: Sequence[Key], values: Sequence[Any]):
    branches = []
    for index, key in enumerate(keys):
        equal = [keys[i].column == values[i] for i in range(index)]
        step = key.column < values[index] if key.desc else key.column > values[index]
        branches.append(and_(*equal, step))
    return or_(*branches)


async def fetch_page(
    session: AsyncSession,
    statement: Select,
    keys: Sequence[Key],
    page: PageParams,
    entity: Callable[[Any], Any] = lambda row: row[0],
) -> tuple[list[Any], str | None]:
    if page.cursor is not None:
        statement = statement.where(after(keys, decode_cursor(page.cursor, keys)))
    rows = list((await session.execute(statement.limit(page.limit + 1))).all())
    if len(rows) <= page.limit:
        return rows, None
    rows = rows[: page.limit]
    last = entity(rows[-1])
    return rows, encode_cursor([getattr(last, key.attr) for key in keys])


def set_next_cursor(response: Response, cursor: str | None) -> None:
    if cursor is not None:
        response.headers[NEXT_CURSOR_HEADER] = cursor
