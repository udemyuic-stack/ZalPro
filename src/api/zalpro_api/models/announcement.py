import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

MAX_TITLE_LENGTH = 80
MAX_BODY_LENGTH = 500
MAX_ACTIVE_PER_AUTHOR = 20
MAX_LISTED = 20


class Announcement(Base):
    __tablename__ = "announcements"
    __table_args__ = (
        CheckConstraint("char_length(title) between 1 and 80", name="title_length"),
        CheckConstraint("char_length(body) between 1 and 500", name="body_length"),
        Index("ix_announcements_created_at", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(Text)
    body: Mapped[str] = mapped_column(Text)
    author_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    trainer_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), default=None, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)
