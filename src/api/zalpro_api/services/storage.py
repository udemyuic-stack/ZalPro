import uuid
from pathlib import Path
from typing import Literal, Protocol

import aioboto3
import boto3
from boto3.s3.transfer import TransferConfig
from botocore.exceptions import ClientError

from zalpro_api.core.config import Settings
from zalpro_api.core.errors import ApiError

MediaKind = Literal["image", "video"]

MEDIA_FOLDERS: dict[MediaKind, str] = {"image": "images", "video": "videos"}
TRANSFER_CONFIG = TransferConfig(max_concurrency=2)


def build_key(kind: MediaKind, owner_id: str) -> str:
    return f"{MEDIA_FOLDERS[kind]}/{owner_id}/{uuid.uuid4().hex}"


class Storage(Protocol):
    async def presign_put(self, key: str, size: int, expires: int) -> str: ...

    async def presign_get(self, key: str, expires: int, content_type: str | None = None) -> str: ...

    async def head(self, key: str) -> int | None: ...

    async def delete(self, key: str) -> None: ...

    async def download(self, key: str, path: Path) -> None: ...

    async def upload(self, path: Path, key: str, content_type: str) -> None: ...

    async def list_keys(self, prefix: str) -> list[str]: ...


class UnconfiguredStorage:
    async def presign_put(self, key: str, size: int, expires: int) -> str:
        raise self._error()

    async def presign_get(self, key: str, expires: int, content_type: str | None = None) -> str:
        raise self._error()

    async def head(self, key: str) -> int | None:
        raise self._error()

    async def delete(self, key: str) -> None:
        raise self._error()

    async def download(self, key: str, path: Path) -> None:
        raise self._error()

    async def upload(self, path: Path, key: str, content_type: str) -> None:
        raise self._error()

    async def list_keys(self, prefix: str) -> list[str]:
        raise self._error()

    @staticmethod
    def _error() -> ApiError:
        return ApiError(503, "storage_unavailable", "Fayl saqlash sozlanmagan")


class R2Storage:
    def __init__(self, settings: Settings) -> None:
        self._bucket = settings.r2_bucket
        self._session = aioboto3.Session()
        self._options = {
            "endpoint_url": settings.r2_endpoint_url,
            "aws_access_key_id": settings.r2_access_key_id,
            "aws_secret_access_key": settings.r2_secret_access_key,
            "region_name": "auto",
        }
        self._signer = boto3.client("s3", **self._options)

    async def presign_put(self, key: str, size: int, expires: int) -> str:
        return self._signer.generate_presigned_url(
            "put_object",
            Params={"Bucket": self._bucket, "Key": key, "ContentLength": size},
            ExpiresIn=expires,
        )

    async def presign_get(self, key: str, expires: int, content_type: str | None = None) -> str:
        params = {"Bucket": self._bucket, "Key": key}
        if content_type is not None:
            params["ResponseContentType"] = content_type
        return self._signer.generate_presigned_url("get_object", Params=params, ExpiresIn=expires)

    async def head(self, key: str) -> int | None:
        async with self._session.client("s3", **self._options) as client:
            try:
                response = await client.head_object(Bucket=self._bucket, Key=key)
            except ClientError as error:
                if error.response.get("Error", {}).get("Code") in {"404", "NoSuchKey", "NotFound"}:
                    return None
                raise
        return int(response["ContentLength"])

    async def delete(self, key: str) -> None:
        async with self._session.client("s3", **self._options) as client:
            await client.delete_object(Bucket=self._bucket, Key=key)

    async def download(self, key: str, path: Path) -> None:
        async with self._session.client("s3", **self._options) as client:
            await client.download_file(self._bucket, key, str(path), Config=TRANSFER_CONFIG)

    async def upload(self, path: Path, key: str, content_type: str) -> None:
        async with self._session.client("s3", **self._options) as client:
            await client.upload_file(
                str(path),
                self._bucket,
                key,
                ExtraArgs={"ContentType": content_type},
                Config=TRANSFER_CONFIG,
            )

    async def list_keys(self, prefix: str) -> list[str]:
        objects: list[dict] = []
        async with self._session.client("s3", **self._options) as client:
            paginator = client.get_paginator("list_objects_v2")
            async for page in paginator.paginate(Bucket=self._bucket, Prefix=prefix):
                objects.extend(page.get("Contents", []))
        objects.sort(key=lambda item: item["LastModified"], reverse=True)
        return [item["Key"] for item in objects]


def build_storage(settings: Settings) -> Storage:
    if settings.r2_configured:
        return R2Storage(settings)
    return UnconfiguredStorage()
