import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Index, Integer, SmallInteger, Text, false, func, text
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Reminder(Base):
    __tablename__ = "reminders"
    __table_args__ = (
        Index("ix_reminders_trainer_id_sent_at", "trainer_id", "sent_at"),
        Index(
            "uq_reminders_auto_stage",
            "client_id",
            "auto_stage",
            "expires_ref",
            unique=True,
            postgresql_where=text("auto"),
        ),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True, default=lambda: uuid.uuid4().hex)
    client_id: Mapped[str] = mapped_column(Text)
    client_name: Mapped[str] = mapped_column(Text, default="", server_default="")
    trainer_id: Mapped[str] = mapped_column(Text, default="", server_default="")
    sent_by: Mapped[str] = mapped_column(Text)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    days_left: Mapped[int] = mapped_column(Integer)
    auto: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    expires_ref: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    auto_stage: Mapped[int | None] = mapped_column(SmallInteger)
