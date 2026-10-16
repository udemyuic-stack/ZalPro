from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any
from zoneinfo import ZoneInfo

from scripts.migrate_firestore.authexport import AuthRecord
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
from scripts.migrate_firestore.report import Findings
from zalpro_api.models.exercise import LEVELS, MUSCLES
from zalpro_api.models.message import MAX_MESSAGE_LENGTH
from zalpro_api.models.photo import MAX_PHOTO_BYTES, MAX_PHOTO_WEIGHT
from zalpro_api.models.product import PRODUCT_CATEGORIES
from zalpro_api.models.user import ROLES
from zalpro_api.services.phone import normalize_phone
from zalpro_api.services.storage import MEDIA_FOLDERS
from zalpro_api.services.subscriptions import MAX_MEMBERSHIP_NAME, compute_expiry

Source = dict[str, list[tuple[str | None, dict[str, Any]]]]

CURRENCIES = ("UZS", "USD")
ORDER_STATUSES = ("new", "given", "canceled")
SYSTEM_PREFIXES = ("🛒", "✅", "❌", "⏰")
MIN_PHONE_DIGITS = 9
MAX_PLAN_MEALS = 20
MAX_MEAL_ITEMS = 50
MAX_PLAN_TITLE = 120
MAX_WATER = 30
TABLE_ORDER = (
    "gyms",
    "users",
    "trainers",
    "ratings",
    "foods",
    "plans",
    "exercises",
    "products",
    "orders",
    "reminders",
    "subscriptions",
    "memberships",
    "weights",
    "days",
    "attendance",
    "messages",
    "photos",
)


@dataclass
class Transformed:
    tables: dict[str, list[dict[str, Any]]] = field(default_factory=dict)
    findings: Findings = field(default_factory=Findings)
    source_counts: dict[str, int] = field(default_factory=dict)


def created(doc: dict[str, Any], *names: str) -> datetime | None:
    for name in names:
        value = when(doc.get(name))
        if value is not None:
            return value
    return when(doc.get("_create_time"))


def currency_of(doc: dict[str, Any], table: str, findings: Findings) -> str:
    value = text(doc.get("currency"), "UZS")
    if value in CURRENCIES:
        return value
    findings.note(table, doc["_id"], f"currency_defaulted:{value}")
    return "UZS"


def transform_gyms(docs: list[tuple[str | None, dict[str, Any]]], findings: Findings):
    rows = []
    for _, doc in docs:
        name = text(doc.get("name")).strip()
        if not name:
            findings.reject("gyms", doc["_id"], "name_missing")
            continue
        rows.append(
            {
                "id": doc["_id"],
                "name": name,
                "address": text(doc.get("address")),
                "country": text(doc.get("country")),
                "region": text(doc.get("region")),
                "district": text(doc.get("district")),
            }
        )
    return rows


def pick_phone_winners(
    candidates: list[dict[str, Any]], auth: dict[str, AuthRecord], findings: Findings
) -> list[dict[str, Any]]:
    groups: dict[str, list[dict[str, Any]]] = {}
    for candidate in candidates:
        groups.setdefault(candidate["phone"], []).append(candidate)
    winners = []
    for group in groups.values():
        if len(group) == 1:
            winners.append(group[0])
            continue

        def rank(item: dict[str, Any]) -> tuple[int, float, str]:
            record = auth.get(item["id"])
            stamp = item["created_at"].timestamp() if item["created_at"] else float("inf")
            return (0 if record and record.password_hash else 1, stamp, item["id"])

        group.sort(key=rank)
        winners.append(group[0])
        for loser in group[1:]:
            findings.reject("users", loser["id"], f"duplicate_phone:kept={group[0]['id']}")
    return winners


