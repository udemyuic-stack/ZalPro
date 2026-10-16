import shutil
import subprocess
from datetime import UTC, datetime
from pathlib import Path

import pytest
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine

from scripts.backup.dump import make_backup, run_pg_dump
from scripts.backup.errors import BackupError
from scripts.backup.restore_check import restore_check
from tests.backup.support import FakeBackupStore

PREFIX = "zalpro"
MOMENT = datetime(2026, 3, 4, 3, 30, 15, tzinfo=UTC)


def tool_major(name: str) -> int | None:
    path = shutil.which(name)
    if path is None:
        return None
    output = subprocess.run([path, "--version"], capture_output=True, text=True, check=True)
    return int(output.stdout.split()[-1].split(".")[0])


async def server_major(database_url: str) -> int:
    engine = create_async_engine(database_url)
    try:
        async with engine.connect() as connection:
            value = (await connection.execute(text("show server_version_num"))).scalar_one()
    finally:
        await engine.dispose()
    return int(value) // 10000


@pytest.fixture
async def database_url(settings) -> str:
    url = settings.database_url
    client = tool_major("pg_dump")
    if client is None or tool_major("pg_restore") is None:
        pytest.skip("pg_dump / pg_restore not installed")
    if client < await server_major(url):
        pytest.skip("pg_dump older than the test server")
    return url


async def test_dump_then_restore_check_matches_source(database_url: str, make_user) -> None:
    await make_user()
    await make_user()
    store = FakeBackupStore()
    result = await make_backup(database_url, store, PREFIX, MOMENT, run_pg_dump)
    assert result.size > 0
    counts = await restore_check(database_url, store, PREFIX)
    engine = create_async_engine(database_url)
    try:
        async with engine.connect() as connection:
            live = (await connection.execute(text("select count(*) from users"))).scalar_one()
    finally:
        await engine.dispose()
    assert counts["users"] == live == 2
    assert counts["alembic_version"] == 1


async def test_restore_check_drops_scratch_database(database_url: str, make_user) -> None:
    await make_user()
    store = FakeBackupStore()
    await make_backup(database_url, store, PREFIX, MOMENT, run_pg_dump)
    await restore_check(database_url, store, PREFIX)
    admin = create_async_engine(
        make_url(database_url).set(database="postgres"), isolation_level="AUTOCOMMIT"
    )
    try:
        async with admin.connect() as connection:
            rows = await connection.execute(
                text("select datname from pg_database where datname like 'zalpro_restore_check_%'")
            )
            assert rows.all() == []
    finally:
        await admin.dispose()


async def test_restore_check_fails_without_backups(database_url: str) -> None:
    with pytest.raises(BackupError, match="no backups"):
        await restore_check(database_url, FakeBackupStore(), PREFIX)


async def test_restore_check_reports_corrupt_dump_and_cleans_up(database_url: str) -> None:
    store = FakeBackupStore()
    store.seed("zalpro/daily/2026/zalpro-20260304T033015Z.dump", b"not a dump")
    with pytest.raises(BackupError, match="pg_restore"):
        await restore_check(database_url, store, PREFIX)
    admin = create_async_engine(
        make_url(database_url).set(database="postgres"), isolation_level="AUTOCOMMIT"
    )
    try:
        async with admin.connect() as connection:
            rows = await connection.execute(
                text("select datname from pg_database where datname like 'zalpro_restore_check_%'")
            )
            assert rows.all() == []
    finally:
        await admin.dispose()


async def test_pg_dump_failure_is_reported(database_url: str, tmp_path: Path) -> None:
    broken = make_url(database_url).set(database="does_not_exist")
    with pytest.raises(BackupError, match="pg_dump"):
        await run_pg_dump(broken, tmp_path / "dump")
