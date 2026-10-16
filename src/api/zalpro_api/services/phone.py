import re

_NON_DIGITS = re.compile(r"[^0-9]")
_LOCAL_NUMBER_LENGTH = 9
_COUNTRY_CODE = "998"


def normalize_phone(raw: str) -> str:
    digits = _NON_DIGITS.sub("", raw)
    if len(digits) == _LOCAL_NUMBER_LENGTH:
        return _COUNTRY_CODE + digits
    return digits
