import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Float, ForeignKey, Index, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Weight(Base):
    __tablename__ = "weights"
    __table_args__ = (
        CheckConstraint("weight > 0 and weight <= 500", name="weight_range"),
        Index("ix_weights_user_id_date", "user_id", "date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    weight: Mapped[float] = mapped_column(Float)
