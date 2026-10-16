import json
import stat

import httpx
import pytest

from scripts.migrate_firestore.extract import (
    ExtractError,
    FirestoreReader,
    extract_all,
    read_jsonl,
)
from tests.migration.support import FakeFirestore, integer, make_doc, photo_doc, string


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0
        self.sleeps: list[float] = []

    def time(self) -> float:
        return self.now

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.now += seconds


def make_reader(fake: FakeFirestore, clock: Clock) -> FirestoreReader:
    return FirestoreReader.sign_in(
        fake.client(), "key", "owner@example.test", "pw", clock=clock.time, sleep=clock.sleep
    )


def seed() -> dict:
    users = [
        make_doc("users/u1", {"name": string("Ali"), "age": integer(30)}),
        make_doc("users/u2", {"name": string("Vali")}),
    ]
    return {
        "users": users,
        "gyms": [make_doc("gyms/g1", {"name": string("Diamond")})],
        "users/u1/weights": [make_doc("users/u1/weights/w1", {"weight": {"doubleValue": 80.0}})],
        "users/u1/days": [make_doc("users/u1/days/2026-05-10")],
        "users/u1/photos": [photo_doc("users/u1/photos/p1", b"\xff\xd8jpeg-bytes")],
        "users/u2/subscriptions": [make_doc("users/u2/subscriptions/s1")],
        "chats/u1/messages": [make_doc("chats/u1/messages/m1", {"text": string("salom")})],
    }


def test_pagination_collects_every_page():
    docs = [make_doc(f"orders/o{i}") for i in range(650)]
    fake = FakeFirestore({"orders": docs})
    reader = make_reader(fake, Clock())
    collected = list(reader.documents("orders"))
    assert len(collected) == 650
    assert [d["name"] for d in collected] == [d["name"] for d in docs]
    assert reader.pages == 3
    assert fake.requests[-1].url.params["pageToken"] == "600"


def test_empty_collection_yields_nothing():
    reader = make_reader(FakeFirestore({}), Clock())
    assert list(reader.documents("ratings")) == []


def test_retries_transient_errors_with_backoff():
    fake = FakeFirestore({"gyms": [make_doc("gyms/g1")]})
    fake.fail_with["gyms"] = [503, 429]
    clock = Clock()
    reader = make_reader(fake, clock)
    assert len(list(reader.documents("gyms"))) == 1
    assert clock.sleeps == [1, 2]


def test_gives_up_after_max_attempts():
    fake = FakeFirestore({})
    fake.fail_with["gyms"] = [503] * 10
    reader = make_reader(fake, Clock())
    with pytest.raises(ExtractError, match="attempts"):
        list(reader.documents("gyms"))


def test_permanent_error_raises_immediately():
    fake = FakeFirestore({})
    fake.fail_with["gyms"] = [403]
    reader = make_reader(fake, Clock())
    with pytest.raises(ExtractError, match="HTTP 403"):
        list(reader.documents("gyms"))


def test_unauthorized_refreshes_token_once():
    fake = FakeFirestore({"gyms": [make_doc("gyms/g1")]})
    fake.fail_with["gyms"] = [401]
    reader = make_reader(fake, Clock())
    assert len(list(reader.documents("gyms"))) == 1
    assert fake.token_calls == 1
    assert fake.requests[-1].headers["Authorization"] == "Bearer id-1"


def test_repeated_unauthorized_raises():
    fake = FakeFirestore({})
    fake.fail_with["gyms"] = [401, 401]
    reader = make_reader(fake, Clock())
    with pytest.raises(ExtractError, match="HTTP 401"):
        list(reader.documents("gyms"))


def test_token_refreshed_before_expiry():
    fake = FakeFirestore({"gyms": [make_doc("gyms/g1")]})
    clock = Clock()
    reader = make_reader(fake, clock)
    clock.now += 3600
    list(reader.documents("gyms"))
    assert fake.token_calls == 1


def test_sign_in_failure_does_not_leak_credentials():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(400, json={"error": {"message": "INVALID_PASSWORD secret-pw"}})

    client = httpx.Client(transport=httpx.MockTransport(handler))
    with pytest.raises(ExtractError) as raised:
        FirestoreReader.sign_in(client, "key", "owner@example.test", "secret-pw")
    assert "secret-pw" not in str(raised.value)
    assert "owner@example.test" not in str(raised.value)


