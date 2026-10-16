from typing import Annotated, ClassVar, Self

from pydantic import AfterValidator, BaseModel, ConfigDict, StringConstraints, model_validator

from zalpro_api.services.phone import normalize_phone

MIN_PHONE_DIGITS = 9
MAX_PHONE_DIGITS = 15


def validate_phone(value: str) -> str:
    normalized = normalize_phone(value)
    if not MIN_PHONE_DIGITS <= len(normalized) <= MAX_PHONE_DIGITS:
        raise ValueError("Telefon raqami noto'g'ri")
    return normalized


PhoneNumber = Annotated[str, AfterValidator(validate_phone)]
Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=60)]
Password = Annotated[str, StringConstraints(min_length=8, max_length=128)]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class OutModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class PatchModel(StrictModel):
    non_nullable: ClassVar[frozenset[str]] = frozenset()

    @model_validator(mode="after")
    def reject_null_for_required_fields(self) -> Self:
        for field in self.non_nullable & self.model_fields_set:
            if getattr(self, field) is None:
                raise ValueError(f"{field} bo'sh bo'lishi mumkin emas")
        return self
