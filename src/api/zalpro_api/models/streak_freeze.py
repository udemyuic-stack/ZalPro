import datetime

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class StreakFreeze(Base):
    __tablename__ = "streak_freezes"
    __table_args__ = (
        CheckConstraint(
            "extract(isodow from week_start) = 1", name="ck_streak_freezes_week_start_monday"
        ),
    )

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    week_start: Mapped[datetime.date] = mapped_column(Date, primary_key=True)
    granted_by: Mapped[str | None] = mapped_column(
        Text, ForeignKey("users.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
