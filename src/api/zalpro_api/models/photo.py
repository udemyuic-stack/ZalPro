import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

MAX_PHOTO_BYTES = 358400
MAX_PHOTO_WEIGHT = 500
MAX_IMAGE_BYTES = 5 * 1024 * 1024


class Photo(Base):
    __tablename__ = "photos"
    __table_args__ = (
        CheckConstraint("weight > 0 and weight <= 500", name="weight_range"),
        CheckConstraint("size between 1 and 358400", name="size_range"),
        Index("ix_photos_user_id_taken_at", "user_id", "taken_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    key: Mapped[str] = mapped_column(Text, unique=True)
    taken_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    weight: Mapped[float] = mapped_column(Float)
    size: Mapped[int] = mapped_column(Integer)
