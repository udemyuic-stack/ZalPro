import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Integer, Numeric, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class ExerciseSet(Base):
    __tablename__ = "exercise_sets"
    __table_args__ = (
        CheckConstraint("set_no >= 1", name="ck_exercise_sets_set_no"),
        CheckConstraint("reps is null or reps between 0 and 1000", name="ck_exercise_sets_reps"),
        CheckConstraint(
            "weight_kg is null or weight_kg between 0 and 1000", name="ck_exercise_sets_weight"
        ),
    )

    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    day: Mapped[datetime.date] = mapped_column(Date, primary_key=True)
    exercise_id: Mapped[str] = mapped_column(Text, primary_key=True)
    set_no: Mapped[int] = mapped_column(Integer, primary_key=True)
    weight_kg: Mapped[Decimal | None] = mapped_column(Numeric(6, 2))
    reps: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime.datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
