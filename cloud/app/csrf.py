"""CSRF helpers for cookie-authenticated admin forms."""

from __future__ import annotations

import secrets

from fastapi import HTTPException, Request, status


def ensure_csrf_token(request: Request) -> str:
    token = request.session.get("csrf_token")
    if not token or not isinstance(token, str):
        token = secrets.token_urlsafe(32)
        request.session["csrf_token"] = token
    return token


def require_csrf(request: Request, token: str | None) -> None:
    expected = request.session.get("csrf_token")
    provided = (token or "").strip()
    if (
        not expected
        or not isinstance(expected, str)
        or not provided
        or not secrets.compare_digest(expected, provided)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid CSRF token",
        )
