import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Integer, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

MUSCLES = ("arms", "chest", "legs")


class ChallengeStep(Base):
    __tablename__ = "challenge_steps"
    __table_args__ = (
        CheckConstraint("position >= 0", name="position_non_negative"),
        CheckConstraint("target > 0", name="target_positive"),
        CheckConstraint("coins >= 0", name="coins_non_negative"),
        CheckConstraint("muscle in ('arms', 'chest', 'legs')", name="muscle_valid"),
        UniqueConstraint("position", name="uq_challenge_steps_position"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True, default=lambda: uuid.uuid4().hex)
    position: Mapped[int] = mapped_column(Integer)
    exercise: Mapped[str] = mapped_column(Text)
    target: Mapped[int] = mapped_column(Integer)
    coins: Mapped[int] = mapped_column(Integer)
    muscle: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
