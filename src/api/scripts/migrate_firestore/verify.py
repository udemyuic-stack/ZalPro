from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncEngine

from scripts.migrate_firestore.load import LOAD_ORDER
from scripts.migrate_firestore.photos import PhotoStore
from scripts.migrate_firestore.transform import Transformed
from zalpro_api.models import Photo, metadata

SOURCE_KIND = {
    "products": "shop",
    "messages": "chatMessages",
}
DERIVED_TABLES = frozenset({"trainers", "memberships"})
SOFT_REFERENCES = {
    "orders.client_id": (
        "select count(*) from orders o "
        "where not exists (select 1 from users u where u.id = o.client_id)"
    ),
    "reminders.client_id": (
        "select count(*) from reminders r "
        "where not exists (select 1 from users u where u.id = r.client_id)"
    ),
    "messages.sender_id": (
        "select count(*) from messages m "
        "where not exists (select 1 from users u where u.id = m.sender_id)"
    ),
    "users.plan_id": (
        "select count(*) from users u where u.plan_id is not null "
        "and not exists (select 1 from plans p where p.id = u.plan_id)"
    ),
}
PHOTO_TABLE = "photos"


@dataclass
class VerifyReport:
    tables: dict[str, dict[str, Any]] = field(default_factory=dict)
    checks: dict[str, Any] = field(default_factory=dict)
    problems: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.problems

    def to_json(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "tables": self.tables,
            "checks": self.checks,
            "problems": self.problems,
            "warnings": self.warnings,
        }


async def scalar(engine: AsyncEngine, statement: Any) -> Any:
    async with engine.connect() as connection:
        return (await connection.execute(statement)).scalar_one()


async def verify_counts(engine: AsyncEngine, result: Transformed, report: VerifyReport) -> None:
    rejected = result.findings.reject_counts()
    for name in (*LOAD_ORDER, PHOTO_TABLE):
        loaded = await scalar(engine, select(func.count()).select_from(metadata.tables[name]))
        source = result.source_counts.get(SOURCE_KIND.get(name, name), 0)
        dropped = sum(rejected.get(name, {}).values())
        entry = {"source": source, "loaded": loaded, "rejected": dropped}
        report.tables[name] = entry
        if name in DERIVED_TABLES:
            entry["derived"] = True
        elif name == PHOTO_TABLE:
            entry["pending_upload"] = len(result.tables[name]) - loaded
            if source != len(result.tables[name]) + dropped:
                report.problems.append(f"count_mismatch:{name}:{source}!=transformed+{dropped}")
        elif source != loaded + dropped:
            report.problems.append(f"count_mismatch:{name}:{source}!={loaded}+{dropped}")


async def verify_orders(engine: AsyncEngine, result: Transformed, report: VerifyReport) -> None:
    expected = sum(row["price"] * row["qty"] for row in result.tables["orders"])
    actual = await scalar(engine, text("select coalesce(sum(price * qty), 0) from orders"))
    report.checks["orders_total"] = {"expected": expected, "actual": int(actual)}
    if expected != int(actual):
        report.problems.append("orders_total_mismatch")


async def verify_references(engine: AsyncEngine, report: VerifyReport) -> None:
    for name, query in SOFT_REFERENCES.items():
        orphans = await scalar(engine, text(query))
        report.checks[f"orphans.{name}"] = orphans
        if orphans:
            report.warnings.append(f"orphans:{name}:{orphans}")


async def verify_legacy(engine: AsyncEngine, result: Transformed, report: VerifyReport) -> None:
    expected = sum(1 for row in result.tables["users"] if row["legacy_hash"])
    actual = await scalar(engine, text("select count(*) from users where legacy_hash is not null"))
    report.checks["legacy_hash_users"] = {"expected": expected, "actual": actual}
    if expected != actual:
        report.problems.append("legacy_hash_mismatch")
    bcrypt = await scalar(engine, text("select count(*) from users where legacy_algo = 'bcrypt'"))
    report.checks["bcrypt_users"] = bcrypt
    if bcrypt:
        report.warnings.append(f"bcrypt_users_need_reset:{bcrypt}")


async def verify_photos(engine: AsyncEngine, store: PhotoStore | None, report: VerifyReport):
    if store is None:
        return
    table = Photo.__table__
    async with engine.connect() as connection:
        rows = (await connection.execute(select(table.c.key, table.c.size))).all()
    missing = 0
    for key, size in rows:
        if await store.size_of(key) != size:
            missing += 1
    report.checks["photo_objects"] = {"checked": len(rows), "missing": missing}
    if missing:
        report.problems.append(f"photo_objects_missing:{missing}")


async def verify_target(
    engine: AsyncEngine, result: Transformed, store: PhotoStore | None
) -> VerifyReport:
    report = VerifyReport()
    await verify_counts(engine, result, report)
    await verify_orders(engine, result, report)
    await verify_references(engine, report)
    await verify_legacy(engine, result, report)
    await verify_photos(engine, store, report)
    return report