def build_user_candidates(
    docs: list[tuple[str | None, dict[str, Any]]],
    auth: dict[str, AuthRecord],
    sentinel_hash: str,
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    candidates = []
    for _, doc in docs:
        uid = doc["_id"]
        phone = normalize_phone(text(doc.get("phone")))
        if len(phone) < MIN_PHONE_DIGITS:
            findings.reject("users", uid, "phone_invalid")
            continue
        role = text(doc.get("role"), "user")
        if role not in ROLES:
            findings.note("users", uid, f"role_defaulted:{role}")
            role = "user"
        record = auth.get(uid)
        legacy_hash = legacy_salt = legacy_algo = None
        if record is None:
            findings.note("users", uid, "no_auth_record")
        elif record.disabled:
            findings.note("users", uid, "disabled_login_removed")
        elif record.algo is None:
            findings.note("users", uid, "no_password_hash")
        else:
            legacy_hash = record.password_hash
            legacy_algo = record.algo
            legacy_salt = record.salt if record.algo == "scrypt" else None
            if record.algo == "bcrypt":
                findings.note("users", uid, "bcrypt_needs_reset")
        gym_days = [day for day in int_list(doc.get("gymDays")) if 1 <= day <= 7]
        program = doc.get("program")
        candidates.append(
            {
                "id": uid,
                "name": text(doc.get("name")),
                "phone": phone,
                "password_hash": sentinel_hash,
                "legacy_hash": legacy_hash,
                "legacy_salt": legacy_salt,
                "legacy_algo": legacy_algo,
                "role": role,
                "gender": text(doc.get("gender")) or None,
                "age": optional_integer(doc.get("age")),
                "height": optional_number(doc.get("height")),
                "weight": number(doc.get("weight")),
                "activity": optional_number(doc.get("activity")),
                "metabolism": text(doc.get("metabolism")) or None,
                "goal": text(doc.get("goal")) or None,
                "plan_id": text(doc.get("planId")) or None,
                "plan_assigned_at": when(doc.get("planAssignedAt")),
                "trainer_id": text(doc.get("trainerId")) or None,
                "gym_id": text(doc.get("gymId")) or None,
                "gym_days": gym_days,
                "home_workout_date": text(doc.get("homeWorkoutDate")) or None,
                "subscription_expires_at": when(doc.get("subscriptionExpiresAt")),
                "last_weigh_in": when(doc.get("lastWeighIn")),
                "program": jsonable(program) if isinstance(program, dict) else {},
                "created_at": (record.created_at if record else None) or created(doc) or now,
            }
        )
    return candidates


def transform_users(
    docs: list[tuple[str | None, dict[str, Any]]],
    auth: dict[str, AuthRecord],
    gym_ids: set[str],
    sentinel_hash: str,
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    candidates = build_user_candidates(docs, auth, sentinel_hash, now, findings)
    rows = pick_phone_winners(candidates, auth, findings)
    rows.sort(key=lambda row: row["id"])
    user_ids = {row["id"] for row in rows}
    for row in rows:
        if row["trainer_id"] is not None and (
            row["trainer_id"] not in user_ids or row["trainer_id"] == row["id"]
        ):
            findings.note("users", row["id"], "trainer_nulled")
            row["trainer_id"] = None
        if row["gym_id"] is not None and row["gym_id"] not in gym_ids:
            findings.note("users", row["id"], "gym_nulled")
            row["gym_id"] = None
    return rows


def transform_trainers(
    docs: list[tuple[str | None, dict[str, Any]]],
    users: list[dict[str, Any]],
    findings: Findings,
) -> list[dict[str, Any]]:
    by_id = {row["id"]: row for row in users}
    doc_by_id = {doc["_id"]: doc for _, doc in docs}
    rows = []
    for trainer_id in doc_by_id:
        user = by_id.get(trainer_id)
        if user is None:
            findings.reject("trainers", trainer_id, "user_missing")
        elif user["role"] != "admin":
            findings.reject("trainers", trainer_id, "not_admin")
    for user in users:
        if user["role"] != "admin":
            continue
        doc = doc_by_id.get(user["id"])
        if doc is None:
            findings.note("trainers", user["id"], "created_for_admin")
            doc = {}
        rows.append(
            {
                "id": user["id"],
                "name": text(doc.get("name")) or user["name"] or user["phone"],
                "bio": text(doc.get("bio")),
                "accepting": boolean(doc.get("accepting"), True),
                "gym_id": user["gym_id"],
            }
        )
    return rows


def transform_ratings(
    docs: list[tuple[str | None, dict[str, Any]]],
    trainer_ids: set[str],
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    rows = []
    for _, doc in docs:
        trainer_id = doc["_id"]
        stars = integer(doc.get("stars"), 0)
        if trainer_id not in trainer_ids:
            findings.reject("ratings", trainer_id, "trainer_missing")
        elif not 1 <= stars <= 5:
            findings.reject("ratings", trainer_id, f"stars_out_of_range:{stars}")
        else:
            rows.append(
                {
                    "trainer_id": trainer_id,
                    "stars": stars,
                    "comment": text(doc.get("comment")),
                    "updated_at": created(doc, "updatedAt") or now,
                }
            )
    return rows


def non_negative(doc: dict[str, Any], key: str, table: str, findings: Findings) -> float:
    value = number(doc.get(key))
    if value < 0:
        findings.note(table, doc["_id"], f"{key}_clamped")
        return 0.0
    return value


def transform_foods(docs: list[tuple[str | None, dict[str, Any]]], findings: Findings):
    rows = []
    for _, doc in docs:
        name = text(doc.get("name")).strip()
        if not name:
            findings.reject("foods", doc["_id"], "name_missing")
            continue
        rows.append(
            {
                "id": doc["_id"],
                "name": name,
                "kcal": non_negative(doc, "kcal", "foods", findings),
                "protein": non_negative(doc, "protein", "foods", findings),
                "fat": non_negative(doc, "fat", "foods", findings),
                "carbs": non_negative(doc, "carbs", "foods", findings),
                "image": text(doc.get("image")),
            }
        )
    return rows


def plan_cap_notes(doc: dict[str, Any], meals: list[Any], week: dict[str, Any], findings: Findings):
    schedules = [meals, *[value for value in week.values() if isinstance(value, list)]]
    for schedule in schedules:
        if len(schedule) > MAX_PLAN_MEALS:
            findings.note("plans", doc["_id"], "exceeds_meal_cap")
        for meal in schedule:
            items = meal.get("items") if isinstance(meal, dict) else None
            if isinstance(items, list) and len(items) > MAX_MEAL_ITEMS:
                findings.note("plans", doc["_id"], "exceeds_item_cap")
    if len(text(doc.get("title"))) > MAX_PLAN_TITLE:
        findings.note("plans", doc["_id"], "title_too_long")


def transform_plans(docs: list[tuple[str | None, dict[str, Any]]], findings: Findings):
    rows = []
    for _, doc in docs:
        title = text(doc.get("title")).strip()
        if not title:
            findings.reject("plans", doc["_id"], "title_missing")
            continue
        meals = doc.get("meals") if isinstance(doc.get("meals"), list) else []
        week = doc.get("week") if isinstance(doc.get("week"), dict) else {}
        photos = doc.get("photos") if isinstance(doc.get("photos"), dict) else {}
        plan_cap_notes(doc, meals, week, findings)
        rows.append(
            {
                "id": doc["_id"],
                "title": title,
                "note": text(doc.get("note")),
                "forbidden": string_list(doc.get("forbidden")),
                "meals": jsonable(meals),
                "week": jsonable(week),
                "photos": {str(key): text(value) for key, value in photos.items()},
            }
        )
    return rows


def transform_exercises(
    docs: list[tuple[str | None, dict[str, Any]]], now: datetime, findings: Findings
):
    rows = []
    for _, doc in docs:
        name = text(doc.get("name")).strip()
        muscle = text(doc.get("muscle"))
        if not name:
            findings.reject("exercises", doc["_id"], "name_missing")
            continue
        if muscle not in MUSCLES:
            findings.reject("exercises", doc["_id"], f"muscle_invalid:{muscle}")
            continue
        level = text(doc.get("level"))
        if level not in LEVELS:
            findings.note("exercises", doc["_id"], f"level_defaulted:{level}")
            level = ""
        rows.append(
            {
                "id": doc["_id"],
                "name": name,
                "muscle": muscle,
                "sets": text(doc.get("sets")),
                "tip": text(doc.get("tip")),
                "also": string_list(doc.get("also")),
                "video": text(doc.get("video")),
                "created_at": created(doc, "createdAt") or now,
                "created_by": text(doc.get("createdBy")),
                "base": text(doc.get("base")),
                "level": level,
            }
        )
    return rows


def size_stock_of(doc: dict[str, Any]) -> dict[str, int]:
    raw = doc.get("sizeStock")
    if not isinstance(raw, dict):
        return {}
    return {str(key): max(integer(value), 0) for key, value in raw.items()}


def transform_products(docs: list[tuple[str | None, dict[str, Any]]], findings: Findings):
    rows = []
    for _, doc in docs:
        name = text(doc.get("name")).strip()
        if not name:
            findings.reject("products", doc["_id"], "name_missing")
            continue
        price = integer(doc.get("price"))
        cost = integer(doc.get("costPrice"))
        if price < 0 or cost < 0:
            findings.reject("products", doc["_id"], "price_negative")
            continue
        category = text(doc.get("category"))
        if category not in PRODUCT_CATEGORIES:
            findings.note("products", doc["_id"], f"category_defaulted:{category}")
            category = "Boshqa"
        size_stock = size_stock_of(doc)
        stock = sum(size_stock.values()) if size_stock else max(integer(doc.get("stock")), 0)
        rows.append(
            {
                "id": doc["_id"],
                "category": category,
                "name": name,
                "note": text(doc.get("note")),
                "name_ru": text(doc.get("nameRu")),
                "name_en": text(doc.get("nameEn")),
                "note_ru": text(doc.get("noteRu")),
                "note_en": text(doc.get("noteEn")),
                "image": text(doc.get("image")),
                "images": string_list(doc.get("images")),
                "sizes": string_list(doc.get("sizes")),
                "colors": string_list(doc.get("colors")),
                "price": price,
                "currency": currency_of(doc, "products", findings),
                "stock": stock,
                "size_stock": size_stock,
                "cost_price": cost,
                "active": boolean(doc.get("active"), True),
            }
        )
    return rows


def transform_orders(
    docs: list[tuple[str | None, dict[str, Any]]], now: datetime, findings: Findings
):
    rows = []
    for _, doc in docs:
        order_id = doc["_id"]
        client_id = text(doc.get("clientId"))
        price = integer(doc.get("price"), -1)
        qty = integer(doc.get("qty"), 1)
        status = text(doc.get("status"), "new")
        if not client_id:
            findings.reject("orders", order_id, "client_missing")
        elif price < 0:
            findings.reject("orders", order_id, "price_invalid")
        elif not 1 <= qty <= 20:
            findings.reject("orders", order_id, f"qty_out_of_range:{qty}")
        elif status not in ORDER_STATUSES:
            findings.reject("orders", order_id, f"status_invalid:{status}")
        else:
            rows.append(
                {
                    "id": order_id,
                    "client_id": client_id,
                    "client_name": text(doc.get("clientName")),
                    "client_phone": text(doc.get("clientPhone")),
                    "trainer_id": text(doc.get("trainerId")),
                    "gym_id": text(doc.get("gymId")),
                    "product_id": text(doc.get("productId")),
                    "product_name": text(doc.get("productName")),
                    "category": text(doc.get("category")),
                    "size": text(doc.get("size")),
                    "color": text(doc.get("color")),
                    "price": price,
                    "currency": currency_of(doc, "orders", findings),
                    "qty": qty,
                    "status": status,
                    "created_at": created(doc, "createdAt") or now,
                    "updated_at": when(doc.get("updatedAt")),
                    "given_by": text(doc.get("givenBy")),
                    "given_at": when(doc.get("givenAt")),
                }
            )
    return rows


def transform_reminders(
    docs: list[tuple[str | None, dict[str, Any]]], now: datetime, findings: Findings
):
    rows = []
    for _, doc in docs:
        client_id = text(doc.get("clientId"))
        if not client_id:
            findings.reject("reminders", doc["_id"], "client_missing")
            continue
        rows.append(
            {
                "id": doc["_id"],
                "client_id": client_id,
                "client_name": text(doc.get("clientName")),
                "trainer_id": text(doc.get("trainerId")),
                "sent_by": text(doc.get("sentBy")),
                "sent_at": created(doc, "sentAt") or now,
                "days_left": integer(doc.get("daysLeft")),
            }
        )
    return rows


def transform_subscriptions(
    docs: list[tuple[str | None, dict[str, Any]]],
    user_ids: set[str],
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    rows = []
    for parent, doc in docs:
        sub_id = doc["_id"]
        label = f"{parent}/{sub_id}"
        months = integer(doc.get("months"))
        days = integer(doc.get("days"))
        price = integer(doc.get("price"))
        start = created(doc, "startDate")
        if parent not in user_ids:
            findings.reject("subscriptions", label, "orphan_user")
        elif not 0 <= months <= 24 or not 0 <= days <= 31:
            findings.reject("subscriptions", label, "duration_out_of_range")
        elif (months > 0) == (days > 0):
            findings.reject("subscriptions", label, "kind_not_exclusive")
        elif price < 0:
            findings.reject("subscriptions", label, "price_negative")
        else:
            rows.append(
                {
                    "id": stable_uuid("subscription", str(parent), sub_id).hex,
                    "user_id": parent,
                    "start_date": start or now,
                    "months": months,
                    "days": days,
                    "price": price,
                    "currency": currency_of(doc, "subscriptions", findings),
                    "paid_date": when(doc.get("paidDate")),
                    "created_at": created(doc, "createdAt") or now,
                }
            )
    return rows


def build_memberships(
    users: list[dict[str, Any]],
    subscriptions: list[dict[str, Any]],
    zone: ZoneInfo,
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    latest: dict[str, dict[str, Any]] = {}
    for sub in subscriptions:
        current = latest.get(sub["user_id"])
        if current is None or sub["start_date"] > current["start_date"]:
            latest[sub["user_id"]] = sub
    by_id = {user["id"]: user for user in users}
    rows = []
    for user_id, sub in sorted(latest.items()):
        user = by_id[user_id]
        if user["role"] != "user":
            continue
        expires = user["subscription_expires_at"]
        if expires is None:
            expires = compute_expiry(sub["start_date"], sub["months"], sub["days"], zone)
            user["subscription_expires_at"] = expires
            findings.note("memberships", user_id, "expiry_computed")
        trainer = by_id.get(user["trainer_id"]) if user["trainer_id"] else None
        gym_id = (trainer["gym_id"] if trainer else None) or user["gym_id"] or ""
        rows.append(
            {
                "user_id": user_id,
                "name": user["name"][:MAX_MEMBERSHIP_NAME],
                "gym_id": gym_id,
                "months": sub["months"],
                "days": sub["days"],
                "price": sub["price"],
                "currency": sub["currency"],
                "paid_date": sub["paid_date"] or sub["start_date"],
                "expires_at": expires,
                "updated_at": now,
            }
        )
    return rows


def transform_weights(
    docs: list[tuple[str | None, dict[str, Any]]],
    user_ids: set[str],
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    rows = []
    for parent, doc in docs:
        label = f"{parent}/{doc['_id']}"
        weight = number(doc.get("weight"))
        if parent not in user_ids:
            findings.reject("weights", label, "orphan_user")
        elif not 0 < weight <= 500:
            findings.reject("weights", label, "weight_out_of_range")
        else:
            rows.append(
                {
                    "id": stable_uuid("weight", str(parent), doc["_id"]),
                    "user_id": parent,
                    "date": created(doc, "date") or now,
                    "weight": weight,
                }
            )
    return rows


def transform_days(
    docs: list[tuple[str | None, dict[str, Any]]], user_ids: set[str], findings: Findings
) -> list[dict[str, Any]]:
    rows = []
    for parent, doc in docs:
        label = f"{parent}/{doc['_id']}"
        day = day_from_key(doc["_id"])
        if parent not in user_ids:
            findings.reject("days", label, "orphan_user")
            continue
        if day is None:
            findings.reject("days", label, "day_key_invalid")
            continue
        water = integer(doc.get("water"))
        if not 0 <= water <= MAX_WATER:
            findings.note("days", label, "water_clamped")
            water = min(max(water, 0), MAX_WATER)
        extras = doc.get("extras") if isinstance(doc.get("extras"), list) else []
        rows.append(
            {
                "user_id": parent,
                "day": day,
                "done": int_list(doc.get("done")),
                "extras": jsonable([item for item in extras if isinstance(item, dict)]),
                "gym_started": boolean(doc.get("gymStarted")),
                "gym_done": string_list(doc.get("gymDone")),
                "water": water,
            }
        )
    return rows


def transform_attendance(
    docs: list[tuple[str | None, dict[str, Any]]],
    user_ids: set[str],
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    rows = []
    for parent, doc in docs:
        label = f"{parent}/{doc['_id']}"
        day = day_from_key(doc["_id"])
        if parent not in user_ids:
            findings.reject("attendance", label, "orphan_user")
        elif day is None:
            findings.reject("attendance", label, "day_key_invalid")
        else:
            rows.append(
                {
                    "user_id": parent,
                    "day": day,
                    "present": boolean(doc.get("present")),
                    "marked_by": text(doc.get("markedBy")),
                    "marked_at": created(doc, "markedAt") or now,
                }
            )
    return rows


def transform_messages(
    docs: list[tuple[str | None, dict[str, Any]]],
    user_ids: set[str],
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    rows = []
    for parent, doc in docs:
        label = f"{parent}/{doc['_id']}"
        body = text(doc.get("text"))
        sender = text(doc.get("senderId"))
        if parent not in user_ids:
            findings.reject("messages", label, "orphan_user")
            continue
        if not body.strip():
            findings.reject("messages", label, "text_empty")
            continue
        if not sender:
            findings.reject("messages", label, "sender_missing")
            continue
        if len(body) > MAX_MESSAGE_LENGTH:
            findings.note("messages", label, "text_truncated")
            body = body[:MAX_MESSAGE_LENGTH]
        rows.append(
            {
                "id": stable_uuid("message", str(parent), doc["_id"]),
                "chat_uid": parent,
                "sender_id": sender,
                "kind": "system" if body.startswith(SYSTEM_PREFIXES) else "user",
                "text": body,
                "created_at": created(doc, "createdAt") or now,
            }
        )
    return rows


def photo_key(user_id: str, photo_id: str) -> str:
    return f"{MEDIA_FOLDERS['image']}/{user_id}/{stable_uuid('photo-key', user_id, photo_id).hex}"


def transform_photos(
    docs: list[tuple[str | None, dict[str, Any]]],
    user_ids: set[str],
    now: datetime,
    findings: Findings,
) -> list[dict[str, Any]]:
    rows = []
    for parent, doc in docs:
        photo_id = doc["_id"]
        label = f"{parent}/{photo_id}"
        size = integer(doc.get("photoBytes"))
        weight = number(doc.get("weight"))
        if parent not in user_ids:
            findings.reject("photos", label, "orphan_user")
        elif size <= 0:
            findings.reject("photos", label, "data_missing")
        elif size > MAX_PHOTO_BYTES:
            findings.reject("photos", label, f"too_large:{size}")
        elif not 0 < weight <= MAX_PHOTO_WEIGHT:
            findings.reject("photos", label, "weight_out_of_range")
        else:
            rows.append(
                {
                    "id": stable_uuid("photo", str(parent), photo_id),
                    "user_id": parent,
                    "key": photo_key(str(parent), photo_id),
                    "taken_at": created(doc, "takenAt") or now,
                    "weight": weight,
                    "size": size,
                    "_file": f"photos/{parent}/{photo_id}.bin",
                }
            )
    return rows


def transform(
    source: Source,
    auth: dict[str, AuthRecord],
    sentinel_hash: str,
    now: datetime | None = None,
    zone: ZoneInfo | None = None,
) -> Transformed:
    now = now or datetime.now(UTC)
    zone = zone or ZoneInfo("Asia/Tashkent")
    result = Transformed()
    findings = result.findings
    result.source_counts = {name: len(docs) for name, docs in source.items()}

    def docs(name: str) -> list[tuple[str | None, dict[str, Any]]]:
        return source.get(name, [])

    tables = result.tables
    tables["gyms"] = transform_gyms(docs("gyms"), findings)
    gym_ids = {row["id"] for row in tables["gyms"]}
    tables["users"] = transform_users(docs("users"), auth, gym_ids, sentinel_hash, now, findings)
    user_ids = {row["id"] for row in tables["users"]}
    tables["trainers"] = transform_trainers(docs("trainers"), tables["users"], findings)
    trainer_ids = {row["id"] for row in tables["trainers"]}
    tables["ratings"] = transform_ratings(docs("ratings"), trainer_ids, now, findings)
    tables["foods"] = transform_foods(docs("foods"), findings)
    tables["plans"] = transform_plans(docs("plans"), findings)
    tables["exercises"] = transform_exercises(docs("exercises"), now, findings)
    tables["products"] = transform_products(docs("shop"), findings)
    tables["orders"] = transform_orders(docs("orders"), now, findings)
    tables["reminders"] = transform_reminders(docs("reminders"), now, findings)
    tables["subscriptions"] = transform_subscriptions(
        docs("subscriptions"), user_ids, now, findings
    )
    tables["memberships"] = build_memberships(
        tables["users"], tables["subscriptions"], zone, now, findings
    )
    tables["weights"] = transform_weights(docs("weights"), user_ids, now, findings)
    tables["days"] = transform_days(docs("days"), user_ids, findings)
    tables["attendance"] = transform_attendance(docs("attendance"), user_ids, now, findings)
    tables["messages"] = transform_messages(docs("chatMessages"), user_ids, now, findings)
    tables["photos"] = transform_photos(docs("photos"), user_ids, now, findings)
    return result
