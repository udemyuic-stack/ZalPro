import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Index,
    Integer,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class PaymentOrder(Base):
    """Talabaning ilova ichidagi abonement to'lovi (Payme yoki Click orqali)."""

    __tablename__ = "payment_orders"
    __table_args__ = (
        CheckConstraint("provider in ('payme', 'click')", name="provider_valid"),
        CheckConstraint(
            "status in ('pending', 'created', 'paid', 'canceled')", name="status_valid"
        ),
        CheckConstraint("months between 1 and 24", name="months_range"),
        CheckConstraint("amount > 0", name="amount_positive"),
        CheckConstraint("currency = 'UZS'", name="currency_valid"),
        Index("ix_payment_orders_user_id_created_at", "user_id", "created_at"),
        Index("ix_payment_orders_provider_time", "provider", "provider_time"),
        Index(
            "uq_payment_orders_provider_trans_id",
            "provider",
            "provider_trans_id",
            unique=True,
            postgresql_where="provider_trans_id is not null",
        ),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True, default=lambda: uuid.uuid4().hex)
    seq: Mapped[int] = mapped_column(BigInteger, Identity(always=True), unique=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    provider: Mapped[str] = mapped_column(Text)
    months: Mapped[int] = mapped_column(Integer)
    amount: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(Text, default="UZS", server_default="UZS")
    status: Mapped[str] = mapped_column(Text, default="pending", server_default="pending")
    provider_trans_id: Mapped[str | None] = mapped_column(Text)
    provider_time: Mapped[int | None] = mapped_column(BigInteger)
    subscription_id: Mapped[str | None] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="SET NULL")
    )
    cancel_reason: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    transaction_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    performed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    canceled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
