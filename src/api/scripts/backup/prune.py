from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from scripts.backup.dump import parse_moment
from scripts.backup.errors import BackupError
from scripts.backup.store import BackupStore

KEEP_DAYS = 7
KEEP_WEEKS = 4
KEEP_MONTHS = 6
MAX_AGE = timedelta(hours=36)


@dataclass(frozen=True)
class PruneResult:
    kept: list[str]
    deleted: list[str]
    latest: datetime


Bucket = Callable[[datetime], tuple[int, ...]]


def _newest_per_bucket(moments: dict[str, datetime], bucket: Bucket, limit: int) -> set[str]:
    newest: dict[tuple[int, ...], tuple[datetime, str]] = {}
    for key, moment in moments.items():
        name = bucket(moment)
        if name not in newest or moment > newest[name][0]:
            newest[name] = (moment, key)
    recent = sorted(newest, reverse=True)[:limit]
    return {newest[name][1] for name in recent}


def select_keep(moments: dict[str, datetime]) -> set[str]:
    if not moments:
        return set()
    keep = _newest_per_bucket(moments, lambda m: (m.year, m.month, m.day), KEEP_DAYS)
    keep |= _newest_per_bucket(moments, lambda m: tuple(m.isocalendar())[:2], KEEP_WEEKS)
    keep |= _newest_per_bucket(moments, lambda m: (m.year, m.month), KEEP_MONTHS)
    keep.add(max(moments, key=lambda key: moments[key]))
    return keep


async def prune(
    store: BackupStore, prefix: str, now: datetime | None = None, max_age: timedelta = MAX_AGE
) -> PruneResult:
    moments = {
        item.key: moment
        for item in await store.list_objects(f"{prefix}/daily/")
        if (moment := parse_moment(item.key)) is not None
    }
    if not moments:
        raise BackupError("no backups found")
    keep = select_keep(moments)
    doomed = sorted(key for key in moments if key not in keep)
    if doomed:
        await store.delete(doomed)
    latest = max(moments.values())
    if (now or datetime.now(UTC)) - latest > max_age:
        raise BackupError(f"latest backup is stale: {latest.isoformat()}")
    return PruneResult(kept=sorted(keep), deleted=doomed, latest=latest)
