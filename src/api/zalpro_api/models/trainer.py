from sqlalchemy import Boolean, ForeignKey, Text, true
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Trainer(Base):
    __tablename__ = "trainers"

    id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    name: Mapped[str] = mapped_column(Text)
    bio: Mapped[str] = mapped_column(Text, default="", server_default="")
    accepting: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true())
    gym_id: Mapped[str | None] = mapped_column(ForeignKey("gyms.id", ondelete="SET NULL"))
