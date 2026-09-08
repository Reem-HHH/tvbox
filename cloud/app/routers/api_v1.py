from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..auth import enroll_device, get_current_device, pair_device
from ..catalog_service import get_catalog_document
from ..client_ip import client_ip
from ..config import get_settings
from ..db import get_db
from ..models import Device, WatchHistoryRow, as_utc, utcnow
from ..rate_limit import auth_limiter

router = APIRouter(prefix="/v1", tags=["device-api"])


def _rate_limit_or_429(key: str, *, limit: int, window_seconds: float) -> None:
    if not auth_limiter.allow(key, limit=limit, window_seconds=window_seconds):
        raise HTTPException(status_code=429, detail="Too many attempts; try again later")


class PairRequest(BaseModel):
    code: str = Field(min_length=4, max_length=8)
    name: str = Field(default="Device", max_length=120)
    platform: str = Field(default="unknown", max_length=40)


class EnrollRequest(BaseModel):
    secret: str = Field(min_length=8, max_length=200)
    name: str = Field(default="Device", max_length=120)
    platform: str = Field(default="unknown", max_length=40)


class PairResponse(BaseModel):
    device_id: int
    name: str
    platform: str
    token: str
    catalog_url: str


class DeviceInfo(BaseModel):
    id: int
    name: str
    platform: str
    revoked: bool


@router.post("/devices/pair", response_model=PairResponse)
def pair(body: PairRequest, request: Request, db: Session = Depends(get_db)):
    ip = client_ip(request)
    _rate_limit_or_429(f"pair:ip:{ip}", limit=20, window_seconds=60)
    _rate_limit_or_429(f"pair:code:{body.code.strip()}", limit=8, window_seconds=600)
    settings = get_settings()
    device, token = pair_device(db, body.code, body.name, body.platform)
    return PairResponse(
        device_id=device.id,
        name=device.name,
        platform=device.platform,
        token=token,
        catalog_url=f"{settings.public_base_url.rstrip('/')}/v1/catalog",
    )


@router.post("/devices/enroll", response_model=PairResponse)
def enroll(body: EnrollRequest, request: Request, db: Session = Depends(get_db)):
    """Auto-register builds that embed CLOUD_ENROLL_SECRET (no pairing code)."""
    ip = client_ip(request)
    _rate_limit_or_429(f"enroll:ip:{ip}", limit=10, window_seconds=60)
    settings = get_settings()
    device, token = enroll_device(
        db,
        settings,
        body.secret,
        body.name,
        body.platform,
    )
    return PairResponse(
        device_id=device.id,
        name=device.name,
        platform=device.platform,
        token=token,
        catalog_url=f"{settings.public_base_url.rstrip('/')}/v1/catalog",
    )


@router.get("/devices/me", response_model=DeviceInfo)
def me(device: Device = Depends(get_current_device)):
    return DeviceInfo(
        id=device.id,
        name=device.name,
        platform=device.platform,
        revoked=device.revoked,
    )


@router.get("/catalog")
def catalog(device: Device = Depends(get_current_device), db: Session = Depends(get_db)):
    doc = get_catalog_document(db)
    try:
        payload = json.loads(doc.payload_json)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail="Corrupt catalog document") from exc
    payload["revision"] = doc.revision
    payload["updatedAt"] = doc.updated_at.isoformat() if doc.updated_at else None
    payload["deviceId"] = device.id
    return payload


class WatchItemIn(BaseModel):
    channel_id: str = Field(min_length=1, max_length=80)
    video_id: str = Field(min_length=1, max_length=120)
    title: str = Field(default="Video", max_length=300)
    youtube_video_id: Optional[str] = Field(default=None, max_length=20)
    direct_url: Optional[str] = Field(default=None, max_length=500)
    position_ms: int = Field(default=0, ge=0)
    updated_at_ms: int = Field(default=0, ge=0)


class WatchItemOut(BaseModel):
    channel_id: str
    video_id: str
    title: str
    youtube_video_id: Optional[str] = None
    direct_url: Optional[str] = None
    position_ms: int
    updated_at_ms: int


