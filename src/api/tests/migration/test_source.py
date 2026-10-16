from datetime import UTC, datetime

from scripts.migrate_firestore.extract import extract_all
from scripts.migrate_firestore.source import load_source
from tests.migration.support import FakeFirestore, integer, make_doc, photo_doc, string
from tests.migration.test_extract import Clock, make_reader


def test_extract_output_round_trips_into_transform_input(tmp_path):
    fake = FakeFirestore(
        {
            "users": [make_doc("users/u1", {"name": string("Ali"), "age": integer(30)})],
            "users/u1/photos": [photo_doc("users/u1/photos/p1", b"jpeg")],
            "chats/u1/messages": [make_doc("chats/u1/messages/m1", {"text": string("hi")})],
        }
    )
    extract_all(make_reader(fake, Clock()), tmp_path, "t")
    source = load_source(tmp_path)
    ((_, user),) = source["users"]
    assert user["_id"] == "u1"
    assert user["age"] == 30
    assert user["_create_time"] == datetime(2026, 1, 1, tzinfo=UTC)
    ((parent, photo),) = source["photos"]
    assert parent == "u1"
    assert photo["photoBytes"] == 4
    assert source["chatMessages"][0][1]["text"] == "hi"
    assert source["gyms"] == []
