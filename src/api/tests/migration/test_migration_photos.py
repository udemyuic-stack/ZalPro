from sqlalchemy import func, select

from scripts.migrate_firestore.load import load_tables
from scripts.migrate_firestore.photos import upload_photos
from scripts.migrate_firestore.transform import transform
from tests.migration.support import FakePhotoStore, sample_source
from tests.migration.test_transform import NOW, SENTINEL, auth_record
from zalpro_api.models import Photo

PAYLOAD = b"12345678"


async def no_sleep(seconds: float) -> None:
    return None


async def prepare(app, tmp_path, write_file=True):
    result = transform(sample_source(), {"u1": auth_record("u1")}, SENTINEL, NOW)
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    (row,) = result.tables["photos"]
    if write_file:
        target = tmp_path / row["_file"]
        target.parent.mkdir(parents=True)
        target.write_bytes(PAYLOAD)
    return result.tables["photos"]


async def count(app):
    async with app.state.engine.connect() as connection:
        return (await connection.execute(select(func.count()).select_from(Photo))).scalar_one()


async def test_uploads_then_inserts_row(app, tmp_path):
    rows = await prepare(app, tmp_path)
    store = FakePhotoStore()
    result = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep
    )
    assert (result.uploaded, result.skipped, result.inserted, result.failed) == (1, 0, 1, [])
    assert store.objects[rows[0]["key"]] == PAYLOAD
    assert await count(app) == 1


async def test_rerun_skips_uploaded_and_does_not_duplicate(app, tmp_path):
    rows = await prepare(app, tmp_path)
    store = FakePhotoStore()
    await upload_photos(app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep)
    again = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep
    )
    assert (again.uploaded, again.skipped, again.inserted) == (0, 1, 0)
    assert store.puts == 1
    assert await count(app) == 1


async def test_failed_upload_inserts_no_row(app, tmp_path):
    rows = await prepare(app, tmp_path)
    store = FakePhotoStore()
    store.fail_puts = 10
    result = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep
    )
    assert result.failed == [(str(rows[0]["id"]), "upload_failed:ConnectionError")]
    assert await count(app) == 0


async def test_transient_failure_is_retried(app, tmp_path):
    rows = await prepare(app, tmp_path)
    store = FakePhotoStore()
    store.fail_puts = 2
    result = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep
    )
    assert result.uploaded == 1
    assert await count(app) == 1


async def test_truncated_object_fails_verification(app, tmp_path):
    rows = await prepare(app, tmp_path)
    store = FakePhotoStore()
    store.truncate = True
    result = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep
    )
    assert result.failed[0][1] == "verify_failed"
    assert await count(app) == 0


async def test_missing_file_and_size_mismatch(app, tmp_path):
    rows = await prepare(app, tmp_path, write_file=False)
    store = FakePhotoStore()
    missing = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep
    )
    assert missing.failed[0][1] == "file_missing"
    target = tmp_path / rows[0]["_file"]
    target.parent.mkdir(parents=True)
    target.write_bytes(b"short")
    mismatch = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=False, sleep=no_sleep
    )
    assert mismatch.failed[0][1] == "size_mismatch"
    assert store.puts == 0


async def test_dry_run_touches_nothing(app, tmp_path):
    rows = await prepare(app, tmp_path)
    store = FakePhotoStore()
    result = await upload_photos(
        app.state.engine, store, rows, tmp_path, dry_run=True, sleep=no_sleep
    )
    assert result.uploaded == 1
    assert store.puts == 0
    assert await count(app) == 0
