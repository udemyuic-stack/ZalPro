from httpx import ASGITransport, AsyncClient

from zalpro_api.core.config import Settings
from zalpro_api.main import create_app

ORIGIN = "https://app.example.com"
OTHER = "https://evil.example.com"


def make_settings(cors_origins: str) -> Settings:
    return Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://x:x@localhost/x",
        jwt_secret="x" * 32,
        cors_origins=cors_origins,
    )


def make_client(cors_origins: str) -> AsyncClient:
    app = create_app(make_settings(cors_origins))
    return AsyncClient(transport=ASGITransport(app=app), base_url="http://test")


def preflight_headers(origin: str) -> dict[str, str]:
    return {
        "Origin": origin,
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "authorization,content-type",
    }


def test_origin_list_strips_and_drops_empty() -> None:
    settings = make_settings(f" {ORIGIN} , ,{OTHER},")
    assert settings.cors_origin_list == [ORIGIN, OTHER]


def test_origin_list_empty_by_default() -> None:
    assert make_settings("").cors_origin_list == []
    assert make_settings(" , ").cors_origin_list == []


async def test_preflight_allowed_origin() -> None:
    async with make_client(ORIGIN) as client:
        response = await client.options("/v1/auth/login", headers=preflight_headers(ORIGIN))
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == ORIGIN
    assert response.headers["access-control-max-age"] == "600"
    assert "access-control-allow-credentials" not in response.headers
    allowed = response.headers["access-control-allow-headers"].lower()
    assert "authorization" in allowed
    assert "content-type" in allowed


async def test_preflight_disallowed_origin() -> None:
    async with make_client(ORIGIN) as client:
        response = await client.options("/v1/auth/login", headers=preflight_headers(OTHER))
    assert response.status_code == 400
    assert "access-control-allow-origin" not in response.headers


async def test_actual_request_allowed_origin() -> None:
    async with make_client(ORIGIN) as client:
        response = await client.get("/openapi.json", headers={"Origin": ORIGIN})
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == ORIGIN
    assert response.headers["access-control-expose-headers"] == "Retry-After"


async def test_actual_request_disallowed_origin() -> None:
    async with make_client(ORIGIN) as client:
        response = await client.get("/openapi.json", headers={"Origin": OTHER})
    assert "access-control-allow-origin" not in response.headers


async def test_whitespace_entries_are_ignored() -> None:
    async with make_client(f" , {ORIGIN} ,") as client:
        allowed = await client.options("/v1/auth/login", headers=preflight_headers(ORIGIN))
        blank = await client.options("/v1/auth/login", headers=preflight_headers(""))
    assert allowed.headers["access-control-allow-origin"] == ORIGIN
    assert "access-control-allow-origin" not in blank.headers


async def test_default_settings_have_no_cors_headers() -> None:
    async with make_client("") as client:
        preflight = await client.options("/v1/auth/login", headers=preflight_headers(ORIGIN))
        actual = await client.get("/openapi.json", headers={"Origin": ORIGIN})
    for response in (preflight, actual):
        assert not any(name.startswith("access-control-") for name in response.headers)
