from sqlalchemy import CheckConstraint, Float, Text
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Food(Base):
    __tablename__ = "foods"
    __table_args__ = (
        CheckConstraint(
            "kcal >= 0 and protein >= 0 and fat >= 0 and carbs >= 0", name="nutrition_non_negative"
        ),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    name: Mapped[str] = mapped_column(Text)
    kcal: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    protein: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    fat: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    carbs: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    image: Mapped[str] = mapped_column(Text, default="", server_default="")
    image_key: Mapped[str | None] = mapped_column(Text, default=None)
