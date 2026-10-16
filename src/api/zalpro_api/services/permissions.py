from dataclasses import dataclass
from datetime import timedelta
from typing import Any

from fastapi.exceptions import RequestValidationError

from zalpro_api.core.errors import conflict, forbidden
from zalpro_api.models import Membership, Order, Trainer, User

STAFF_ROLES = frozenset({"admin", "owner"})
STAFF_DIRECTORY_ROLES = frozenset({"admin", "owner", "barmen"})

TRAINER_PATCH_FIELDS = frozenset(
    {
        "plan_id",
        "plan_assigned_at",
        "goal",
        "metabolism",
        "gender",
        "age",
        "height",
        "activity",
        "home_workout_date",
        "subscription_expires_at",
        "program",
        "name",
    }
)

SELF_PATCH_FIELDS = frozenset(
    {"name", "gender", "age", "height", "activity", "metabolism", "goal", "gym_days", "weight"}
)

OWNER_TRAINER_PATCH_FIELDS = frozenset({"gym_id"})

WEIGH_IN_MIN_INTERVAL = timedelta(days=6)

SHOP_WRITER_ROLES = frozenset({"admin", "owner", "barmen"})
ORDER_HANDLER_STATUSES = frozenset({"given", "canceled"})


@dataclass(frozen=True)
class OrderScope:
    column: str | None
    value: str
    empty: bool = False


def is_owner(actor: User) -> bool:
    return actor.role == "owner"


def requires_window(actor: User, start: object | None, end: object | None) -> bool:
    missing = [name for name, value in (("from", start), ("to", end)) if value is None]
    if not missing:
        return True
    if len(missing) == 2 and is_owner(actor):
        return False
    raise RequestValidationError(
        [
            {"type": "missing", "loc": ("query", name), "msg": "Field required", "input": None}
            for name in missing
        ]
    )


def is_staff(actor: User) -> bool:
    return actor.role in STAFF_ROLES


def is_trainer_of(actor: User, target: User) -> bool:
    return is_staff(actor) and target.trainer_id == actor.id


def can_manage(actor: User, target: User) -> bool:
    return is_owner(actor) or is_trainer_of(actor, target)


def can_read_user(actor: User, target: User) -> bool:
    return actor.id == target.id or can_manage(actor, target)


def gym_of(user: User) -> str:
    return user.gym_id or ""


def is_trainer_self(actor: User, trainer_id: str) -> bool:
    return actor.id == trainer_id and actor.role == "admin"


def ensure_owner(actor: User) -> None:
    if not is_owner(actor):
        raise forbidden()


def user_list_scope(actor: User) -> str:
    if is_owner(actor):
        return "all"
    if is_staff(actor):
        return "own_students"
    if actor.role == "barmen":
        return "staff_directory"
    raise forbidden()


def ensure_staff(actor: User) -> None:
    if not is_staff(actor):
        raise forbidden()


def ensure_self(actor: User, user_id: str) -> None:
    if actor.id != user_id:
        raise forbidden()


def can_see_exercise_level(actor: User) -> bool:
    return is_staff(actor)


def ensure_can_read_user(actor: User, target: User) -> None:
    if not can_read_user(actor, target):
        raise forbidden()


def ensure_can_set_role(actor: User, target: User, role: str) -> None:
    ensure_owner(actor)
    if actor.id == target.id and role != target.role:
        raise conflict("cannot_change_own_role", "O'z rolingizni o'zgartira olmaysiz")


def ensure_can_delete_user(actor: User, target: User) -> None:
    ensure_owner(actor)
    if actor.id == target.id:
        raise conflict("cannot_delete_self", "O'z akkauntingizni o'chira olmaysiz")


def _allowed_patch_fields(actor: User, target: User) -> frozenset[str]:
    if is_trainer_of(actor, target):
        return TRAINER_PATCH_FIELDS
    if actor.id == target.id:
        return SELF_PATCH_FIELDS
    return frozenset()


def check_user_patch(actor: User, target: User, changes: dict[str, Any]) -> None:
    if is_owner(actor):
        if "role" in changes:
            ensure_can_set_role(actor, target, changes["role"])
        return
    allowed_fields = _allowed_patch_fields(actor, target)
    if not allowed_fields:
        raise forbidden()
    if not set(changes) <= allowed_fields:
        raise forbidden("field_not_allowed", "Bu maydonni o'zgartirishga ruxsat yo'q")
    if "weight" in changes and target.weight != 0:
        raise forbidden("weight_locked", "Vazn faqat o'lchov orqali o'zgaradi")


