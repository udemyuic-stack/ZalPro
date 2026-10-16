import argparse
import asyncio
import os
import sys
from datetime import UTC, datetime
from pathlib import Path

import httpx

from scripts.migrate_firestore.extract import FirestoreReader, extract_all
from scripts.migrate_firestore.load import TargetNotEmptyError
from scripts.migrate_firestore.photos import R2PhotoStore
from scripts.migrate_firestore.pipeline import (
    Summary,
    prepare,
    run_load,
    run_photos,
    run_verify,
)
from zalpro_api.core.config import Settings
from zalpro_api.db.session import create_engine

COMMANDS = ("extract", "load", "photos", "verify", "all")


class DryRunStore:
    async def size_of(self, key: str) -> int | None:
        return None

    async def put(self, key: str, data: bytes) -> None:
        raise RuntimeError("dry run must not upload")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(prog="python -m scripts.migrate_firestore")
    root.add_argument("command", choices=COMMANDS)
    root.add_argument("--out", type=Path, default=Path("migration_out"))
    root.add_argument("--auth-export", type=Path)
    root.add_argument("--target-db")
    root.add_argument("--replace", action="store_true")
    root.add_argument("--apply", action="store_true")
    root.add_argument("--dry-run", action="store_true")
    root.add_argument("--check-objects", action="store_true")
    return root


def target_url(value: str | None) -> str:
    url = value or os.environ.get("DATABASE_URL", "")
    if not url:
        raise SystemExit("target database missing: pass --target-db or set DATABASE_URL")
    return url


def r2_store() -> R2PhotoStore:
    settings = Settings()
    if not settings.r2_configured:
        raise SystemExit("R2 settings are not configured")
    return R2PhotoStore(settings)


def required(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise SystemExit(f"environment variable {name} is required")
    return value


def run_extract(out: Path) -> Summary:
    with httpx.Client(timeout=60) as client:
        reader = FirestoreReader.sign_in(
            client, required("FIREBASE_API_KEY"), required("OWNER_EMAIL"), required("OWNER_PASS")
        )
        manifest = extract_all(reader, out, datetime.now(UTC).isoformat())
    lines = ["extract done"] + [f"  {name}: {count}" for name, count in manifest.counts.items()]
    return Summary(True, lines)


async def run_database(args: argparse.Namespace) -> Summary:
    if args.auth_export is None:
        raise SystemExit("--auth-export is required")
    if args.apply and args.dry_run:
        raise SystemExit("--apply and --dry-run are mutually exclusive")
    result = await prepare(args.out, args.auth_export)
    engine = create_engine(target_url(args.target_db))
    store = r2_store() if args.command in ("photos", "all") and args.apply else None
    verify_store = r2_store() if args.check_objects else None
    lines: list[str] = []
    ok = True
    try:
        if args.command in ("load", "all"):
            summary = await run_load(
                engine, args.out, result, replace=args.replace, apply=args.apply
            )
            lines += summary.lines
            ok = ok and summary.ok
        if args.command in ("photos", "all"):
            summary = await run_photos(
                engine, store or DryRunStore(), args.out, result, apply=args.apply
            )
            lines += summary.lines
            ok = ok and summary.ok
        if args.command == "verify" or (args.command == "all" and args.apply):
            summary = await run_verify(engine, verify_store, args.out, result)
            lines += summary.lines
            ok = ok and summary.ok
    except TargetNotEmptyError as error:
        return Summary(False, [str(error), "pass --replace to overwrite"])
    finally:
        await engine.dispose()
    return Summary(ok, lines)


def main() -> int:
    args = parser().parse_args()
    if args.command == "extract":
        summary = run_extract(args.out)
    else:
        summary = asyncio.run(run_database(args))
    print("\n".join(summary.lines))
    return 0 if summary.ok else 1


if __name__ == "__main__":
    sys.exit(main())
