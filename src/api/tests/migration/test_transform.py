from datetime import UTC, datetime
from typing import Any

from scripts.migrate_firestore.authexport import AuthRecord
from scripts.migrate_firestore.convert import stable_uuid
from scripts.migrate_firestore.transform import Transformed, transform

NOW = datetime(2026, 6, 1, tzinfo=UTC)
SENTINEL = "sentinel-hash"
CREATE = datetime(2026, 1, 1, tzinfo=UTC)


def doc(doc_id: str, **fields: Any) -> dict[str, Any]:
    return {"_id": doc_id, "_create_time": CREATE, **fields}


def auth_record(uid: str, **overrides: Any) -> AuthRecord:
    values = {
        "uid": uid,
        "email": f"{uid}@phone.test",
        "password_hash": "aGFzaA==",
        "salt": "c2FsdA==",
        "algo": "scrypt",
        "created_at": datetime(2025, 12, 1, tzinfo=UTC),
        "disabled": False,
    }
    values.update(overrides)
    return AuthRecord(**values)


def user(uid: str, phone: str, **extra: Any) -> tuple[None, dict[str, Any]]:
    fields = {"name": f"N{uid}", "phone": phone, "role": "user", **extra}
    return None, doc(uid, **fields)


def run(source: dict, auth: dict | None = None) -> Transformed:
    return transform(source, auth or {}, SENTINEL, NOW)


def rejected(result: Transformed, table: str) -> list[str]:
    return [item.reason for item in result.findings.rejects if item.table == table]


def noted(result: Transformed, table: str) -> list[str]:
    return [item.note for item in result.findings.notes if item.table == table]


def test_user_phone_normalised_and_hash_copied():
    result = run({"users": [user("u1", "+998 90 123-45-67")]}, {"u1": auth_record("u1")})
    (row,) = result.tables["users"]
    assert row["phone"] == "998901234567"
    assert row["password_hash"] == SENTINEL
    assert (row["legacy_hash"], row["legacy_salt"], row["legacy_algo"]) == (
        "aGFzaA==",
        "c2FsdA==",
        "scrypt",
    )
    assert row["created_at"] == datetime(2025, 12, 1, tzinfo=UTC)


def test_invalid_phone_rejected():
    result = run({"users": [user("u1", ""), user("u2", "123")]})
    assert result.tables["users"] == []
    assert rejected(result, "users") == ["phone_invalid", "phone_invalid"]


def test_duplicate_phone_keeps_user_with_auth_record():
    source = {"users": [user("a", "998901234567"), user("b", "998901234567")]}
    result = run(source, {"b": auth_record("b")})
    assert [row["id"] for row in result.tables["users"]] == ["b"]
    assert rejected(result, "users") == ["duplicate_phone:kept=b"]


def test_duplicate_phone_without_auth_keeps_earliest():
    older = (None, {**doc("old", name="x", phone="998901234567"), "_create_time": CREATE})
    newer = (
        None,
        {
            **doc("new", name="y", phone="998901234567"),
            "_create_time": datetime(2026, 3, 1, tzinfo=UTC),
        },
    )
    result = run({"users": [newer, older]})
    assert [row["id"] for row in result.tables["users"]] == ["old"]


def test_unknown_role_defaults_to_user():
    result = run({"users": [(None, doc("u1", phone="998901234567", role="wizard"))]})
    assert result.tables["users"][0]["role"] == "user"
    assert noted(result, "users") == ["role_defaulted:wizard", "no_auth_record"]


def test_missing_references_nulled():
    source = {
        "users": [user("u1", "998901234567", trainerId="ghost", gymId="nope")],
        "gyms": [(None, doc("g1", name="Gym"))],
    }
    (row,) = run(source).tables["users"]
    assert row["trainer_id"] is None
    assert row["gym_id"] is None


