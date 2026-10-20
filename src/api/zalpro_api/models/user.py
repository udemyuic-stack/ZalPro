from datetime import datetime
from typing import Any

from sqlalchemy import (
    ARRAY,
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    Text,
    func,
    true,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

ROLES = ("user", "admin", "owner", "barmen")


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("role in ('user', 'admin', 'owner', 'barmen')", name="role_valid"),
        CheckConstraint(
            "(legacy_hash is null and legacy_salt is null and legacy_algo is null) "
            "or (legacy_hash is not null and legacy_algo in ('scrypt', 'bcrypt'))",
            name="legacy_consistent",
        ),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    name: Mapped[str] = mapped_column(Text, default="", server_default="")
    phone: Mapped[str] = mapped_column(Text, unique=True)
    password_hash: Mapped[str] = mapped_column(Text)
    legacy_hash: Mapped[str | None] = mapped_column(Text)
    legacy_salt: Mapped[str | None] = mapped_column(Text)
    legacy_algo: Mapped[str | None] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text, default="user", server_default="user")
    gender: Mapped[str | None] = mapped_column(Text)
    age: Mapped[int | None] = mapped_column(Integer)
    height: Mapped[float | None] = mapped_column(Float)
    weight: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    activity: Mapped[float | None] = mapped_column(Float)
    metabolism: Mapped[str | None] = mapped_column(Text)
    goal: Mapped[str | None] = mapped_column(Text)
    plan_id: Mapped[str | None] = mapped_column(Text)
    plan_assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    trainer_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    gym_id: Mapped[str | None] = mapped_column(
        ForeignKey("gyms.id", ondelete="SET NULL"), index=True
    )
    gym_days: Mapped[list[int]] = mapped_column(ARRAY(Integer), default=list, server_default="{}")
    home_workout_date: Mapped[str | None] = mapped_column(Text)
    subscription_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_weigh_in: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    show_in_leaderboard: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true())
    game_enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true())
    program: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict, server_default="{}")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
