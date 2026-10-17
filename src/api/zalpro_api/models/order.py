import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Index, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (
        CheckConstraint("qty between 1 and 20", name="qty_range"),
        CheckConstraint("price >= 0", name="price_non_negative"),
        CheckConstraint("cost_price is null or cost_price >= 0", name="cost_price_non_negative"),
        CheckConstraint("currency in ('UZS', 'USD')", name="currency_valid"),
        CheckConstraint("status in ('new', 'given', 'canceled')", name="status_valid"),
        Index("ix_orders_client_id_created_at", "client_id", "created_at"),
        Index("ix_orders_trainer_id_created_at", "trainer_id", "created_at"),
        Index("ix_orders_gym_id_created_at", "gym_id", "created_at"),
        Index("ix_orders_status_given_at", "status", "given_at"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True, default=lambda: uuid.uuid4().hex)
    client_id: Mapped[str] = mapped_column(Text)
    client_name: Mapped[str] = mapped_column(Text, default="", server_default="")
    client_phone: Mapped[str] = mapped_column(Text, default="", server_default="")
    trainer_id: Mapped[str] = mapped_column(Text, default="", server_default="")
    gym_id: Mapped[str] = mapped_column(Text, default="", server_default="")
    product_id: Mapped[str] = mapped_column(Text)
    product_name: Mapped[str] = mapped_column(Text)
    category: Mapped[str] = mapped_column(Text, default="", server_default="")
    size: Mapped[str] = mapped_column(Text, default="", server_default="")
    color: Mapped[str] = mapped_column(Text, default="", server_default="")
    price: Mapped[int] = mapped_column(Integer)
    cost_price: Mapped[int | None] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(Text, default="UZS", server_default="UZS")
    qty: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    status: Mapped[str] = mapped_column(Text, default="new", server_default="new")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    given_by: Mapped[str] = mapped_column(Text, default="", server_default="")
    given_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
