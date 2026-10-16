import datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Attendance(Base):
    __tablename__ = "attendance"

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    day: Mapped[datetime.date] = mapped_column(Date, primary_key=True)
    present: Mapped[bool] = mapped_column(Boolean)
    marked_by: Mapped[str] = mapped_column(Text)
    marked_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
