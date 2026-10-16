import argparse
import asyncio
import json
import logging
import sys

from scripts.backup.dump import make_backup, ping
from scripts.backup.errors import BackupError
from scripts.backup.prune import prune
from scripts.backup.restore_check import restore_check
from scripts.backup.store import BackupStore, R2BackupStore
from zalpro_api.core.config import Settings

logger = logging.getLogger("backup")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m scripts.backup")
    parser.add_argument("command", choices=["dump", "prune", "restore-check"])
    return parser


def build_store(settings: Settings) -> BackupStore:
    if not settings.backup_configured:
        raise BackupError("BACKUP_R2_* is not configured")
    return R2BackupStore(settings)


async def run(command: str, settings: Settings, store: BackupStore) -> dict[str, object]:
    if command == "dump":
        result = await make_backup(settings.database_url, store, settings.backup_prefix)
        pruned = await prune(store, settings.backup_prefix)
        return {
            "key": result.key,
            "size": result.size,
            "kept": len(pruned.kept),
            "deleted": len(pruned.deleted),
        }
    if command == "prune":
        pruned = await prune(store, settings.backup_prefix)
        return {"kept": len(pruned.kept), "deleted": len(pruned.deleted)}
    counts = await restore_check(settings.database_url, store, settings.backup_prefix)
    return {"tables": counts}


async def main(argv: list[str]) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    command = build_parser().parse_args(argv).command
    settings = Settings()
    ok = False
    try:
        report = await run(command, settings, build_store(settings))
        ok = True
        print(json.dumps(report, sort_keys=True))
        return 0
    except BackupError as error:
        logger.error("%s", error)
        return 1
    finally:
        if command == "dump":
            await ping(settings.backup_ping_url, ok)


if __name__ == "__main__":
    sys.exit(asyncio.run(main(sys.argv[1:])))
