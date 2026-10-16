from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send

from zalpro_api.core.errors import error_body

VERSION_HEADER = b"x-app-version"
GATE_PREFIX = "/v1/"
CONFIG_PATH = "/v1/app/config"


def parse_build(value: str | None) -> int | None:
    if not value or "+" not in value:
        return None
    build = value.rsplit("+", 1)[1].strip()
    return int(build) if build.isascii() and build.isdigit() else None


class AppVersionGate:
    def __init__(self, app: ASGIApp, min_build: int, download_url: str) -> None:
        self.app = app
        self.min_build = min_build
        self.download_url = download_url

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http" and self.is_outdated(scope):
            body = error_body("upgrade_required", "Ilovani yangilang")
            body["detail"]["download_url"] = self.download_url
            await JSONResponse(body, status_code=426)(scope, receive, send)
            return
        await self.app(scope, receive, send)

    def is_outdated(self, scope: Scope) -> bool:
        path = scope["path"]
        if not path.startswith(GATE_PREFIX) or path == CONFIG_PATH:
            return False
        for name, value in scope["headers"]:
            if name == VERSION_HEADER:
                build = parse_build(value.decode("latin-1"))
                return build is not None and build < self.min_build
        return False
