from __future__ import annotations

from fastapi import Request


def client_ip(request: Request) -> str:
    """Best-effort client address for rate limiting.

    When proxies append to X-Forwarded-For, the *rightmost* hop is added by the
    nearest trusted proxy (e.g. Render). Using the leftmost hop lets clients
    spoof a new IP per request and bypass limits.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        parts = [p.strip() for p in forwarded.split(",") if p.strip()]
        if parts:
            return parts[-1]
    if request.client and request.client.host:
        return request.client.host
    return "unknown"
