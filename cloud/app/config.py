from functools import lru_cache
import os

from pydantic_settings import BaseSettings, SettingsConfigDict


def normalize_database_url(url: str) -> str:
    """Accept Neon/Render postgres URLs and force the psycopg3 SQLAlchemy driver."""
    u = url.strip()
    if u.startswith("postgres://"):
        u = "postgresql://" + u[len("postgres://") :]
    if u.startswith("postgresql://") and "+psycopg" not in u.split("://", 1)[0]:
        u = "postgresql+psycopg://" + u[len("postgresql://") :]
    return u


def _truthy_env(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    admin_email: str = "admin@example.com"
    admin_password: str = "change-me-now"
    secret_key: str = "dev-secret-change-me"
    database_url: str = "sqlite:///./data/kiddytube.db"
    public_base_url: str = "http://127.0.0.1:8787"
    # Shared with Flutter builds (CLOUD_ENROLL_SECRET). Empty = enroll disabled.
    device_enroll_secret: str = ""
    pairing_code_ttl_seconds: int = 600
    session_cookie_name: str = "kt_admin_session"
    session_max_age_seconds: int = 60 * 60 * 12
    # When true (or inferred from HTTPS / Render), refuse insecure defaults.
    production: bool = False

    @property
    def sqlalchemy_database_url(self) -> str:
        return normalize_database_url(self.database_url)

    @property
    def is_production(self) -> bool:
        if self.production or _truthy_env("PRODUCTION"):
            return True
        # Render sets RENDER=true on every web service — do not wait for PUBLIC_BASE_URL.
        if _truthy_env("RENDER") or os.environ.get("RENDER_EXTERNAL_URL", "").strip():
            return True
        base = self.public_base_url.strip().lower()
        return base.startswith("https://") and "127.0.0.1" not in base and "localhost" not in base


def validate_settings(settings: Settings) -> None:
    """Refuse to boot a public deploy with known-insecure defaults or ephemeral SQLite."""
    if not settings.is_production:
        return
    if settings.admin_password in {"", "change-me-now"}:
        raise RuntimeError("ADMIN_PASSWORD must be set to a strong value in production")
    if settings.secret_key in {"", "dev-secret-change-me"}:
        raise RuntimeError("SECRET_KEY must be set to a strong value in production")
    db = settings.sqlalchemy_database_url.lower()
    if db.startswith("sqlite"):
        raise RuntimeError(
            "DATABASE_URL must be Postgres in production (SQLite is ephemeral on Render)"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
