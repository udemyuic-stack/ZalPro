from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import APIRouter, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from zalpro_api.api.deps import SessionDep
from zalpro_api.api.routes import (
    app_config,
    attendance,
    auth,
    chat_ws,
    days,
    exercises,
    finance,
    foods,
    gyms,
    memberships,
    messages,
    orders,
    photos,
    plans,
    products,
    push_tokens,
    ratings,
    reminders,
    stats,
    subscriptions,
    trainers,
    users,
    weights,
)
from zalpro_api.core.app_version import AppVersionGate
from zalpro_api.core.config import Settings
from zalpro_api.core.errors import register_error_handlers
from zalpro_api.db.session import create_engine, create_sessionmaker
from zalpro_api.services.chat_hub import ChatHub
from zalpro_api.services.login_throttle import LoginThrottle
from zalpro_api.services.storage import build_storage


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    engine = create_engine(app.state.settings.database_url)
    app.state.engine = engine
    app.state.sessionmaker = create_sessionmaker(engine)
    try:
        yield
    finally:
        await engine.dispose()


def build_v1_router() -> APIRouter:
    router = APIRouter(prefix="/v1")
    for module in (
        app_config,
        auth,
        users,
        gyms,
        trainers,
        foods,
        plans,
        exercises,
        days,
        weights,
        ratings,
        subscriptions,
        memberships,
        attendance,
        reminders,
        finance,
        products,
        orders,
        messages,
        chat_ws,
        photos,
        push_tokens,
        stats,
    ):
        router.include_router(module.router)
    return router


def create_app(settings: Settings | None = None) -> FastAPI:
    app = FastAPI(title="ZalPro API", version="0.1.0", lifespan=lifespan)
    app.state.settings = settings or Settings()
    app.state.hub = ChatHub()
    app.state.login_throttle = LoginThrottle(
        app.state.settings.login_max_attempts, app.state.settings.login_window_seconds
    )
    app.state.storage = build_storage(app.state.settings)
    register_error_handlers(app)
    if app.state.settings.min_app_build > 0:
        app.add_middleware(
            AppVersionGate,
            min_build=app.state.settings.min_app_build,
            download_url=app.state.settings.app_download_url,
        )
    origins = app.state.settings.cors_origin_list
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=False,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            allow_headers=["Authorization", "Content-Type", "X-App-Version"],
            expose_headers=["Retry-After"],
            max_age=600,
        )
    app.include_router(build_v1_router())

    @app.get("/health", tags=["health"])
    async def health(session: SessionDep) -> dict[str, str]:
        await session.execute(text("SELECT 1"))
        return {"status": "ok"}

    return app


app = create_app()
