from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Membership(Base):
    __tablename__ = "memberships"
    __table_args__ = (
        CheckConstraint("months between 0 and 24", name="months_range"),
        CheckConstraint("days between 0 and 31", name="days_range"),
        CheckConstraint("price >= 0", name="price_non_negative"),
        CheckConstraint("currency in ('UZS', 'USD')", name="currency_valid"),
    )

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    name: Mapped[str] = mapped_column(Text, default="", server_default="")
    gym_id: Mapped[str] = mapped_column(Text, default="", server_default="")
    months: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    days: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    price: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    currency: Mapped[str] = mapped_column(Text, default="UZS", server_default="UZS")
    paid_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
