from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class RepSession(Base):
    __tablename__ = "rep_sessions"
    __table_args__ = (
        CheckConstraint("status in ('valid', 'flagged', 'voided')", name="status_valid"),
        CheckConstraint("reps > 0 and duration_s > 0", name="positive_counts"),
        CheckConstraint("visibility_pct between 0 and 100", name="visibility_range"),
        Index("ix_rep_sessions_user_started", "user_id", "started_at"),
        Index("ix_rep_sessions_status_started", "status", "started_at"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    exercise_key: Mapped[str] = mapped_column(Text)
    reps: Mapped[int] = mapped_column(Integer)
    duration_s: Mapped[int] = mapped_column(Integer)
    visibility_pct: Mapped[int] = mapped_column(Integer)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    coins: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    xp: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    status: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
