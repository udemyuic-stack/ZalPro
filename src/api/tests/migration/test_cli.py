import argparse

from sqlalchemy import text

from scripts.migrate_firestore import __main__ as cli
from scripts.migrate_firestore.extract import extract_all
from tests.migration.seed import auth_export, firestore_seed
from tests.migration.support import FakeFirestore, FakePhotoStore
from tests.migration.test_extract import Clock, make_reader


def arguments(command, out, auth, url, **flags):
    values = {
        "command": command,
        "out": out,
        "auth_export": auth,
        "target_db": url,
        "replace": False,
        "apply": False,
        "dry_run": False,
        "check_objects": False,
    }
    values.update(flags)
    return argparse.Namespace(**values)


def extracted(tmp_path, trainees=3):
    out = tmp_path / "out"
    fake = FakeFirestore(firestore_seed(trainees))
    extract_all(make_reader(fake, Clock()), out, "t")
    uids = ["t1", *[f"u{index}" for index in range(trainees)]]
    return out, auth_export(tmp_path / "auth.json", uids)


async def count(app, table):
    async with app.state.engine.connect() as connection:
        return (await connection.execute(text(f"select count(*) from {table}"))).scalar_one()


async def test_all_dry_run_changes_nothing(app, tmp_path, settings):
    out, auth = extracted(tmp_path)
    url = settings.database_url
    summary = await cli.run_database(arguments("all", out, auth, url))
    assert summary.ok, summary.lines
    assert await count(app, "users") == 0
    assert (out / "report-transform.json").exists()


async def test_all_apply_loads_uploads_and_verifies(app, tmp_path, settings, monkeypatch):
    out, auth = extracted(tmp_path)
    store = FakePhotoStore()
    monkeypatch.setattr(cli, "r2_store", lambda: store)
    url = settings.database_url
    summary = await cli.run_database(arguments("all", out, auth, url, apply=True))
    assert summary.ok, summary.lines
    assert await count(app, "users") == 4
    assert await count(app, "photos") == 3
    assert len(store.objects) == 3
    assert await count(app, "memberships") == 3
    assert (out / "report-verify.json").exists()


async def test_second_apply_without_replace_refused(app, tmp_path, settings, monkeypatch):
    out, auth = extracted(tmp_path)
    monkeypatch.setattr(cli, "r2_store", lambda: FakePhotoStore())
    url = settings.database_url
    await cli.run_database(arguments("load", out, auth, url, apply=True))
    summary = await cli.run_database(arguments("load", out, auth, url, apply=True))
    assert not summary.ok
    assert "not empty" in summary.lines[0]


async def test_reports_do_not_contain_secrets(app, tmp_path, settings, monkeypatch):
    out, auth = extracted(tmp_path)
    monkeypatch.setattr(cli, "r2_store", lambda: FakePhotoStore())
    await cli.run_database(arguments("all", out, auth, settings.database_url, apply=True))
    for report in out.glob("report-*.json"):
        content = report.read_text()
        assert "aGFzaA==" not in content
        assert "c2FsdA==" not in content
        assert "argon2" not in content
