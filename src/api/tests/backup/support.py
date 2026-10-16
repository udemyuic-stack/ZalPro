import asyncio
from datetime import UTC, datetime
from pathlib import Path

from scripts.backup.store import StoredObject


class FakeBackupStore:
    def __init__(self) -> None:
        self.blobs: dict[str, bytes] = {}
        self.deleted: list[str] = []
        self.truncate_uploads = False

    async def upload(self, path: Path, key: str) -> None:
        data = await asyncio.to_thread(path.read_bytes)
        self.blobs[key] = data[:-1] if self.truncate_uploads else data

    async def size_of(self, key: str) -> int | None:
        return len(self.blobs[key]) if key in self.blobs else None

    async def list_objects(self, prefix: str) -> list[StoredObject]:
        return [
            StoredObject(key, len(data), datetime(2026, 1, 1, tzinfo=UTC))
            for key, data in sorted(self.blobs.items())
            if key.startswith(prefix)
        ]

    async def download(self, key: str, path: Path) -> None:
        await asyncio.to_thread(path.write_bytes, self.blobs[key])

    async def delete(self, keys: list[str]) -> None:
        for key in keys:
            self.blobs.pop(key, None)
        self.deleted.extend(keys)

    def seed(self, key: str, data: bytes = b"x") -> None:
        self.blobs[key] = data
