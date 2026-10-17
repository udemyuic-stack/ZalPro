import uuid

from sqlalchemy import Boolean, CheckConstraint, Integer, Text
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column

from zalpro_api.db.base import Base

PRODUCT_CATEGORIES = (
    "Forma",
    "Suv idishlari",
    "Anjomlar",
    "Protein",
    "Gainer",
    "Kreatin",
    "L-Karnitin",
    "L-Arginin",
    "Boshqa",
)

MAX_PRODUCT_IMAGES = 20

_CATEGORY_LIST = ", ".join(f"'{item}'" for item in PRODUCT_CATEGORIES)


class Product(Base):
    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint(f"category in ({_CATEGORY_LIST})", name="category_valid"),
        CheckConstraint("price >= 0", name="price_non_negative"),
        CheckConstraint("stock >= 0", name="stock_non_negative"),
        CheckConstraint("cost_price >= 0", name="cost_price_non_negative"),
        CheckConstraint("currency in ('UZS', 'USD')", name="currency_valid"),
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True, default=lambda: uuid.uuid4().hex)
    category: Mapped[str] = mapped_column(Text)
    name: Mapped[str] = mapped_column(Text)
    note: Mapped[str] = mapped_column(Text, default="", server_default="")
    name_ru: Mapped[str] = mapped_column(Text, default="", server_default="")
    name_en: Mapped[str] = mapped_column(Text, default="", server_default="")
    note_ru: Mapped[str] = mapped_column(Text, default="", server_default="")
    note_en: Mapped[str] = mapped_column(Text, default="", server_default="")
    image: Mapped[str] = mapped_column(Text, default="", server_default="")
    images: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    image_keys: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    sizes: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    colors: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    price: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    currency: Mapped[str] = mapped_column(Text, default="UZS", server_default="UZS")
    stock: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    size_stock: Mapped[dict[str, int]] = mapped_column(JSONB, default=dict, server_default="{}")
    cost_price: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
