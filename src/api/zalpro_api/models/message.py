import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

MESSAGE_KINDS = ("user", "system")
MAX_MESSAGE_LENGTH = 2000
MAX_CHAT_VIDEO_BYTES = 50 * 1024 * 1024
MAX_CHAT_AUDIO_BYTES = 5 * 1024 * 1024
MAX_CHAT_AUDIO_MS = 300_000


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (
        CheckConstraint("kind in ('user', 'system')", name="kind_valid"),
        CheckConstraint(
            "char_length(text) <= 2000 and (char_length(text) >= 1 or media_key is not null)",
            name="text_length",
        ),
        CheckConstraint(
            "media_kind is null or media_kind in ('image', 'video', 'audio')",
            name="media_kind_valid",
        ),
        CheckConstraint(
            "media_duration_ms is null or "
            "(media_kind = 'audio' and media_duration_ms between 1 and 300000)",
            name="media_duration_valid",
        ),
        CheckConstraint(
            "media_status is null or media_status in ('processing', 'ready', 'failed')",
            name="media_status_valid",
        ),
        Index("ix_messages_chat_uid_created_at", "chat_uid", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    chat_uid: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    sender_id: Mapped[str] = mapped_column(Text)
    kind: Mapped[str] = mapped_column(Text, server_default="user")
    text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    media_key: Mapped[str | None] = mapped_column(Text, default=None)
    media_kind: Mapped[str | None] = mapped_column(Text, default=None)
    media_status: Mapped[str | None] = mapped_column(Text, default=None)
    media_duration_ms: Mapped[int | None] = mapped_column(Integer, default=None)
