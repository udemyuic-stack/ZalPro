import base64
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from tests.migration.support import make_doc


def encode(value: Any) -> dict[str, Any]:
    if value is None:
        return {"nullValue": None}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, float):
        return {"doubleValue": value}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, bytes):
        return {"bytesValue": base64.b64encode(value).decode()}
    if isinstance(value, datetime):
        return {"timestampValue": value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.%fZ")}
    if isinstance(value, list):
        return {"arrayValue": {"values": [encode(item) for item in value]}}
    return {"mapValue": {"fields": {key: encode(item) for key, item in value.items()}}}


def fields(**values: Any) -> dict[str, Any]:
    return {key: encode(value) for key, value in values.items()}


def firestore_seed(trainees: int = 3, photo_bytes: bytes = b"12345678") -> dict[str, list]:
    start = datetime(2026, 5, 1, tzinfo=UTC)
    seed: dict[str, list] = {
        "gyms": [make_doc("gyms/g1", fields(name="Diamond"))],
        "users": [
            make_doc(
                "users/t1",
                fields(name="Coach", phone="998900000001", role="admin", gymId="g1"),
            )
        ],
        "trainers": [make_doc("trainers/t1", fields(name="Coach", bio="hi"))],
        "ratings": [make_doc("ratings/t1", fields(stars=5, comment="top"))],
        "foods": [make_doc("foods/f1", fields(name="Rice", kcal=130.0))],
        "plans": [make_doc("plans/pl1", fields(title="Plan", meals=[{"items": []}]))],
        "exercises": [make_doc("exercises/e1", fields(name="Press", muscle="chest"))],
        "shop": [make_doc("shop/pr1", fields(name="Shirt", category="Forma", price=100, stock=3))],
        "orders": [],
        "reminders": [],
    }
    for index in range(trainees):
        uid = f"u{index}"
        seed["users"].append(
            make_doc(
                f"users/{uid}",
                fields(
                    name=f"Ali {index}",
                    phone=f"99890100{index:04d}",
                    role="user",
                    trainerId="t1",
                    gymId="g1",
                    weight=80.0,
                ),
            )
        )
        seed["orders"].append(
            make_doc(
                f"orders/o{index}",
                fields(clientId=uid, price=1000 * (index + 1), qty=2, status="new"),
            )
        )
        seed[f"users/{uid}/subscriptions"] = [
            make_doc(
                f"users/{uid}/subscriptions/s1",
                fields(months=1, days=0, price=300000, startDate=start),
            )
        ]
        seed[f"users/{uid}/weights"] = [
            make_doc(f"users/{uid}/weights/w1", fields(weight=80.0, date=start))
        ]
        seed[f"users/{uid}/days"] = [
            make_doc(f"users/{uid}/days/2026-05-10", fields(done=[0], water=2))
        ]
        seed[f"users/{uid}/attendance"] = [
            make_doc(f"users/{uid}/attendance/2026-05-10", fields(present=True, markedBy="t1"))
        ]
        seed[f"users/{uid}/photos"] = [
            make_doc(
                f"users/{uid}/photos/p1",
                fields(data=photo_bytes, weight=80.0, takenAt=start),
            )
        ]
        seed[f"chats/{uid}/messages"] = [
            make_doc(f"chats/{uid}/messages/m1", fields(text="salom", senderId=uid))
        ]
    return seed


def auth_export(path: Path, uids: list[str]) -> Path:
    users = [
        {
            "localId": uid,
            "email": f"{uid}@phone.test",
            "passwordHash": "aGFzaA==",
            "salt": "c2FsdA==",
            "createdAt": "1764547200000",
        }
        for uid in uids
    ]
    path.write_text(json.dumps({"users": users}), encoding="utf-8")
    return path