class WatchUpsertRequest(BaseModel):
    items: list[WatchItemIn] = Field(default_factory=list, max_length=50)


class WatchListResponse(BaseModel):
    items: list[WatchItemOut]


def _ms_to_dt(ms: int) -> datetime:
    if ms <= 0:
        return utcnow()
    return datetime.fromtimestamp(ms / 1000.0, tz=timezone.utc)


def _dt_to_ms(dt: datetime) -> int:
    return int(as_utc(dt).timestamp() * 1000)


def _row_to_out(row: WatchHistoryRow) -> WatchItemOut:
    return WatchItemOut(
        channel_id=row.channel_id,
        video_id=row.video_id,
        title=row.title,
        youtube_video_id=row.youtube_video_id,
        direct_url=row.direct_url,
        position_ms=row.position_ms,
        updated_at_ms=_dt_to_ms(row.updated_at),
    )


@router.get("/watch", response_model=WatchListResponse)
def list_watch(
    device: Device = Depends(get_current_device),
    db: Session = Depends(get_db),
    limit: int = 24,
):
    limit = max(1, min(limit, 50))
    rows = (
        db.query(WatchHistoryRow)
        .filter(WatchHistoryRow.device_id == device.id)
        .order_by(WatchHistoryRow.updated_at.desc())
        .limit(limit)
        .all()
    )
    return WatchListResponse(items=[_row_to_out(r) for r in rows])


@router.put("/watch", response_model=WatchListResponse)
def upsert_watch(
    body: WatchUpsertRequest,
    device: Device = Depends(get_current_device),
    db: Session = Depends(get_db),
):
    """Upsert watch rows; newer updated_at_ms wins."""
    for item in body.items:
        updated = as_utc(_ms_to_dt(item.updated_at_ms))
        channel_id = item.channel_id.strip()[:80]
        video_id = item.video_id.strip()[:120]
        existing = (
            db.query(WatchHistoryRow)
            .filter(
                WatchHistoryRow.device_id == device.id,
                WatchHistoryRow.channel_id == channel_id,
                WatchHistoryRow.video_id == video_id,
            )
            .first()
        )
        if existing is None:
            try:
                with db.begin_nested():
                    db.add(
                        WatchHistoryRow(
                            device_id=device.id,
                            channel_id=channel_id,
                            video_id=video_id,
                            title=(item.title or "Video").strip()[:300],
                            youtube_video_id=item.youtube_video_id,
                            direct_url=item.direct_url,
                            position_ms=item.position_ms,
                            updated_at=updated,
                        )
                    )
                    db.flush()
            except IntegrityError:
                existing = (
                    db.query(WatchHistoryRow)
                    .filter(
                        WatchHistoryRow.device_id == device.id,
                        WatchHistoryRow.channel_id == channel_id,
                        WatchHistoryRow.video_id == video_id,
                    )
                    .first()
                )
                if existing is not None and as_utc(existing.updated_at) <= updated:
                    existing.title = (item.title or existing.title).strip()[:300]
                    existing.youtube_video_id = (
                        item.youtube_video_id or existing.youtube_video_id
                    )
                    existing.direct_url = item.direct_url or existing.direct_url
                    existing.position_ms = item.position_ms
                    existing.updated_at = updated
        elif as_utc(existing.updated_at) <= updated:
            existing.title = (item.title or existing.title).strip()[:300]
            existing.youtube_video_id = item.youtube_video_id or existing.youtube_video_id
            existing.direct_url = item.direct_url or existing.direct_url
            existing.position_ms = item.position_ms
            existing.updated_at = updated
    db.commit()

    # Cap stored history per device.
    rows = (
        db.query(WatchHistoryRow)
        .filter(WatchHistoryRow.device_id == device.id)
        .order_by(WatchHistoryRow.updated_at.desc())
        .all()
    )
    for stale in rows[40:]:
        db.delete(stale)
    if len(rows) > 40:
        db.commit()
        rows = rows[:40]
    return WatchListResponse(items=[_row_to_out(r) for r in rows[:24]])
