from sqlalchemy import Text
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base


class Gym(Base):
    __tablename__ = "gyms"

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    name: Mapped[str] = mapped_column(Text)
    address: Mapped[str] = mapped_column(Text, default="", server_default="")
    country: Mapped[str] = mapped_column(Text, default="", server_default="")
    region: Mapped[str] = mapped_column(Text, default="", server_default="")
    district: Mapped[str] = mapped_column(Text, default="", server_default="")
    map_url: Mapped[str] = mapped_column(Text, default="", server_default="")
