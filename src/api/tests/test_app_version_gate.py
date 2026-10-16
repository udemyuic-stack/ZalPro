from collections.abc import AsyncIterator

import pytest
from httpx import ASGITransport, AsyncClient

from zalpro_api.api.deps import get_session
from zalpro_api.core.app_version import parse_build
from zalpro_api.core.config import Settings
from zalpro_api.main import create_app

DOWNLOAD_URL = "https://example.com/app.apk"


async def no_session() -> AsyncIterator[None]:
    yield None


def make_client(min_build: int, origins: str = "") -> AsyncClient:
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://x:x@localhost/x",
        jwt_secret="x" * 32,
        min_app_build=min_build,
        app_download_url=DOWNLOAD_URL,
        cors_origins=origins,
    )
    app = create_app(settings)
    app.dependency_overrides[get_session] = no_session
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("1.0.0+7", 7),
        ("2.3.1+120", 120),
        ("1.0.0", None),
        ("1.0.0+", None),
        ("1.0.0+x", None),
        ("1.0.0+-3", None),
        ("", None),
        (None, None),
    ],
)
def test_parse_build(value: str | None, expected: int | None) -> None:
    assert parse_build(value) == expected


async def test_old_build_gets_426_with_download_url() -> None:
    async with make_client(5) as client:
        response = await client.get("/v1/gyms", headers={"X-App-Version": "1.0.0+4"})
    assert response.status_code == 426
    detail = response.json()["detail"]
    assert detail["code"] == "upgrade_required"
    assert detail["download_url"] == DOWNLOAD_URL


async def test_current_build_passes_gate() -> None:
    async with make_client(5) as client:
        response = await client.get("/v1/gyms", headers={"X-App-Version": "1.0.0+5"})
    assert response.status_code == 401


async def test_missing_or_unparseable_header_passes_gate() -> None:
    async with make_client(5) as client:
        missing = await client.get("/v1/gyms")
        garbage = await client.get("/v1/gyms", headers={"X-App-Version": "abc"})
    assert missing.status_code == 401
    assert garbage.status_code == 401


async def test_app_config_is_open_even_for_old_build() -> None:
    async with make_client(5) as client:
        response = await client.get("/v1/app/config", headers={"X-App-Version": "1.0.0+1"})
    assert response.status_code == 200
    assert response.json() == {"min_app_build": 5, "download_url": DOWNLOAD_URL}


async def test_health_is_not_gated() -> None:
    async with make_client(5) as client:
        client._transport = ASGITransport(app=client._transport.app, raise_app_exceptions=False)
        response = await client.get("/health", headers={"X-App-Version": "1.0.0+1"})
    assert response.status_code != 426


async def test_zero_min_build_disables_gate() -> None:
    async with make_client(0) as client:
        response = await client.get("/v1/gyms", headers={"X-App-Version": "1.0.0+0"})
    assert response.status_code == 401


async def test_426_carries_cors_headers() -> None:
    origin = "https://app.example.com"
    async with make_client(5, origin) as client:
        response = await client.get(
            "/v1/gyms", headers={"X-App-Version": "1.0.0+1", "Origin": origin}
        )
    assert response.status_code == 426
    assert response.headers["access-control-allow-origin"] == origin


async def test_preflight_allows_version_header() -> None:
    origin = "https://app.example.com"
    async with make_client(5, origin) as client:
        response = await client.options(
            "/v1/gyms",
            headers={
                "Origin": origin,
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization,x-app-version",
            },
        )
    assert response.status_code == 200