def test_valid_references_kept_and_gym_days_filtered():
    source = {
        "users": [
            user("t1", "998901111111", gymId="g1"),
            user("u1", "998902222222", trainerId="t1", gymId="g1", gymDays=[0, 1, 7, 9]),
        ],
        "gyms": [(None, doc("g1", name="Gym"))],
    }
    rows = {row["id"]: row for row in run(source).tables["users"]}
    assert rows["u1"]["trainer_id"] == "t1"
    assert rows["u1"]["gym_id"] == "g1"
    assert rows["u1"]["gym_days"] == [1, 7]


def test_disabled_and_bcrypt_and_hashless_accounts_reported():
    source = {
        "users": [
            user("d", "998901000001"),
            user("b", "998901000002"),
            user("n", "998901000003"),
        ]
    }
    auth = {
        "d": auth_record("d", disabled=True),
        "b": auth_record("b", algo="bcrypt", salt=None),
        "n": auth_record("n", algo=None, password_hash=None, salt=None),
    }
    result = run(source, auth)
    rows = {row["id"]: row for row in result.tables["users"]}
    assert rows["d"]["legacy_hash"] is None
    assert rows["b"]["legacy_algo"] == "bcrypt"
    assert rows["b"]["legacy_salt"] is None
    assert rows["n"]["legacy_hash"] is None
    assert set(noted(result, "users")) == {
        "disabled_login_removed",
        "bcrypt_needs_reset",
        "no_password_hash",
    }


def test_trainers_rebuilt_from_admins():
    source = {
        "users": [
            (None, doc("a1", name="Coach", phone="998901000001", role="admin")),
            (None, doc("a2", name="", phone="998901000002", role="admin")),
            user("u1", "998901000003"),
        ],
        "trainers": [
            (None, doc("a1", name="Coach Ali", bio="bio", accepting=False)),
            (None, doc("u1", name="Student")),
            (None, doc("ghost", name="Ghost")),
        ],
    }
    result = run(source)
    rows = {row["id"]: row for row in result.tables["trainers"]}
    assert set(rows) == {"a1", "a2"}
    assert rows["a1"]["name"] == "Coach Ali"
    assert rows["a1"]["accepting"] is False
    assert rows["a2"]["name"] == "998901000002"
    assert sorted(rejected(result, "trainers")) == ["not_admin", "user_missing"]


def test_ratings_need_known_trainer_and_valid_stars():
    source = {
        "users": [(None, doc("a1", phone="998901000001", role="admin"))],
        "ratings": [
            (None, doc("a1", stars=5, comment="top")),
            (None, doc("a2", stars=5)),
        ],
    }
    result = run(source)
    assert [row["trainer_id"] for row in result.tables["ratings"]] == ["a1"]
    assert rejected(result, "ratings") == ["trainer_missing"]
    bad = run({**source, "ratings": [(None, doc("a1", stars=9))]})
    assert rejected(bad, "ratings") == ["stars_out_of_range:9"]


def test_foods_clamp_negative_values():
    result = run({"foods": [(None, doc("f1", name="Rice", kcal=-5, protein=3))]})
    (row,) = result.tables["foods"]
    assert row["kcal"] == 0.0
    assert row["protein"] == 3.0
    assert noted(result, "foods") == ["kcal_clamped"]


def test_plan_over_caps_only_noted():
    meals = [{"items": []} for _ in range(21)]
    result = run({"plans": [(None, doc("p1", title="Plan", meals=meals))]})
    assert len(result.tables["plans"][0]["meals"]) == 21
    assert noted(result, "plans") == ["exceeds_meal_cap"]


