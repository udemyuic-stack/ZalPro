import uuid
from datetime import datetime

from sqlalchemy import DateTime, Index, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Reminder(Base):
    __tablename__ = "reminders"
    __table_args__ = (Index("ix_reminders_trainer_id_sent_at", "trainer_id", "sent_at"),)

    id: Mapped[str] = mapped_column(Text, primary_key=True, default=lambda: uuid.uuid4().hex)
    client_id: Mapped[str] = mapped_column(Text)
    client_name: Mapped[str] = mapped_column(Text, default="", server_default="")
    trainer_id: Mapped[str] = mapped_column(Text, default="", server_default="")
    sent_by: Mapped[str] = mapped_column(Text)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    days_left: Mapped[int] = mapped_column(Integer)
