import asyncio
from collections.abc import Awaitable, Callable, Sequence
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

import aioboto3
from botocore.exceptions import ClientError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine

from scripts.migrate_firestore.load import batches, clean
from zalpro_api.core.config import Settings
from zalpro_api.models import Photo

UPLOAD_ATTEMPTS = 3
CONCURRENCY = 8
MISSING_CODES = frozenset({"404", "NoSuchKey", "NotFound"})


class PhotoStore(Protocol):
    async def size_of(self, key: str) -> int | None: ...

    async def put(self, key: str, data: bytes) -> None: ...


class R2PhotoStore:
    def __init__(self, settings: Settings) -> None:
        self._bucket = settings.r2_bucket
        self._session = aioboto3.Session()
        self._options = {
            "endpoint_url": settings.r2_endpoint_url,
            "aws_access_key_id": settings.r2_access_key_id,
            "aws_secret_access_key": settings.r2_secret_access_key,
            "region_name": "auto",
        }

    async def size_of(self, key: str) -> int | None:
        async with self._session.client("s3", **self._options) as client:
            try:
                head = await client.head_object(Bucket=self._bucket, Key=key)
            except ClientError as error:
                if str(error.response.get("Error", {}).get("Code")) in MISSING_CODES:
                    return None
                raise
            return int(head["ContentLength"])

    async def put(self, key: str, data: bytes) -> None:
        async with self._session.client("s3", **self._options) as client:
            await client.put_object(Bucket=self._bucket, Key=key, Body=data)


@dataclass
class PhotoResult:
    uploaded: int = 0
    skipped: int = 0
    inserted: int = 0
    failed: list[tuple[str, str]] = field(default_factory=list)


async def upload_one(
    store: PhotoStore,
    row: dict[str, Any],
    directory: Path,
    dry_run: bool,
    sleep: Callable[[float], Awaitable[None]],
) -> str:
    path = directory / row["_file"]
    if not path.is_file():
        return "file_missing"
    data = path.read_bytes()
    if len(data) != row["size"]:
        return "size_mismatch"
    if dry_run:
        return "dry_run"
    for attempt in range(UPLOAD_ATTEMPTS):
        try:
            if await store.size_of(row["key"]) == row["size"]:
                return "skipped"
            await store.put(row["key"], data)
            if await store.size_of(row["key"]) != row["size"]:
                return "verify_failed"
            return "uploaded"
        except Exception as error:
            if attempt == UPLOAD_ATTEMPTS - 1:
                return f"upload_failed:{type(error).__name__}"
            await sleep(2**attempt)
    return "upload_failed"


async def upload_photos(
    engine: AsyncEngine,
    store: PhotoStore,
    rows: Sequence[dict[str, Any]],
    directory: Path,
    *,
    dry_run: bool,
    sleep: Callable[[float], Awaitable[None]] = asyncio.sleep,
) -> PhotoResult:
    result = PhotoResult()
    gate = asyncio.Semaphore(CONCURRENCY)

    async def work(row: dict[str, Any]) -> tuple[dict[str, Any], str]:
        async with gate:
            return row, await upload_one(store, row, directory, dry_run, sleep)

    outcomes = await asyncio.gather(*(work(row) for row in rows))
    ready = []
    for row, outcome in outcomes:
        if outcome == "uploaded":
            result.uploaded += 1
            ready.append(row)
        elif outcome == "skipped":
            result.skipped += 1
            ready.append(row)
        elif outcome == "dry_run":
            result.uploaded += 1
        else:
            result.failed.append((str(row["id"]), outcome))
    if dry_run or not ready:
        return result
    table = Photo.__table__
    async with engine.begin() as connection:
        for chunk in batches(ready):
            ids = [row["id"] for row in chunk]
            lookup = select(table.c.id).where(table.c.id.in_(ids))
            known = set((await connection.execute(lookup)).scalars())
            fresh = [clean(row) for row in chunk if row["id"] not in known]
            if fresh:
                await connection.execute(table.insert(), fresh)
            result.inserted += len(fresh)
    return result
