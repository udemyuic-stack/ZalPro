from datetime import datetime

from sqlalchemy import ARRAY, CheckConstraint, DateTime, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

MUSCLES = (
    "chest",
    "shoulders",
    "biceps",
    "triceps",
    "forearms",
    "abs",
    "back",
    "traps",
    "glutes",
    "quads",
    "hamstrings",
    "calves",
)
LEVELS = ("", "beginner", "middle", "pro")
MAX_VIDEO_BYTES = 100 * 1024 * 1024


def _in_list(column: str, values: tuple[str, ...]) -> str:
    return f"{column} in ({', '.join(repr(value) for value in values)})"


class Exercise(Base):
    __tablename__ = "exercises"
    __table_args__ = (
        CheckConstraint(_in_list("muscle", MUSCLES), name="muscle_valid"),
        CheckConstraint(_in_list("level", LEVELS), name="level_valid"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    name: Mapped[str] = mapped_column(Text)
    muscle: Mapped[str] = mapped_column(Text)
    sets: Mapped[str] = mapped_column(Text, default="", server_default="")
    tip: Mapped[str] = mapped_column(Text, default="", server_default="")
    also: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    video: Mapped[str] = mapped_column(Text, default="", server_default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    created_by: Mapped[str] = mapped_column(Text)
    base: Mapped[str] = mapped_column(Text, default="", server_default="")
    level: Mapped[str] = mapped_column(Text, default="", server_default="")
    video_key: Mapped[str | None] = mapped_column(Text, default=None)
    video_status: Mapped[str | None] = mapped_column(Text, default=None)

    @property
    def has_video(self) -> bool:
        return self.video_key is not None
