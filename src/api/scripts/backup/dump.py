import asyncio
import logging
import os
import re
import tempfile
import urllib.request
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy.engine import URL, make_url

from scripts.backup.errors import BackupError
from scripts.backup.store import BackupStore

logger = logging.getLogger(__name__)

STAMP_FORMAT = "%Y%m%dT%H%M%SZ"
NAME_PATTERN = re.compile(r"/zalpro-(\d{8}T\d{6}Z)\.dump$")
PING_TIMEOUT_SECONDS = 10

Runner = Callable[[URL, Path], Awaitable[None]]


@dataclass(frozen=True)
class BackupResult:
    key: str
    size: int


def backup_key(prefix: str, moment: datetime) -> str:
    return f"{prefix}/daily/{moment:%Y}/zalpro-{moment.strftime(STAMP_FORMAT)}.dump"


def parse_moment(key: str) -> datetime | None:
    match = NAME_PATTERN.search(key)
    if match is None:
        return None
    return datetime.strptime(match.group(1), STAMP_FORMAT).replace(tzinfo=UTC)


def connection_args(url: URL) -> list[str]:
    return [
        "-h",
        url.host or "localhost",
        "-p",
        str(url.port or 5432),
        "-U",
        url.username or "postgres",
    ]


def connection_env(url: URL) -> dict[str, str]:
    return {**os.environ, "PGPASSWORD": url.password or ""}


async def run_command(args: list[str], env: dict[str, str]) -> None:
    process = await asyncio.create_subprocess_exec(
        *args, env=env, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE
    )
    _, stderr = await process.communicate()
    if process.returncode != 0:
        raise BackupError(f"{args[0]} failed ({process.returncode}): {stderr.decode().strip()}")


async def run_pg_dump(url: URL, path: Path) -> None:
    args = [
        "pg_dump",
        "-Fc",
        "--no-owner",
        "--no-privileges",
        *connection_args(url),
        "-d",
        url.database or "",
        "-f",
        str(path),
    ]
    await run_command(args, connection_env(url))


async def make_backup(
    database_url: str,
    store: BackupStore,
    prefix: str,
    moment: datetime | None = None,
    runner: Runner = run_pg_dump,
) -> BackupResult:
    key = backup_key(prefix, moment or datetime.now(UTC))
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "dump"
        await runner(make_url(database_url), path)
        size = path.stat().st_size if path.exists() else 0
        if size == 0:
            raise BackupError("pg_dump produced an empty file")
        await store.upload(path, key)
    remote = await store.size_of(key)
    if remote != size:
        raise BackupError(f"uploaded size mismatch for {key}: local={size} remote={remote}")
    return BackupResult(key=key, size=size)


def _fetch(url: str) -> None:
    with urllib.request.urlopen(url, timeout=PING_TIMEOUT_SECONDS):
        pass


async def ping(base_url: str, ok: bool) -> None:
    if not base_url:
        return
    url = base_url if ok else f"{base_url.rstrip('/')}/fail"
    try:
        await asyncio.to_thread(_fetch, url)
    except OSError:
        logger.warning("backup ping failed", exc_info=True)
