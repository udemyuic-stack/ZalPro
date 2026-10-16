from typing import Annotated, Literal, Self

from pydantic import Field, StrictBool, StringConstraints, model_validator

from zalpro_api.models.product import PRODUCT_CATEGORIES
from zalpro_api.schemas.base import OutModel, PatchModel, StrictModel

MAX_INT = 2147483647

Category = Literal[*PRODUCT_CATEGORIES]
Currency = Literal["UZS", "USD"]
Money = Annotated[int, Field(strict=True, ge=0, le=MAX_INT)]
ProductName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
Variant = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=30)]
Url = Annotated[str, StringConstraints(max_length=500)]
Note = Annotated[str, StringConstraints(max_length=500)]
ShortName = Annotated[str, StringConstraints(max_length=120)]
SizeStock = dict[Variant, Annotated[int, Field(strict=True, ge=0, le=MAX_INT)]]


class ProductIn(StrictModel):
    category: Category
    name: ProductName
    note: Note = ""
    name_ru: ShortName = ""
    name_en: ShortName = ""
    note_ru: Note = ""
    note_en: Note = ""
    image: Url = ""
    images: list[Url] = Field(default_factory=list, max_length=20)
    sizes: list[Variant] = Field(default_factory=list, max_length=30)
    colors: list[Variant] = Field(default_factory=list, max_length=30)
    price: Money
    currency: Currency = "UZS"
    cost_price: Money = 0
    active: StrictBool = True
    size_stock: SizeStock = Field(default_factory=dict, max_length=30)
    stock: Money | None = None

    @model_validator(mode="after")
    def validate_stock_rules(self) -> Self:
        if len(set(self.sizes)) != len(self.sizes):
            raise ValueError("O'lchamlar takrorlanmasligi kerak")
        if len(set(self.colors)) != len(self.colors):
            raise ValueError("Ranglar takrorlanmasligi kerak")
        if self.sizes:
            if self.stock is not None:
                raise ValueError("O'lcham bor tovarda stock yuborilmaydi, size_stock ishlating")
            if not set(self.size_stock) <= set(self.sizes):
                raise ValueError("size_stock kalitlari sizes ichida bo'lishi kerak")
            total = sum(self.size_stock.values())
            if total > MAX_INT:
                raise ValueError("Ombor qoldig'i juda katta")
            self.stock = total
        else:
            if self.size_stock:
                raise ValueError("O'lchamsiz tovarda size_stock bo'lmasligi kerak")
            if self.stock is None:
                self.stock = 0
        return self


class ProductPatch(PatchModel):
    non_nullable = frozenset(ProductIn.model_fields)

    category: Category | None = None
    name: ProductName | None = None
    note: Note | None = None
    name_ru: ShortName | None = None
    name_en: ShortName | None = None
    note_ru: Note | None = None
    note_en: Note | None = None
    image: Url | None = None
    images: list[Url] | None = Field(default=None, max_length=20)
    sizes: list[Variant] | None = Field(default=None, max_length=30)
    colors: list[Variant] | None = Field(default=None, max_length=30)
    price: Money | None = None
    currency: Currency | None = None
    cost_price: Money | None = None
    active: StrictBool | None = None
    size_stock: SizeStock | None = Field(default=None, max_length=30)
    stock: Money | None = None


class ProductOut(OutModel):
    id: str
    category: str
    name: str
    note: str
    name_ru: str
    name_en: str
    note_ru: str
    note_en: str
    image: str
    images: list[str]
    sizes: list[str]
    colors: list[str]
    price: int
    currency: str
    stock: int
    size_stock: dict[str, int]
    cost_price: int | None
    active: bool
