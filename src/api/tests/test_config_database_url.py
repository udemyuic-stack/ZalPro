import pytest

from zalpro_api.core.config import Settings

SECRET = "x" * 32


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("postgres://u:p@h:5432/d", "postgresql+asyncpg://u:p@h:5432/d"),
        ("postgresql://u:p@h/d", "postgresql+asyncpg://u:p@h/d"),
        ("postgresql+asyncpg://u:p@h/d", "postgresql+asyncpg://u:p@h/d"),
        ("postgres://u:p@h/d?sslmode=require", "postgresql+asyncpg://u:p@h/d?ssl=require"),
    ],
)
def test_database_url_is_normalized(raw: str, expected: str) -> None:
    assert Settings(database_url=raw, jwt_secret=SECRET).database_url == expected
