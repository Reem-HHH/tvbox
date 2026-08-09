from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


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


@lru_cache
def get_settings() -> Settings:
    return Settings()
