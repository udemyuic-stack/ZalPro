import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)

HTTP_ERROR_CODES = {404: "not_found", 405: "method_not_allowed"}


class ApiError(Exception):
    def __init__(
        self, status_code: int, code: str, message: str, headers: dict[str, str] | None = None
    ) -> None:
        super().__init__(message)
        self.headers = headers
        self.status_code = status_code
        self.code = code
        self.message = message


def bad_request(code: str, message: str) -> ApiError:
    return ApiError(400, code, message)


def unauthorized(code: str = "unauthorized", message: str = "Kirish talab qilinadi") -> ApiError:
    return ApiError(401, code, message)


def forbidden(code: str = "forbidden", message: str = "Bu amal uchun ruxsat yo'q") -> ApiError:
    return ApiError(403, code, message)


def not_found(message: str = "Topilmadi") -> ApiError:
    return ApiError(404, "not_found", message)


def conflict(code: str, message: str) -> ApiError:
    return ApiError(409, code, message)


def error_body(
    code: str, message: str, errors: list[dict[str, str]] | None = None
) -> dict[str, Any]:
    detail: dict[str, Any] = {"code": code, "message": message}
    if errors:
        detail["errors"] = errors
    return {"detail": detail}


def error_response(
    status_code: int,
    code: str,
    message: str,
    errors: list[dict[str, str]] | None = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    if status_code == 401:
        headers = {"WWW-Authenticate": "Bearer", **(headers or {})}
    return JSONResponse(error_body(code, message, errors), status_code=status_code, headers=headers)


async def handle_api_error(request: Request, error: ApiError) -> JSONResponse:
    return error_response(error.status_code, error.code, error.message, headers=error.headers)


async def handle_validation_error(request: Request, error: RequestValidationError) -> JSONResponse:
    errors = [
        {"field": ".".join(str(part) for part in item["loc"]), "message": item["msg"]}
        for item in error.errors()
    ]
    return error_response(422, "validation_error", "Ma'lumotlar noto'g'ri", errors)


async def handle_http_error(request: Request, error: StarletteHTTPException) -> JSONResponse:
    code = HTTP_ERROR_CODES.get(error.status_code, "http_error")
    return error_response(error.status_code, code, "So'rovni bajarib bo'lmadi")


async def handle_unexpected_error(request: Request, error: Exception) -> JSONResponse:
    logger.exception("unhandled_error", extra={"path": request.url.path})
    return error_response(500, "internal_error", "Ichki xatolik")


def register_error_handlers(app: FastAPI) -> None:
    app.add_exception_handler(ApiError, handle_api_error)
    app.add_exception_handler(RequestValidationError, handle_validation_error)
    app.add_exception_handler(StarletteHTTPException, handle_http_error)
    app.add_exception_handler(Exception, handle_unexpected_error)
