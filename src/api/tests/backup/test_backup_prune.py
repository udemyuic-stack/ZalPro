from datetime import UTC, datetime, timedelta

import pytest

from scripts.backup.dump import backup_key, parse_moment
from scripts.backup.errors import BackupError
from scripts.backup.prune import prune, select_keep
from tests.backup.support import FakeBackupStore

PREFIX = "zalpro"
NOON = timedelta(hours=12)


def moment(year: int, month: int, day: int) -> datetime:
    return datetime(year, month, day, 3, 30, tzinfo=UTC)


def daily_moments(start: datetime, days: int) -> dict[str, datetime]:
    moments = [start + timedelta(days=offset) for offset in range(days)]
    return {backup_key(PREFIX, value): value for value in moments}


def test_key_round_trip() -> None:
    value = datetime(2026, 3, 4, 3, 30, 15, tzinfo=UTC)
    key = backup_key(PREFIX, value)
    assert key == "zalpro/daily/2026/zalpro-20260304T033015Z.dump"
    assert parse_moment(key) == value


def test_parse_ignores_foreign_names() -> None:
    assert parse_moment("zalpro/daily/2026/notes.txt") is None
    assert parse_moment("zalpro/daily/2026/zalpro-bad.dump") is None


def test_select_keep_empty() -> None:
    assert select_keep({}) == set()


def test_seven_daily_kept_in_a_single_week_window() -> None:
    moments = daily_moments(moment(2026, 3, 2), 7)
    assert select_keep(moments) == set(moments)


def test_old_daily_beyond_window_is_dropped_when_not_a_survivor() -> None:
    moments = daily_moments(moment(2026, 3, 1), 10)
    keep = select_keep(moments)
    second = backup_key(PREFIX, moment(2026, 3, 2))
    newest = backup_key(PREFIX, moment(2026, 3, 10))
    assert newest in keep
    assert second not in keep


def test_weekly_and_monthly_survivors_from_a_long_history() -> None:
    moments = daily_moments(moment(2025, 6, 1), 400)
    keep = select_keep(moments)
    last_day = max(moments.values())
    recent_days = {value for value in moments.values() if last_day - value < timedelta(days=7)}
    assert recent_days == {parse_moment(key) for key in keep if parse_moment(key) in recent_days}
    assert len(keep) <= 7 + 4 + 6
    assert len(keep) >= 7 + 4
    months = {(parse_moment(key).year, parse_moment(key).month) for key in keep}
    assert len(months) >= 6


def test_latest_is_always_kept() -> None:
    moments = daily_moments(moment(2024, 1, 1), 900)
    latest = max(moments, key=lambda key: moments[key])
    assert latest in select_keep(moments)


def test_two_dumps_same_day_keep_the_newest() -> None:
    early = datetime(2026, 3, 1, 1, 0, tzinfo=UTC)
    late = datetime(2026, 3, 1, 22, 0, tzinfo=UTC)
    moments = {backup_key(PREFIX, early): early, backup_key(PREFIX, late): late}
    assert select_keep(moments) == {backup_key(PREFIX, late)}


async def test_prune_deletes_only_unselected_and_never_foreign_keys() -> None:
    store = FakeBackupStore()
    moments = daily_moments(moment(2025, 6, 1), 400)
    for key in moments:
        store.seed(key)
    store.seed("zalpro/daily/2025/readme.txt")
    store.seed("other/daily/2025/zalpro-20250601T033000Z.dump")
    now = max(moments.values()) + NOON
    result = await prune(store, PREFIX, now=now)
    assert set(result.deleted) == set(moments) - set(result.kept)
    assert "zalpro/daily/2025/readme.txt" in store.blobs
    assert "other/daily/2025/zalpro-20250601T033000Z.dump" in store.blobs
    assert result.latest == max(moments.values())
    assert set(store.blobs) >= set(result.kept)


async def test_prune_fails_on_empty_bucket() -> None:
    with pytest.raises(BackupError, match="no backups"):
        await prune(FakeBackupStore(), PREFIX)


async def test_prune_fails_when_latest_is_stale_but_keeps_it() -> None:
    store = FakeBackupStore()
    value = moment(2026, 3, 1)
    key = backup_key(PREFIX, value)
    store.seed(key)
    with pytest.raises(BackupError, match="stale"):
        await prune(store, PREFIX, now=value + timedelta(hours=37))
    assert key in store.blobs


async def test_prune_accepts_latest_within_max_age() -> None:
    store = FakeBackupStore()
    value = moment(2026, 3, 1)
    store.seed(backup_key(PREFIX, value))
    result = await prune(store, PREFIX, now=value + timedelta(hours=35))
    assert result.deleted == []
