import asyncio
from datetime import UTC, datetime
from pathlib import Path

import pytest
from sqlalchemy.engine import URL

from scripts.backup.__main__ import main
from scripts.backup.dump import make_backup, ping
from scripts.backup.errors import BackupError
from tests.backup.support import FakeBackupStore

DATABASE_URL = "postgresql+asyncpg://u:p%40ss@db:5432/zalpro"
MOMENT = datetime(2026, 3, 4, 3, 30, 15, tzinfo=UTC)
PREFIX = "zalpro"


async def write_dump(url: URL, path: Path) -> None:
    assert url.password == "p@ss"
    assert url.database == "zalpro"
    await asyncio.to_thread(path.write_bytes, b"dump-bytes")


async def write_empty(url: URL, path: Path) -> None:
    await asyncio.to_thread(path.write_bytes, b"")


async def write_nothing(url: URL, path: Path) -> None:
    return None


async def test_make_backup_uploads_and_verifies_size() -> None:
    store = FakeBackupStore()
    result = await make_backup(DATABASE_URL, store, PREFIX, MOMENT, write_dump)
    assert result.key == "zalpro/daily/2026/zalpro-20260304T033015Z.dump"
    assert result.size == len(b"dump-bytes")
    assert store.blobs[result.key] == b"dump-bytes"


async def test_make_backup_fails_on_size_mismatch() -> None:
    store = FakeBackupStore()
    store.truncate_uploads = True
    with pytest.raises(BackupError, match="size mismatch"):
        await make_backup(DATABASE_URL, store, PREFIX, MOMENT, write_dump)


@pytest.mark.parametrize("runner", [write_empty, write_nothing])
async def test_make_backup_rejects_empty_dump(runner) -> None:
    store = FakeBackupStore()
    with pytest.raises(BackupError, match="empty"):
        await make_backup(DATABASE_URL, store, PREFIX, MOMENT, runner)
    assert store.blobs == {}


async def test_ping_without_url_is_noop() -> None:
    await ping("", True)


async def test_main_requires_backup_configuration(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("DATABASE_URL", DATABASE_URL)
    monkeypatch.setenv("JWT_SECRET", "x" * 32)
    for name in ("BACKUP_R2_ENDPOINT_URL", "BACKUP_R2_BUCKET"):
        monkeypatch.setenv(name, "")
    assert await main(["dump"]) == 1
