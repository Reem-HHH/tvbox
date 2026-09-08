"""Tests for production settings validation and client IP parsing."""

from __future__ import annotations

import pytest
from starlette.requests import Request as StarletteRequest
from starlette.types import Scope

from app.client_ip import client_ip
from app.config import Settings, get_settings, validate_settings


def test_is_production_from_https_public_url():
    s = Settings(
        production=False,
        public_base_url="https://kiddytube-cloud.onrender.com",
        admin_password="strong-enough",
        secret_key="strong-secret",
        database_url="postgresql://u:p@host/db",
    )
    assert s.is_production is True


def test_is_production_from_render_env(monkeypatch):
    monkeypatch.setenv("RENDER", "true")
    s = Settings(
        production=False,
        public_base_url="http://127.0.0.1:8787",
        admin_password="strong-enough",
        secret_key="strong-secret",
        database_url="postgresql://u:p@host/db",
    )
    assert s.is_production is True


def test_validate_settings_rejects_sqlite_in_production():
    s = Settings(
        production=True,
        admin_password="strong-enough",
        secret_key="strong-secret",
        database_url="sqlite:///./data/kiddytube.db",
    )
    with pytest.raises(RuntimeError, match="Postgres"):
        validate_settings(s)


def test_validate_settings_rejects_default_password_in_production():
    s = Settings(
        production=True,
        admin_password="change-me-now",
        secret_key="strong-secret",
        database_url="postgresql://u:p@host/db",
    )
    with pytest.raises(RuntimeError, match="ADMIN_PASSWORD"):
        validate_settings(s)


def test_validate_settings_allows_local_dev_defaults():
    get_settings.cache_clear()
    s = Settings(
        production=False,
        public_base_url="http://127.0.0.1:8787",
        admin_password="change-me-now",
        secret_key="dev-secret-change-me",
        database_url="sqlite:///./data/kiddytube.db",
    )
    validate_settings(s)  # must not raise


def _request_with_xff(xff: str | None, client_host: str = "10.0.0.1") -> StarletteRequest:
    headers = []
    if xff is not None:
        headers.append((b"x-forwarded-for", xff.encode("latin-1")))
    scope: Scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "GET",
        "scheme": "http",
        "path": "/",
        "raw_path": b"/",
        "query_string": b"",
        "headers": headers,
        "client": (client_host, 12345),
        "server": ("test", 80),
    }
    return StarletteRequest(scope)


def test_client_ip_uses_rightmost_forwarded_hop():
    req = _request_with_xff("203.0.113.50, 10.1.2.3")
    assert client_ip(req) == "10.1.2.3"


def test_client_ip_falls_back_to_socket_peer():
    req = _request_with_xff(None, client_host="192.0.2.10")
    assert client_ip(req) == "192.0.2.10"