def ensure_can_assign_trainer(actor: User, target: User) -> None:
    if not is_owner(actor) and actor.id != target.id:
        raise forbidden()


def ensure_trainer_choice(actor: User, trainer: Trainer | None) -> None:
    if is_owner(actor):
        return
    if trainer is None or not trainer.accepting:
        raise forbidden("trainer_not_accepting", "Bu trener hozir shogird qabul qilmayapti")


def ensure_can_create_trainer(actor: User, trainer_id: str) -> None:
    if not is_owner(actor) and not is_trainer_self(actor, trainer_id):
        raise forbidden()


def ensure_can_update_trainer(actor: User, trainer_id: str, changes: dict[str, Any]) -> bool:
    if is_trainer_self(actor, trainer_id):
        return True
    if is_owner(actor) and set(changes) <= OWNER_TRAINER_PATCH_FIELDS:
        return False
    raise forbidden()


def ensure_can_manage(actor: User, target: User) -> None:
    if not can_manage(actor, target):
        raise forbidden()


def can_read_membership(actor: User, membership: Membership) -> bool:
    if actor.id == membership.user_id or is_owner(actor):
        return True
    actor_gym = gym_of(actor)
    return (is_staff(actor) or actor.role == "barmen") and (
        actor_gym != "" and membership.gym_id == actor_gym
    )


def ensure_can_read_membership(actor: User, membership: Membership) -> None:
    if not can_read_membership(actor, membership):
        raise forbidden()


def membership_scope(actor: User) -> str | None:
    if is_owner(actor):
        return None
    if is_staff(actor) or actor.role == "barmen":
        return gym_of(actor)
    raise forbidden()


def ensure_can_create_reminder(actor: User, client: User) -> None:
    if not is_staff(actor):
        raise forbidden()
    if not is_owner(actor) and client.trainer_id != actor.id:
        raise forbidden()


def reminder_trainer_scope(actor: User) -> str | None:
    return None if is_owner(actor) else actor.id


def is_barmen(actor: User) -> bool:
    return actor.role == "barmen"


def can_write_products(actor: User) -> bool:
    return actor.role in SHOP_WRITER_ROLES


def ensure_can_write_products(actor: User) -> None:
    if not can_write_products(actor):
        raise forbidden()


def can_see_cost_price(actor: User) -> bool:
    return actor.role != "user"


def order_scope(actor: User) -> OrderScope:
    if is_owner(actor):
        return OrderScope(column=None, value="")
    if actor.role == "admin":
        return OrderScope(column="trainer_id", value=actor.id)
    if is_barmen(actor):
        gym = gym_of(actor)
        return OrderScope(column="gym_id", value=gym, empty=gym == "")
    return OrderScope(column="client_id", value=actor.id)


def _handles_order(actor: User, order: Order) -> bool:
    if is_owner(actor):
        return True
    if actor.role == "admin":
        return order.trainer_id == actor.id
    if is_barmen(actor):
        actor_gym = gym_of(actor)
        return actor_gym != "" and order.gym_id == actor_gym
    return False


def can_read_order(actor: User, order: Order) -> bool:
    return order.client_id == actor.id or _handles_order(actor, order)


def ensure_can_read_order(actor: User, order: Order) -> None:
    if not can_read_order(actor, order):
        raise forbidden()


def ensure_can_set_order_status(actor: User, order: Order, status: str) -> None:
    if _handles_order(actor, order) and status in ORDER_HANDLER_STATUSES:
        return
    if order.client_id == actor.id and status == "canceled":
        return
    raise forbidden()


def can_read_chat(actor: User, chat_owner: User) -> bool:
    return actor.id == chat_owner.id or can_manage(actor, chat_owner)


def ensure_can_read_chat(actor: User, chat_owner: User) -> None:
    if not can_read_chat(actor, chat_owner):
        raise forbidden()


def ensure_can_post_chat(actor: User, chat_owner: User) -> None:
    if not can_read_chat(actor, chat_owner):
        raise forbidden()


def ensure_can_read_photos(actor: User, owner: User) -> None:
    if not can_read_user(actor, owner):
        raise forbidden()


def ensure_can_write_photos(actor: User, owner_id: str) -> None:
    ensure_self(actor, owner_id)