def test_extract_all_writes_every_collection(tmp_path):
    fake = FakeFirestore(seed())
    reader = make_reader(fake, Clock())
    manifest = extract_all(reader, tmp_path, "2026-10-15T00:00:00Z")
    assert manifest.counts["users"] == 2
    assert manifest.counts["gyms"] == 1
    assert manifest.counts["exercises"] == 0
    assert manifest.counts["weights"] == 1
    assert manifest.counts["photos"] == 1
    assert manifest.counts["subscriptions"] == 1
    assert manifest.counts["chatMessages"] == 1
    assert manifest.photo_bytes == len(b"\xff\xd8jpeg-bytes")
    on_disk = json.loads((tmp_path / "manifest.json").read_text())
    assert on_disk["counts"] == manifest.counts
    parents = [parent for parent, _ in read_jsonl(tmp_path, "weights")]
    assert parents == ["u1"]
    chat = list(read_jsonl(tmp_path, "chatMessages"))
    assert chat[0][0] == "u1"
    assert chat[0][1]["fields"]["text"] == {"stringValue": "salom"}


def test_photo_bytes_stored_as_file_not_in_jsonl(tmp_path):
    fake = FakeFirestore(seed())
    extract_all(make_reader(fake, Clock()), tmp_path, "t")
    ((parent, doc),) = list(read_jsonl(tmp_path, "photos"))
    assert parent == "u1"
    assert "data" not in doc["fields"]
    assert doc["photoBytes"] == len(b"\xff\xd8jpeg-bytes")
    assert (tmp_path / "photos" / "u1" / "p1.bin").read_bytes() == b"\xff\xd8jpeg-bytes"
    assert "jpeg-bytes" not in (tmp_path / "photos.jsonl").read_text()


def test_output_is_private(tmp_path):
    fake = FakeFirestore(seed())
    extract_all(make_reader(fake, Clock()), tmp_path / "out", "t")
    out = tmp_path / "out"
    assert stat.S_IMODE(out.stat().st_mode) == 0o700
    assert stat.S_IMODE((out / "users.jsonl").stat().st_mode) == 0o600
    assert stat.S_IMODE((out / "photos" / "u1" / "p1.bin").stat().st_mode) == 0o600
    assert stat.S_IMODE((out / "manifest.json").stat().st_mode) == 0o600


def test_failure_leaves_no_complete_file(tmp_path):
    fake = FakeFirestore(seed())
    fake.fail_with["users/u2/weights"] = [403]
    with pytest.raises(ExtractError):
        extract_all(make_reader(fake, Clock()), tmp_path, "t")
    assert (tmp_path / "users.jsonl").exists()
    assert not (tmp_path / "weights.jsonl").exists()
    assert (tmp_path / "weights.jsonl.part").exists()
    assert not (tmp_path / "manifest.json").exists()


def test_rerun_overwrites_previous_output(tmp_path):
    fake = FakeFirestore(seed())
    extract_all(make_reader(fake, Clock()), tmp_path, "t")
    extract_all(make_reader(fake, Clock()), tmp_path, "t")
    assert len(list(read_jsonl(tmp_path, "users"))) == 2


def test_invalid_base64_photo_recorded_with_zero_bytes(tmp_path):
    collections = seed()
    collections["users/u1/photos"] = [
        make_doc(
            "users/u1/photos/bad",
            {"data": {"bytesValue": "***not-base64***"}, "weight": {"doubleValue": 70.0}},
        )
    ]
    manifest = extract_all(make_reader(FakeFirestore(collections), Clock()), tmp_path, "t")
    ((_, doc),) = list(read_jsonl(tmp_path, "photos"))
    assert doc["photoBytes"] == 0
    assert "data" not in doc["fields"]
    assert not (tmp_path / "photos" / "u1" / "bad.bin").exists()
    assert manifest.photo_bytes == 0


def test_empty_next_page_token_ends_pagination():
    fake = FakeFirestore({"gyms": [make_doc("gyms/g1")]})
    reader = make_reader(fake, Clock())
    assert len(list(reader.documents("gyms"))) == 1


def test_manifest_written_atomically(tmp_path):
    extract_all(make_reader(FakeFirestore(seed()), Clock()), tmp_path, "t")
    assert (tmp_path / "manifest.json").exists()
    assert not (tmp_path / "manifest.json.part").exists()
