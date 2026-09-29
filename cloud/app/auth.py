from __future__ import annotations

import hashlib
import secrets
from datetime import timedelta
from typing import Optional, Tuple

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from starlette.middleware.sessions import SessionMiddleware

from .config import Settings
from .db import get_db
from .models import AdminUser, Device, PairingCode, utcnow

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
bearer = HTTPBearer(auto_error=False)

# Real bcrypt hash used only to equalize login timing when the email is unknown.
DUMMY_PASSWORD_HASH = pwd_context.hash("timing-equalization-dummy-not-a-password")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def new_device_token() -> str:
    return secrets.token_urlsafe(32)


def new_pairing_code() -> str:
    # 6-digit numeric, easy to type on TV remote.
    return f"{secrets.randbelow(1_000_000):06d}"


def ensure_admin(db: Session, settings: Settings) -> AdminUser:
    email = settings.admin_email.lower().strip()
    user = db.query(AdminUser).filter(AdminUser.email == email).first()
    if user is None:
        user = AdminUser(
            email=email,
            password_hash=hash_password(settings.admin_password),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user
    # Keep DB password in sync when ADMIN_PASSWORD env changes (Render redeploy).
    if not verify_password(settings.admin_password, user.password_hash):
        user.password_hash = hash_password(settings.admin_password)
        db.commit()
        db.refresh(user)
    return user


def get_current_device(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(bearer),
    db: Session = Depends(get_db),
) -> Device:
    if creds is None or not creds.credentials:
        raise HTTPException(status_code=401, detail="Missing device token")
    token = creds.credentials.strip()
    device = (
        db.query(Device)
        .filter(Device.token_hash == hash_token(token), Device.revoked.is_(False))
        .first()
    )
    if device is None:
        raise HTTPException(status_code=401, detail="Invalid or revoked device token")
    device.last_seen_at = utcnow()
    db.commit()
    return device


def create_pairing_code(db: Session, settings: Settings, device_name_hint: str = "") -> PairingCode:
    # Invalidate older unused codes to keep the table small.
    now = utcnow()
    db.query(PairingCode).filter(
        PairingCode.consumed_at.is_(None),
        PairingCode.expires_at < now,
    ).delete()
    for _ in range(8):
        candidate = new_pairing_code()
        existing = db.query(PairingCode).filter(PairingCode.code == candidate).first()
        if existing is None:
            code = PairingCode(
                code=candidate,
                device_name_hint=device_name_hint.strip()[:120],
                expires_at=now + timedelta(seconds=settings.pairing_code_ttl_seconds),
            )
            db.add(code)
            db.commit()
            db.refresh(code)
            return code
    raise HTTPException(status_code=500, detail="Could not allocate pairing code")


def pair_device(
    db: Session,
    code: str,
    name: str,
    platform: str,
) -> Tuple[Device, str]:
    now = utcnow()
    normalized = code.strip()
    # Atomic claim: only one concurrent request can set consumed_at.
    claimed = (
        db.query(PairingCode)
        .filter(
            PairingCode.code == normalized,
            PairingCode.consumed_at.is_(None),
            PairingCode.expires_at >= now,
        )
        .update({PairingCode.consumed_at: now}, synchronize_session=False)
    )
    if claimed != 1:
        db.rollback()
        raise HTTPException(status_code=400, detail="Invalid or expired pairing code")

    row = db.query(PairingCode).filter(PairingCode.code == normalized).one()
    raw_token = new_device_token()
    device = Device(
        name=(name or row.device_name_hint or "Device").strip()[:120],
        platform=(platform or "unknown").strip()[:40],
        token_hash=hash_token(raw_token),
        token_prefix=raw_token[:8],
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return device, raw_token


def enroll_device(
    db: Session,
    settings: Settings,
    secret: str,
    name: str,
    platform: str,
) -> Tuple[Device, str]:
    """Register a device that was built with the family enroll secret (no pairing code)."""
    expected = (settings.device_enroll_secret or "").strip()
    if not expected:
        raise HTTPException(status_code=503, detail="Device enroll is not configured")
    provided = (secret or "").strip()
    # Hash first so unequal lengths still compare in constant time.
    if not provided or not secrets.compare_digest(
        hashlib.sha256(provided.encode("utf-8")).digest(),
        hashlib.sha256(expected.encode("utf-8")).digest(),
    ):
        raise HTTPException(status_code=403, detail="Invalid enroll secret")

    raw_token = new_device_token()
    device = Device(
        name=(name or "Device").strip()[:120] or "Device",
        platform=(platform or "unknown").strip()[:40],
        token_hash=hash_token(raw_token),
        token_prefix=raw_token[:8],
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return device, raw_token


def mount_session_middleware(app, settings: Settings) -> None:
    https_only = settings.public_base_url.strip().lower().startswith("https://")
    app.add_middleware(
        SessionMiddleware,
        secret_key=settings.secret_key,
        session_cookie=settings.session_cookie_name,
        max_age=settings.session_max_age_seconds,
        same_site="lax",
        https_only=https_only,
    )
