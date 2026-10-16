import base64
import math
from datetime import UTC, datetime

import pytest

from scripts.migrate_firestore.firestore_values import (
    decode_document,
    decode_value,
    document_id,
    parse_timestamp,
)


def test_scalars():
    assert decode_value({"stringValue": "salom"}) == "salom"
    assert decode_value({"integerValue": "42"}) == 42
    assert decode_value({"integerValue": "-7"}) == -7
    assert decode_value({"doubleValue": 1.5}) == 1.5
    assert decode_value({"doubleValue": 3}) == 3.0
    assert decode_value({"booleanValue": True}) is True
    assert decode_value({"nullValue": None}) is None
    assert decode_value({"referenceValue": "projects/p/databases/d/documents/users/u"}) == (
        "projects/p/databases/d/documents/users/u"
    )


def test_integer_is_exact_beyond_double_precision():
    assert decode_value({"integerValue": "9007199254740993"}) == 9007199254740993


def test_special_doubles():
    assert math.isnan(decode_value({"doubleValue": "NaN"}))
    assert decode_value({"doubleValue": "Infinity"}) == math.inf
    assert decode_value({"doubleValue": "-Infinity"}) == -math.inf


def test_timestamp_variants():
    expected = datetime(2026, 5, 10, 10, 0, 0, tzinfo=UTC)
    assert parse_timestamp("2026-05-10T10:00:00Z") == expected
    assert parse_timestamp("2026-05-10T10:00:00.123456789Z") == expected.replace(microsecond=123456)
    assert parse_timestamp("2026-05-10T10:00:00.5Z") == expected.replace(microsecond=500000)
    assert parse_timestamp("2026-05-10T15:00:00+05:00") == expected
    assert parse_timestamp("2026-05-10T05:30:00-04:30") == expected
    assert decode_value({"timestampValue": "2026-05-10T10:00:00Z"}).tzinfo is not None


def test_invalid_timestamp():
    with pytest.raises(ValueError):
        parse_timestamp("10 May 2026")


def test_bytes():
    payload = b"\xff\xd8\xff\xe0jpeg"
    encoded = base64.b64encode(payload).decode()
    assert decode_value({"bytesValue": encoded}) == payload


def test_invalid_bytes():
    with pytest.raises(ValueError):
        decode_value({"bytesValue": "not base64!!"})


GRAMS = {"integerValue": "150"}


def test_nested_map_and_array():
    value = {
        "mapValue": {
            "fields": {
                "week": {
                    "mapValue": {
                        "fields": {
                            "1": {
                                "arrayValue": {
                                    "values": [
                                        {
                                            "mapValue": {
                                                "fields": {"grams": {"integerValue": "150"}}
                                            }
                                        },
                                        {"stringValue": "x"},
                                    ]
                                }
                            }
                        }
                    }
                },
                "empty": {"arrayValue": {}},
                "emptyMap": {"mapValue": {}},
            }
        }
    }
    assert decode_value(value) == {
        "week": {"1": [{"grams": 150}, "x"]},
        "empty": [],
        "emptyMap": {},
    }


def test_geo_point():
    assert decode_value({"geoPointValue": {"latitude": 41.3, "longitude": 69.2}}) == {
        "latitude": 41.3,
        "longitude": 69.2,
    }


def test_unknown_and_malformed_values():
    with pytest.raises(ValueError):
        decode_value({"mysteryValue": 1})
    with pytest.raises(ValueError):
        decode_value({})
    with pytest.raises(ValueError):
        decode_value({"stringValue": "a", "integerValue": "1"})


def test_decode_document():
    document = {
        "name": "projects/p/databases/(default)/documents/users/abc123",
        "fields": {
            "name": {"stringValue": "Ali"},
            "age": {"integerValue": "30"},
            "createdAt": {"integerValue": "1700000000000"},
        },
        "createTime": "2026-01-01T00:00:00Z",
    }
    assert decode_document(document) == {
        "_id": "abc123",
        "name": "Ali",
        "age": 30,
        "createdAt": 1700000000000,
    }


def test_decode_document_without_fields():
    assert decode_document({"name": "projects/p/databases/(default)/documents/users/u1"}) == {
        "_id": "u1"
    }


def test_document_id_from_nested_path():
    assert document_id("projects/p/databases/(default)/documents/users/u1/days/2026-05-10") == (
        "2026-05-10"
    )
