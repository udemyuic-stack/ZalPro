import base64
from typing import Any

import httpx

DOCS_MARKER = "/databases/(default)/documents/"


def string(value: str) -> dict[str, Any]:
    return {"stringValue": value}


def integer(value: int) -> dict[str, Any]:
    return {"integerValue": str(value)}


def make_doc(path: str, fields: dict[str, Any] | None = None) -> dict[str, Any]:
    return {
        "name": f"projects/p{DOCS_MARKER}{path}",
        "fields": fields or {},
        "createTime": "2026-01-01T00:00:00Z",
        "updateTime": "2026-01-01T00:00:00Z",
    }


def photo_doc(path: str, payload: bytes) -> dict[str, Any]:
    return make_doc(
        path,
        {
            "data": {"bytesValue": base64.b64encode(payload).decode()},
            "weight": {"doubleValue": 80.5},
        },
    )


class FakeFirestore:
    def __init__(self, collections: dict[str, list[dict[str, Any]]], page_size: int = 300) -> None:
        self.collections = collections
        self.page_size = page_size
        self.requests: list[httpx.Request] = []
        self.fail_with: dict[str, list[int]] = {}
        self.token_calls = 0
        self.sign_in_calls = 0

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        url = str(request.url)
        if "accounts:signInWithPassword" in url:
            self.sign_in_calls += 1
            return httpx.Response(
                200, json={"idToken": "id-0", "refreshToken": "refresh-0", "expiresIn": "3600"}
            )
        if "securetoken.googleapis.com" in url:
            self.token_calls += 1
            return httpx.Response(
                200,
                json={
                    "id_token": f"id-{self.token_calls}",
                    "refresh_token": "refresh-0",
                    "expires_in": "3600",
                },
            )
        path = request.url.path.split(DOCS_MARKER, 1)[1]
        queued = self.fail_with.get(path)
        if queued:
            return httpx.Response(queued.pop(0))
        documents = self.collections.get(path, [])
        start = int(request.url.params.get("pageToken", "0"))
        size = int(request.url.params["pageSize"])
        chunk = documents[start : start + size]
        body: dict[str, Any] = {}
        if chunk:
            body["documents"] = chunk
        if start + size < len(documents):
            body["nextPageToken"] = str(start + size)
        return httpx.Response(200, json=body)

    def client(self) -> httpx.Client:
        return httpx.Client(transport=httpx.MockTransport(self.handler))


def sample_source() -> dict[str, list[tuple[str | None, dict[str, Any]]]]:
    from datetime import UTC, datetime

    created = datetime(2026, 1, 1, tzinfo=UTC)
    start = datetime(2026, 5, 1, tzinfo=UTC)

    def doc(doc_id: str, **fields: Any) -> dict[str, Any]:
        return {"_id": doc_id, "_create_time": created, **fields}

    return {
        "gyms": [(None, doc("g1", name="Diamond", address="Toshkent"))],
        "users": [
            (
                None,
                doc(
                    "t1",
                    name="Coach",
                    phone="998901111111",
                    role="admin",
                    gymId="g1",
                ),
            ),
            (
                None,
                doc(
                    "u1",
                    name="Ali",
                    phone="998902222222",
                    role="user",
                    trainerId="t1",
                    gymId="g1",
                    gymDays=[1, 3, 5],
                    weight=80.5,
                    age=30,
                    program={"chest": ["e1"]},
                ),
            ),
            (None, doc("bad", name="NoPhone", phone="", role="user")),
        ],
        "trainers": [(None, doc("t1", name="Coach", bio="hi"))],
        "ratings": [(None, doc("t1", stars=5, comment="top"))],
        "foods": [(None, doc("f1", name="Rice", kcal=130, protein=2.7, fat=0.3, carbs=28))],
        "plans": [(None, doc("pl1", title="Plan", meals=[{"items": []}], forbidden=["sugar"]))],
        "exercises": [(None, doc("e1", name="Press", muscle="chest", createdAt=1700000000000))],
        "shop": [(None, doc("pr1", name="Shirt", category="Forma", price=100, stock=3))],
        "orders": [
            (None, doc("o1", clientId="u1", price=1000, qty=2, status="new")),
            (None, doc("o2", clientId="u1", price=500, qty=1, status="given")),
            (None, doc("o3", clientId="u1", price=500, qty=99, status="new")),
        ],
        "reminders": [(None, doc("r1", clientId="u1", trainerId="t1", daysLeft=3))],
        "subscriptions": [
            ("u1", doc("s1", months=1, days=0, price=300000, startDate=start)),
        ],
        "weights": [("u1", doc("w1", weight=80.5, date=start))],
        "days": [("u1", doc("2026-05-10", done=[0, 1], water=3))],
        "attendance": [("u1", doc("2026-05-10", present=True, markedBy="t1"))],
        "chatMessages": [
            ("u1", doc("m1", text="salom", senderId="u1")),
            ("u1", doc("m2", text="✅ ok", senderId="t1")),
        ],
        "photos": [
            ("u1", doc("p1", photoBytes=8, weight=80.0, takenAt=start)),
            ("u1", doc("p2", photoBytes=0, weight=80.0)),
        ],
    }


class FakePhotoStore:
    def __init__(self) -> None:
        self.objects: dict[str, bytes] = {}
        self.puts = 0
        self.fail_puts = 0
        self.truncate = False

    async def size_of(self, key: str) -> int | None:
        data = self.objects.get(key)
        return None if data is None else len(data)

    async def put(self, key: str, data: bytes) -> None:
        if self.fail_puts:
            self.fail_puts -= 1
            raise ConnectionError("boom")
        self.puts += 1
        self.objects[key] = data[:-1] if self.truncate else data
