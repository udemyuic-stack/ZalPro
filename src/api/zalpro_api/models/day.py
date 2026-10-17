import datetime
from typing import Any

from sqlalchemy import (
    ARRAY,
    Boolean,
    CheckConstraint,
    Date,
    ForeignKey,
    Integer,
    SmallInteger,
    Text,
    false,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Day(Base):
    __tablename__ = "days"
    __table_args__ = (
        CheckConstraint("water between 0 and 30", name="water_range"),
        CheckConstraint("feedback between 1 and 3", name="feedback_range"),
    )

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    day: Mapped[datetime.date] = mapped_column(Date, primary_key=True)
    done: Mapped[list[int]] = mapped_column(ARRAY(Integer), default=list, server_default="{}")
    extras: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, default=list, server_default="[]")
    gym_started: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    gym_done: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    water: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    feedback: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
