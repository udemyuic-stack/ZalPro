from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Protocol

import aioboto3
from botocore.exceptions import ClientError

from zalpro_api.core.config import Settings

MISSING_CODES = frozenset({"404", "NoSuchKey", "NotFound"})


@dataclass(frozen=True)
class StoredObject:
    key: str
    size: int
    modified: datetime


class BackupStore(Protocol):
    async def upload(self, path: Path, key: str) -> None: ...

    async def size_of(self, key: str) -> int | None: ...

    async def list_objects(self, prefix: str) -> list[StoredObject]: ...

    async def download(self, key: str, path: Path) -> None: ...

    async def delete(self, keys: list[str]) -> None: ...


class R2BackupStore:
    def __init__(self, settings: Settings) -> None:
        self._bucket = settings.backup_r2_bucket
        self._session = aioboto3.Session()
        self._options = {
            "endpoint_url": settings.backup_r2_endpoint_url,
            "aws_access_key_id": settings.backup_r2_access_key_id,
            "aws_secret_access_key": settings.backup_r2_secret_access_key,
            "region_name": "auto",
        }

    async def upload(self, path: Path, key: str) -> None:
        async with self._session.client("s3", **self._options) as client:
            await client.upload_file(str(path), self._bucket, key)

    async def size_of(self, key: str) -> int | None:
        async with self._session.client("s3", **self._options) as client:
            try:
                head = await client.head_object(Bucket=self._bucket, Key=key)
            except ClientError as error:
                if str(error.response.get("Error", {}).get("Code")) in MISSING_CODES:
                    return None
                raise
            return int(head["ContentLength"])

    async def list_objects(self, prefix: str) -> list[StoredObject]:
        found: list[StoredObject] = []
        async with self._session.client("s3", **self._options) as client:
            paginator = client.get_paginator("list_objects_v2")
            async for page in paginator.paginate(Bucket=self._bucket, Prefix=prefix):
                found.extend(
                    StoredObject(item["Key"], int(item["Size"]), item["LastModified"])
                    for item in page.get("Contents", [])
                )
        return found

    async def download(self, key: str, path: Path) -> None:
        async with self._session.client("s3", **self._options) as client:
            await client.download_file(self._bucket, key, str(path))

    async def delete(self, keys: list[str]) -> None:
        async with self._session.client("s3", **self._options) as client:
            for start in range(0, len(keys), 1000):
                chunk = keys[start : start + 1000]
                await client.delete_objects(
                    Bucket=self._bucket,
                    Delete={"Objects": [{"Key": key} for key in chunk], "Quiet": True},
                )
