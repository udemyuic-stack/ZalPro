import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Text, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

PLATFORMS = ("android", "web", "ios")
MAX_PUSH_TOKEN_LENGTH = 4096


class PushToken(Base):
    __tablename__ = "push_tokens"
    __table_args__ = (
        CheckConstraint("platform in ('android', 'web', 'ios')", name="platform_valid"),
        CheckConstraint("char_length(token) between 1 and 4096", name="token_length"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(Text, unique=True)
    platform: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
