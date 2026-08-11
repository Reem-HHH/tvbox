from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles

from .auth import ensure_admin, mount_session_middleware
from .catalog_service import get_catalog_document
from .config import get_settings, validate_settings
from .db import SessionLocal
from .migrate import ensure_schema
from .routers import admin_web, api_v1


def create_app() -> FastAPI:
    settings = get_settings()
    validate_settings(settings)
    Path("data").mkdir(parents=True, exist_ok=True)

    docs = None if settings.is_production else "/docs"
    redoc = None if settings.is_production else "/redoc"
    app = FastAPI(
        title="KiddyTube Cloud",
        version="0.1.0",
        docs_url=docs,
        redoc_url=redoc,
        openapi_url=None if settings.is_production else "/openapi.json",
    )
    mount_session_middleware(app, settings)

    static_dir = Path(__file__).resolve().parent / "static"
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

    app.include_router(api_v1.router)
    app.include_router(admin_web.router)

    @app.on_event("startup")
    def _startup() -> None:
        ensure_schema()
        db = SessionLocal()
        try:
            ensure_admin(db, settings)
            get_catalog_document(db)
        finally:
            db.close()

    @app.get("/")
    def root():
        return RedirectResponse("/admin")

    @app.get("/health")
    def health():
        return {"ok": True}

    return app


app = create_app()
