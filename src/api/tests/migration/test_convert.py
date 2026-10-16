from datetime import UTC, date, datetime

from scripts.migrate_firestore.convert import (
    boolean,
    day_from_key,
    int_list,
    integer,
    jsonable,
    number,
    optional_integer,
    optional_number,
    stable_uuid,
    string_list,
    text,
    when,
)


def test_stable_uuid_is_deterministic_and_distinct():
    assert stable_uuid("weight", "u1", "a") == stable_uuid("weight", "u1", "a")
    assert stable_uuid("weight", "u1", "a") != stable_uuid("weight", "u1", "b")
    assert stable_uuid("weight", "u1", "a") != stable_uuid("photo", "u1", "a")


def test_text_defaults_and_coercion():
    assert text(None) == ""
    assert text(None, "x") == "x"
    assert text(5) == "5"
    assert text("abc") == "abc"


def test_numbers():
    assert integer("7") == 7
    assert integer(None, 3) == 3
    assert integer("zz", 4) == 4
    assert number("2.5") == 2.5
    assert number(None) == 0.0
    assert optional_number(None) is None
    assert optional_number(3) == 3.0
    assert optional_integer(None) is None
    assert optional_integer(4.0) == 4


def test_boolean():
    assert boolean(True) is True
    assert boolean(None, True) is True
    assert boolean(None) is False


def test_when_accepts_datetime_and_epoch():
    moment = datetime(2026, 1, 2, 3, 4, 5, tzinfo=UTC)
    assert when(moment) == moment
    assert when(moment.timestamp() * 1000) == moment
    assert when(moment.timestamp()) == moment
    assert when(None) is None
    assert when("nonsense") is None


def test_day_from_key():
    assert day_from_key("2026-05-10") == date(2026, 5, 10)
    assert day_from_key("2026-13-40") is None
    assert day_from_key("x") is None


def test_lists():
    assert string_list(["a", 1]) == ["a", "1"]
    assert string_list(None) == []
    assert int_list([1, "2", "x"]) == [1, 2]
    assert int_list("nope") == []


def test_jsonable_converts_datetimes():
    moment = datetime(2026, 1, 2, tzinfo=UTC)
    assert jsonable({"at": moment, "n": [1, {"d": moment}]}) == {
        "at": moment.isoformat(),
        "n": [1, {"d": moment.isoformat()}],
    }