def test_exercise_rules():
    source = {
        "exercises": [
            (
                None,
                doc("e1", name="Press", muscle="chest", level="beginner", createdAt=1700000000000),
            ),
            (None, doc("e2", name="Odd", muscle="nowhere")),
            (None, doc("e3", name="Curl", muscle="biceps", level="godlike")),
        ]
    }
    result = run(source)
    rows = {row["id"]: row for row in result.tables["exercises"]}
    assert set(rows) == {"e1", "e3"}
    assert rows["e1"]["level"] == "beginner"
    assert rows["e1"]["created_at"] == datetime.fromtimestamp(1700000000, UTC)
    assert rows["e3"]["level"] == ""
    assert rejected(result, "exercises") == ["muscle_invalid:nowhere"]


def test_product_stock_sum_and_category_default():
    source = {
        "shop": [
            (
                None,
                doc("p1", name="Shirt", category="Forma", price=100, sizeStock={"S": 2, "M": 3}),
            ),
            (None, doc("p2", name="Mystery", category="???", price=5, stock=4)),
            (None, doc("p3", name="Bad", price=-1)),
        ]
    }
    result = run(source)
    rows = {row["id"]: row for row in result.tables["products"]}
    assert rows["p2"]["category"] == "Boshqa"
    assert rows["p2"]["stock"] == 4
    assert rejected(result, "products") == ["price_negative"]
    assert rows["p1"]["stock"] == 5
    assert rows["p1"]["category"] == "Forma"


def test_order_validation_and_totals():
    source = {
        "orders": [
            (None, doc("o1", clientId="u1", price=1000, qty=2, status="new")),
            (None, doc("o2", clientId="u1", price=1000, qty=99, status="new")),
            (None, doc("o3", clientId="u1", price=-1, qty=1, status="new")),
            (None, doc("o4", clientId="u1", price=1, qty=1, status="weird")),
            (None, doc("o5", price=1, qty=1, status="new")),
        ]
    }
    result = run(source)
    assert [row["id"] for row in result.tables["orders"]] == ["o1"]
    assert sorted(rejected(result, "orders")) == [
        "client_missing",
        "price_invalid",
        "qty_out_of_range:99",
        "status_invalid:weird",
    ]


def sub(sub_id: str, **fields: Any) -> tuple[str, dict[str, Any]]:
    return "u1", doc(sub_id, **fields)


def test_subscription_rules():
    source = {
        "users": [user("u1", "998901234567")],
        "subscriptions": [
            sub("s1", months=1, days=0, price=100, startDate=datetime(2026, 5, 1, tzinfo=UTC)),
            sub("s2", months=1, days=3, price=100),
            sub("s3", months=0, days=0, price=100),
            ("ghost", doc("s4", months=1, days=0, price=1)),
        ],
    }
    result = run(source)
    (kept,) = result.tables["subscriptions"]
    assert kept["id"] == stable_uuid("subscription", "u1", "s1").hex
    assert kept["months"] == 1
    assert sorted(rejected(result, "subscriptions")) == [
        "kind_not_exclusive",
        "kind_not_exclusive",
        "orphan_user",
    ]


def test_membership_rebuilt_from_latest_subscription():
    source = {
        "users": [user("u1", "998901234567", name="Ali")],
        "subscriptions": [
            sub("old", months=1, days=0, price=100, startDate=datetime(2026, 1, 1, tzinfo=UTC)),
            sub("new", months=3, days=0, price=300, startDate=datetime(2026, 4, 1, tzinfo=UTC)),
        ],
    }
    result = run(source)
    (membership,) = result.tables["memberships"]
    assert (membership["months"], membership["price"]) == (3, 300)
    assert membership["expires_at"] == result.tables["users"][0]["subscription_expires_at"]
    assert membership["expires_at"] is not None
    assert noted(result, "memberships") == ["expiry_computed"]


def test_membership_keeps_stored_expiry_and_skips_staff():
    expiry = datetime(2026, 9, 9, tzinfo=UTC)
    source = {
        "users": [
            user("u1", "998901234567", subscriptionExpiresAt=expiry),
            (None, doc("a1", phone="998907654321", role="admin")),
        ],
        "subscriptions": [
            sub("s1", months=1, days=0, price=1, startDate=datetime(2026, 5, 1, tzinfo=UTC)),
            ("a1", doc("s2", months=1, days=0, price=1)),
        ],
    }
    result = run(source)
    (membership,) = result.tables["memberships"]
    assert membership["user_id"] == "u1"
    assert membership["expires_at"] == expiry


