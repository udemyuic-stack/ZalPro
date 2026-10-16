from collections.abc import Iterator, Sequence
from typing import Any

from sqlalchemy import bindparam, func, select, text, update
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncEngine

from zalpro_api.models import metadata

BATCH_SIZE = 500
LOAD_ORDER = (
    "gyms",
    "users",
    "trainers",
    "ratings",
    "foods",
    "plans",
    "exercises",
    "products",
    "orders",
    "reminders",
    "subscriptions",
    "memberships",
    "weights",
    "days",
    "attendance",
    "messages",
)
GUARDED_TABLES = (*LOAD_ORDER, "photos", "refresh_tokens", "push_tokens")


class TargetNotEmptyError(Exception):
    def __init__(self, counts: dict[str, int]) -> None:
        self.counts = counts
        super().__init__(
            "target database is not empty: "
            + ", ".join(f"{name}={count}" for name, count in counts.items())
        )


def batches(rows: Sequence[dict[str, Any]]) -> Iterator[Sequence[dict[str, Any]]]:
    for start in range(0, len(rows), BATCH_SIZE):
        yield rows[start : start + BATCH_SIZE]


def clean(row: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in row.items() if not key.startswith("_")}


async def insert_rows(connection: AsyncConnection, table: str, rows: Sequence[dict[str, Any]]):
    target = metadata.tables[table]
    for chunk in batches(rows):
        await connection.execute(target.insert(), [clean(row) for row in chunk])
    return len(rows)


async def table_counts(connection: AsyncConnection) -> dict[str, int]:
    counts = {}
    for name in GUARDED_TABLES:
        counts[name] = (
            await connection.execute(select(func.count()).select_from(metadata.tables[name]))
        ).scalar_one()
    return counts


async def purge(connection: AsyncConnection) -> None:
    names = ", ".join(GUARDED_TABLES)
    await connection.execute(text(f"TRUNCATE {names} RESTART IDENTITY CASCADE"))


async def insert_users(connection: AsyncConnection, rows: Sequence[dict[str, Any]]) -> int:
    first_pass = [{**row, "trainer_id": None} for row in rows]
    await insert_rows(connection, "users", first_pass)
    links = [
        {"b_id": row["id"], "b_trainer": row["trainer_id"]} for row in rows if row["trainer_id"]
    ]
    users = metadata.tables["users"]
    statement = (
        update(users)
        .where(users.c.id == bindparam("b_id"))
        .values(trainer_id=bindparam("b_trainer"))
    )
    for chunk in batches(links):
        await connection.execute(statement, list(chunk))
    return len(rows)


async def load_tables(
    engine: AsyncEngine,
    tables: dict[str, list[dict[str, Any]]],
    *,
    replace: bool,
    dry_run: bool,
) -> dict[str, int]:
    async with engine.connect() as connection:
        transaction = await connection.begin()
        try:
            existing = {k: v for k, v in (await table_counts(connection)).items() if v}
            if existing and not replace:
                raise TargetNotEmptyError(existing)
            if existing:
                await purge(connection)
            loaded: dict[str, int] = {}
            for name in LOAD_ORDER:
                rows = tables.get(name, [])
                if name == "users":
                    loaded[name] = await insert_users(connection, rows)
                else:
                    loaded[name] = await insert_rows(connection, name, rows)
        except BaseException:
            await transaction.rollback()
            raise
        if dry_run:
            await transaction.rollback()
        else:
            await transaction.commit()
        return loaded
