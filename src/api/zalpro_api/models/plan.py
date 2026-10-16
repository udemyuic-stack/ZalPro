from typing import Any

from sqlalchemy import ARRAY, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Plan(Base):
    __tablename__ = "plans"

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    title: Mapped[str] = mapped_column(Text)
    note: Mapped[str] = mapped_column(Text, default="", server_default="")
    forbidden: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    meals: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, default=list, server_default="[]")
    week: Mapped[dict[str, Any]] = mapped_column(JSONB, default=dict, server_default="{}")
    photos: Mapped[dict[str, str]] = mapped_column(JSONB, default=dict, server_default="{}")
