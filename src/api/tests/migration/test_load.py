import pytest
from sqlalchemy import func, select, text
from sqlalchemy.exc import DBAPIError

from scripts.migrate_firestore.load import TargetNotEmptyError, load_tables
from scripts.migrate_firestore.transform import transform
from tests.migration.support import sample_source
from tests.migration.test_transform import NOW, SENTINEL, auth_record
from zalpro_api.models import Order, Trainer, User


def build():
    auth = {"u1": auth_record("u1"), "t1": auth_record("t1")}
    return transform(sample_source(), auth, SENTINEL, NOW)


async def scalar(engine, statement):
    async with engine.connect() as connection:
        return (await connection.execute(statement)).scalar_one()


async def test_loads_every_table(app):
    result = build()
    loaded = await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    assert loaded["users"] == 2
    assert loaded["orders"] == 2
    assert loaded["memberships"] == 1
    assert await scalar(app.state.engine, select(func.count()).select_from(User)) == 2
    assert await scalar(app.state.engine, select(func.count()).select_from(Trainer)) == 1
    total = await scalar(app.state.engine, select(func.sum(Order.price * Order.qty)))
    assert total == 2500


async def test_trainer_link_set_in_second_pass(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    trainer = await scalar(app.state.engine, select(User.trainer_id).where(User.id == "u1"))
    assert trainer == "t1"


async def test_dry_run_rolls_back(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=True)
    assert await scalar(app.state.engine, select(func.count()).select_from(User)) == 0


async def test_non_empty_target_refused_without_replace(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    with pytest.raises(TargetNotEmptyError) as error:
        await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    assert error.value.counts["users"] == 2


async def test_replace_reload_is_idempotent(app):
    result = build()
    await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    await load_tables(app.state.engine, result.tables, replace=True, dry_run=False)
    assert await scalar(app.state.engine, select(func.count()).select_from(User)) == 2
    assert await scalar(app.state.engine, text("select count(*) from messages")) == 2


async def test_failure_leaves_database_unchanged(app):
    result = build()
    result.tables["orders"][0]["status"] = "bogus"
    with pytest.raises(DBAPIError):
        await load_tables(app.state.engine, result.tables, replace=False, dry_run=False)
    assert await scalar(app.state.engine, select(func.count()).select_from(User)) == 0
