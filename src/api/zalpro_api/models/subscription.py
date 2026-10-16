import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Subscription(Base):
    __tablename__ = "subscriptions"
    __table_args__ = (
        CheckConstraint("months between 0 and 24", name="months_range"),
        CheckConstraint("days between 0 and 31", name="days_range"),
        CheckConstraint("(months > 0) <> (days > 0)", name="kind_exclusive"),
        CheckConstraint("price >= 0", name="price_non_negative"),
        CheckConstraint("currency in ('UZS', 'USD')", name="currency_valid"),
        Index("ix_subscriptions_user_id_start_date", "user_id", "start_date"),
        Index("ix_subscriptions_paid_date", "paid_date"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True, default=lambda: uuid.uuid4().hex)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    months: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    days: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    price: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    currency: Mapped[str] = mapped_column(Text, default="UZS", server_default="UZS")
    paid_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
