from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


def normalize_database_url(url: str) -> str:
    """Accept Neon/Render postgres URLs and force the psycopg3 SQLAlchemy driver."""
    u = url.strip()
    if u.startswith("postgres://"):
        u = "postgresql://" + u[len("postgres://") :]
    if u.startswith("postgresql://") and "+psycopg" not in u.split("://", 1)[0]:
        u = "postgresql+psycopg://" + u[len("postgresql://") :]
    return u


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    admin_email: str = "admin@example.com"
    admin_password: str = "change-me-now"
    secret_key: str = "dev-secret-change-me"
    database_url: str = "sqlite:///./data/kiddytube.db"
    public_base_url: str = "http://127.0.0.1:8787"
    pairing_code_ttl_seconds: int = 600
    session_cookie_name: str = "kt_admin_session"
    session_max_age_seconds: int = 60 * 60 * 12

    @property
    def sqlalchemy_database_url(self) -> str:
        return normalize_database_url(self.database_url)


@lru_cache
def get_settings() -> Settings:
    return Settings()
