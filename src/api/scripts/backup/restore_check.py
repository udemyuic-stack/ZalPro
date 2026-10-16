import secrets
import tempfile
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import create_async_engine

from scripts.backup.dump import (
    connection_args,
    connection_env,
    parse_moment,
    run_command,
)
from scripts.backup.errors import BackupError
from scripts.backup.store import BackupStore

TABLES_SQL = text(
    "select table_name from information_schema.tables "
    "where table_schema = 'public' and table_type = 'BASE TABLE' order by table_name"
)


async def latest_key(store: BackupStore, prefix: str) -> str:
    moments = {
        item.key: moment
        for item in await store.list_objects(f"{prefix}/daily/")
        if (moment := parse_moment(item.key)) is not None
    }
    if not moments:
        raise BackupError("no backups found")
    return max(moments, key=lambda key: moments[key])


async def table_counts(database_url: str) -> dict[str, int]:
    engine = create_async_engine(database_url)
    try:
        async with engine.connect() as connection:
            names = [row[0] for row in await connection.execute(TABLES_SQL)]
            return {
                name: int(
                    (await connection.execute(text(f'select count(*) from "{name}"'))).scalar_one()
                )
                for name in names
            }
    finally:
        await engine.dispose()


async def restore_check(database_url: str, store: BackupStore, prefix: str) -> dict[str, int]:
    url = make_url(database_url)
    scratch = f"zalpro_restore_check_{secrets.token_hex(4)}"
    admin = create_async_engine(url.set(database="postgres"), isolation_level="AUTOCOMMIT")
    created = False
    try:
        key = await latest_key(store, prefix)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dump"
            await store.download(key, path)
            async with admin.connect() as connection:
                await connection.execute(text(f'create database "{scratch}"'))
            created = True
            await run_command(
                [
                    "pg_restore",
                    "--no-owner",
                    "--exit-on-error",
                    *connection_args(url),
                    "-d",
                    scratch,
                    str(path),
                ],
                connection_env(url),
            )
        counts = await table_counts(url.set(database=scratch).render_as_string(hide_password=False))
        if not counts:
            raise BackupError("restored database has no tables")
        if counts.get("alembic_version", 0) < 1:
            raise BackupError("restored database has no alembic_version row")
        return counts
    finally:
        if created:
            async with admin.connect() as connection:
                await connection.execute(text(f'drop database if exists "{scratch}" with (force)'))
        await admin.dispose()
