import pytest

from zalpro_api.services.phone import normalize_phone


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("901234567", "998901234567"),
        ("90 123 45 67", "998901234567"),
        ("+998 (90) 123-45-67", "998901234567"),
        ("998901234567", "998901234567"),
        ("12345678", "12345678"),
        ("1234567890", "1234567890"),
        ("", ""),
        ("abc", ""),
        ("٩٠١٢٣٤٥٦٧", ""),
    ],
)
def test_normalize_phone_matches_dart_implementation(raw: str, expected: str) -> None:
    assert normalize_phone(raw) == expected