def test_weights_days_attendance():
    source = {
        "users": [user("u1", "998901234567")],
        "weights": [
            ("u1", doc("w1", weight=80.5, date=datetime(2026, 5, 1, tzinfo=UTC))),
            ("u1", doc("w2", weight=0)),
            ("u1", doc("w3", weight=900)),
            ("ghost", doc("w4", weight=70)),
        ],
        "days": [
            ("u1", doc("2026-05-10", done=[0, 2], water=99, extras=[{"name": "x"}])),
            ("u1", doc("garbage")),
        ],
        "attendance": [
            ("u1", doc("2026-05-10", present=True, markedBy="a1")),
            ("u1", doc("zzz")),
        ],
    }
    result = run(source)
    assert len(result.tables["weights"]) == 1
    assert sorted(rejected(result, "weights")) == [
        "orphan_user",
        "weight_out_of_range",
        "weight_out_of_range",
    ]
    (day,) = result.tables["days"]
    assert day["water"] == 30
    assert day["done"] == [0, 2]
    assert rejected(result, "days") == ["day_key_invalid"]
    assert len(result.tables["attendance"]) == 1
    assert rejected(result, "attendance") == ["day_key_invalid"]


def test_messages_kind_truncation_and_rejects():
    source = {
        "users": [user("u1", "998901234567")],
        "chatMessages": [
            ("u1", doc("m1", text="salom", senderId="u1")),
            ("u1", doc("m2", text="🛒 Yangi buyurtma", senderId="u1")),
            ("u1", doc("m3", text="x" * 2500, senderId="u1")),
            ("u1", doc("m4", text="   ", senderId="u1")),
            ("u1", doc("m5", text="hi")),
            ("ghost", doc("m6", text="hi", senderId="g")),
        ],
    }
    result = run(source)
    kinds = [row["kind"] for row in result.tables["messages"]]
    assert kinds == ["user", "system", "user"]
    assert len(result.tables["messages"][2]["text"]) == 2000
    assert noted(result, "messages") == ["text_truncated"]
    assert sorted(rejected(result, "messages")) == ["orphan_user", "sender_missing", "text_empty"]


def test_photos_validation_and_deterministic_keys():
    source = {
        "users": [user("u1", "998901234567")],
        "photos": [
            ("u1", doc("p1", photoBytes=1000, weight=80.0)),
            ("u1", doc("p2", photoBytes=0, weight=80.0)),
            ("u1", doc("p3", photoBytes=400000, weight=80.0)),
            ("u1", doc("p4", photoBytes=10, weight=0)),
            ("ghost", doc("p5", photoBytes=10, weight=80.0)),
        ],
    }
    first = run(source)
    second = run(source)
    (row,) = first.tables["photos"]
    assert row["id"] == second.tables["photos"][0]["id"]
    assert row["key"] == second.tables["photos"][0]["key"]
    assert row["key"].split("/")[1] == "u1"
    assert row["_file"] == "photos/u1/p1.bin"
    assert sorted(rejected(first, "photos")) == [
        "data_missing",
        "orphan_user",
        "too_large:400000",
        "weight_out_of_range",
    ]


def test_source_counts_recorded():
    result = run({"users": [user("u1", "998901234567")], "foods": []})
    assert result.source_counts == {"users": 1, "foods": 0}


def test_findings_never_contain_hashes():
    source = {"users": [user("u1", "998901234567")]}
    result = run(source, {"u1": auth_record("u1", algo="bcrypt", salt=None)})
    blob = str(result.findings.to_json())
    assert "aGFzaA==" not in blob
    assert SENTINEL not in blob
