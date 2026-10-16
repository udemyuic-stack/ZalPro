from sqlalchemy import text

from scripts.migrate_firestore.load import load_tables
from scripts.migrate_firestore.transform import transform
from scripts.migrate_firestore.verify import verify_target
from tests.migration.support import FakePhotoStore, sample_source
from tests.migration.test_transform import NOW, SENTINEL, auth_record


def build():
    auth = {"u1": auth_record("u1"), "t1": auth_record("t1", algo="bcrypt", salt=None)}
    return transform(sample_source(), auth, SENTINEL, NOW)


async def test_clean_load_verifies(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    report = await verify_target(app.state.engine, result, None)
    assert report.ok, report.problems
    assert report.tables["users"] == {"source": 3, "loaded": 2, "rejected": 1}
    assert report.tables["orders"] == {"source": 3, "loaded": 2, "rejected": 1}
    assert report.checks["orders_total"] == {"expected": 2500, "actual": 2500}
    assert report.checks["legacy_hash_users"] == {"expected": 2, "actual": 2}
    assert report.warnings == ["bcrypt_users_need_reset:1"]


async def test_count_mismatch_detected(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    async with app.state.engine.begin() as connection:
        await connection.execute(text("delete from foods"))
    report = await verify_target(app.state.engine, result, None)
    assert "count_mismatch:foods:1!=0+0" in report.problems


async def test_orders_total_and_orphans_detected(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    async with app.state.engine.begin() as connection:
        await connection.execute(text("update orders set qty = qty + 1 where id = 'o1'"))
        await connection.execute(text("update reminders set client_id = 'ghost'"))
    report = await verify_target(app.state.engine, result, None)
    assert "orders_total_mismatch" in report.problems
    assert "orphans:reminders.client_id:1" in report.warnings


async def test_missing_photo_objects_detected(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    row = result.tables["photos"][0]
    async with app.state.engine.begin() as connection:
        await connection.execute(
            text(
                "insert into photos (id, user_id, key, taken_at, weight, size) "
                "values (:id, :user_id, :key, :taken_at, :weight, :size)"
            ),
            {k: v for k, v in row.items() if not k.startswith("_")},
        )
    store = FakePhotoStore()
    report = await verify_target(app.state.engine, result, store)
    assert "photo_objects_missing:1" in report.problems
    store.objects[row["key"]] = b"x" * row["size"]
    report = await verify_target(app.state.engine, result, store)
    assert report.checks["photo_objects"] == {"checked": 1, "missing": 0}


async def test_photo_source_accounting_checked(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    result.source_counts["photos"] += 1
    report = await verify_target(app.state.engine, result, None)
    assert any(item.startswith("count_mismatch:photos") for item in report.problems)
