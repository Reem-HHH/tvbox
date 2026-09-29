"""Simple in-process rate limiter for auth endpoints (pair / enroll / login)."""

from __future__ import annotations

import time
from collections import defaultdict
from threading import Lock


class RateLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()

    def allow(self, key: str, *, limit: int, window_seconds: float) -> bool:
        """Return True if under limit; records this attempt when allowed."""
        now = time.monotonic()
        with self._lock:
            bucket = [t for t in self._hits[key] if now - t < window_seconds]
            if len(bucket) >= limit:
                self._hits[key] = bucket
                return False
            bucket.append(now)
            self._hits[key] = bucket
            return True

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()


# Shared process-wide limiter (fine for single uvicorn worker / household deploy).
auth_limiter = RateLimiter()
