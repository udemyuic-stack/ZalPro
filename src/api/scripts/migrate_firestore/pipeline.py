import secrets
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from sqlalchemy.ext.asyncio import AsyncEngine

from scripts.migrate_firestore.authexport import load_auth_export
from scripts.migrate_firestore.load import load_tables
from scripts.migrate_firestore.photos import PhotoResult, PhotoStore, upload_photos
from scripts.migrate_firestore.report import write_json
from scripts.migrate_firestore.source import load_source
from scripts.migrate_firestore.transform import Transformed, transform
from scripts.migrate_firestore.verify import VerifyReport, verify_target
from zalpro_api.core.security import hash_password


@dataclass
class Summary:
    ok: bool
    lines: list[str]


async def prepare(directory: Path, auth_path: Path) -> Transformed:
    sentinel = await hash_password(secrets.token_urlsafe(32))
    auth = load_auth_export(auth_path)
    return transform(load_source(directory), auth, sentinel, datetime.now(UTC))


def transform_report(result: Transformed) -> dict[str, Any]:
    return {
        "source_counts": result.source_counts,
        "output_counts": {name: len(rows) for name, rows in result.tables.items()},
        **result.findings.to_json(),
    }


async def run_load(
    engine: AsyncEngine,
    directory: Path,
    result: Transformed,
    *,
    replace: bool,
    apply: bool,
) -> Summary:
    write_json(directory / "report-transform.json", transform_report(result))
    loaded = await load_tables(engine, result.tables, replace=replace, dry_run=not apply)
    mode = "applied" if apply else "dry-run (rolled back)"
    lines = [f"load {mode}"]
    lines += [f"  {name}: {count}" for name, count in loaded.items()]
    rejects = result.findings.reject_counts()
    lines += [f"  rejected {table}: {reasons}" for table, reasons in rejects.items()]
    return Summary(True, lines)


async def run_photos(
    engine: AsyncEngine,
    store: PhotoStore,
    directory: Path,
    result: Transformed,
    *,
    apply: bool,
) -> Summary:
    outcome: PhotoResult = await upload_photos(
        engine, store, result.tables["photos"], directory, dry_run=not apply
    )
    write_json(
        directory / "report-photos.json",
        {
            "uploaded": outcome.uploaded,
            "skipped": outcome.skipped,
            "inserted": outcome.inserted,
            "failed": [{"id": ident, "reason": reason} for ident, reason in outcome.failed],
        },
    )
    mode = "applied" if apply else "dry-run"
    line = (
        f"photos {mode}: uploaded={outcome.uploaded} skipped={outcome.skipped} "
        f"inserted={outcome.inserted} failed={len(outcome.failed)}"
    )
    return Summary(not outcome.failed, [line])


async def run_verify(
    engine: AsyncEngine, store: PhotoStore | None, directory: Path, result: Transformed
) -> Summary:
    report: VerifyReport = await verify_target(engine, result, store)
    write_json(directory / "report-verify.json", report.to_json())
    lines = [f"verify {'OK' if report.ok else 'FAILED'}"]
    lines += [f"  problem: {item}" for item in report.problems]
    lines += [f"  warning: {item}" for item in report.warnings]
    return Summary(report.ok, lines)
