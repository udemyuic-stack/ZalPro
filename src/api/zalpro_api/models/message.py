import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

MESSAGE_KINDS = ("user", "system")
MAX_MESSAGE_LENGTH = 2000


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (
        CheckConstraint("kind in ('user', 'system')", name="kind_valid"),
        CheckConstraint("char_length(text) between 1 and 2000", name="text_length"),
        Index("ix_messages_chat_uid_created_at", "chat_uid", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    chat_uid: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    sender_id: Mapped[str] = mapped_column(Text)
    kind: Mapped[str] = mapped_column(Text, server_default="user")
    text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
