from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session, joinedload

from ..auth import create_pairing_code, ensure_admin, verify_password
from ..catalog_service import import_catalog_json, persist_catalog_document
from ..config import get_settings
from ..db import get_db
from ..models import AdminUser, ChannelRow, Device, PairingCode, VideoRow, utcnow

router = APIRouter(prefix="/admin", tags=["admin-web"])
TEMPLATES = Jinja2Templates(directory=str(Path(__file__).resolve().parents[1] / "templates"))

_YT_ID = re.compile(r"(?:youtube\.com/watch\?.*v=|youtu\.be/|youtube\.com/embed/)?([\w-]{11})$")


def _require_admin(request: Request, db: Session) -> AdminUser:
    admin_id = request.session.get("admin_id")
    if not admin_id:
        return None  # type: ignore[return-value]
    user = db.query(AdminUser).filter(AdminUser.id == admin_id).first()
    return user


def _extract_video_id(raw: str) -> Optional[str]:
    text = raw.strip()
    if not text:
        return None
    m = _YT_ID.search(text)
    if not m:
        return None
    vid = m.group(1)
    return vid if re.fullmatch(r"[\w-]{11}", vid) else None


@router.get("/login", response_class=HTMLResponse)
def login_page(request: Request):
    return TEMPLATES.TemplateResponse(
        "login.html",
        {"request": request, "error": None},
    )


@router.post("/login")
def login_submit(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db),
):
    settings = get_settings()
    ensure_admin(db, settings)
    user = db.query(AdminUser).filter(AdminUser.email == email.lower().strip()).first()
    if user is None or not verify_password(password, user.password_hash):
        return TEMPLATES.TemplateResponse(
            "login.html",
            {"request": request, "error": "Invalid email or password"},
            status_code=401,
        )
    request.session["admin_id"] = user.id
    return RedirectResponse("/admin", status_code=303)


@router.post("/logout")
def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/admin/login", status_code=303)


@router.get("", response_class=HTMLResponse)
@router.get("/", response_class=HTMLResponse)
def dashboard(request: Request, db: Session = Depends(get_db)):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    channels = db.query(ChannelRow).count()
    videos = db.query(VideoRow).count()
    devices = db.query(Device).filter(Device.revoked.is_(False)).count()
    return TEMPLATES.TemplateResponse(
        "dashboard.html",
        {
            "request": request,
            "admin": admin,
            "channel_count": channels,
            "video_count": videos,
            "device_count": devices,
            "public_base_url": get_settings().public_base_url,
        },
    )


@router.get("/devices", response_class=HTMLResponse)
def devices_page(request: Request, db: Session = Depends(get_db)):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    devices = db.query(Device).order_by(Device.created_at.desc()).all()
    active_codes = (
        db.query(PairingCode)
        .filter(PairingCode.consumed_at.is_(None), PairingCode.expires_at >= utcnow())
        .order_by(PairingCode.created_at.desc())
        .all()
    )
    return TEMPLATES.TemplateResponse(
        "devices.html",
        {
            "request": request,
            "admin": admin,
            "devices": devices,
            "active_codes": active_codes,
            "flash": request.query_params.get("flash"),
            "public_base_url": get_settings().public_base_url,
        },
    )


@router.post("/devices/pair-code")
def create_code(
    request: Request,
    device_name: str = Form(""),
    db: Session = Depends(get_db),
):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    code = create_pairing_code(db, get_settings(), device_name)
    return RedirectResponse(
        f"/admin/devices?flash=Pairing+code+{code.code}+created",
        status_code=303,
    )


@router.post("/devices/{device_id}/revoke")
def revoke_device(device_id: int, request: Request, db: Session = Depends(get_db)):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    device = db.query(Device).filter(Device.id == device_id).first()
    if device:
        device.revoked = True
        db.commit()
    return RedirectResponse("/admin/devices?flash=Device+revoked", status_code=303)


@router.get("/catalog", response_class=HTMLResponse)
def catalog_page(request: Request, db: Session = Depends(get_db)):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    channels = (
        db.query(ChannelRow)
        .options(joinedload(ChannelRow.videos))
        .order_by(ChannelRow.sort_order.asc(), ChannelRow.id.asc())
        .all()
    )
    return TEMPLATES.TemplateResponse(
        "catalog.html",
        {
            "request": request,
            "admin": admin,
            "channels": channels,
            "flash": request.query_params.get("flash"),
            "error": request.query_params.get("error"),
        },
    )


@router.post("/catalog/channels")
def add_channel(
    request: Request,
    channel_key: str = Form(...),
    title: str = Form(...),
    playlist_id: str = Form(""),
    db: Session = Depends(get_db),
):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    key = channel_key.strip().lower().replace(" ", "_")
    if not key:
        return RedirectResponse("/admin/catalog?error=Channel+id+required", status_code=303)
    exists = db.query(ChannelRow).filter(ChannelRow.channel_key == key).first()
    if exists:
        return RedirectResponse("/admin/catalog?error=Channel+id+already+exists", status_code=303)
    max_order = db.query(ChannelRow).count()
    db.add(
        ChannelRow(
            channel_key=key,
            title=title.strip() or key,
            youtube_playlist_id=playlist_id.strip() or None,
            follow_uploads=bool(playlist_id.strip()),
            sort_order=max_order,
        )
    )
    db.commit()
    persist_catalog_document(db)
    return RedirectResponse("/admin/catalog?flash=Channel+added", status_code=303)


@router.post("/catalog/channels/{channel_id}/toggle")
def toggle_channel(channel_id: int, request: Request, db: Session = Depends(get_db)):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    ch = db.query(ChannelRow).filter(ChannelRow.id == channel_id).first()
    if ch:
        ch.enabled = not ch.enabled
        db.commit()
        persist_catalog_document(db)
    return RedirectResponse("/admin/catalog?flash=Channel+updated", status_code=303)


@router.post("/catalog/channels/{channel_id}/delete")
def delete_channel(channel_id: int, request: Request, db: Session = Depends(get_db)):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    ch = db.query(ChannelRow).filter(ChannelRow.id == channel_id).first()
    if ch:
        db.delete(ch)
        db.commit()
        persist_catalog_document(db)
    return RedirectResponse("/admin/catalog?flash=Channel+deleted", status_code=303)


@router.post("/catalog/channels/{channel_id}/videos")
def add_video(
    channel_id: int,
    request: Request,
    video_input: str = Form(...),
    title: str = Form(""),
    db: Session = Depends(get_db),
):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    ch = db.query(ChannelRow).filter(ChannelRow.id == channel_id).first()
    if ch is None:
        return RedirectResponse("/admin/catalog?error=Channel+not+found", status_code=303)
    video_id = _extract_video_id(video_input)
    if not video_id:
        return RedirectResponse(
            "/admin/catalog?error=Invalid+YouTube+id+or+URL",
            status_code=303,
        )
    if any(v.video_key == video_id for v in ch.videos):
        return RedirectResponse("/admin/catalog?error=Video+already+in+channel", status_code=303)
    db.add(
        VideoRow(
            channel_id=ch.id,
            video_key=video_id,
            title=(title.strip() or f"Video {video_id}"),
            youtube_video_id=video_id,
            thumbnail_url=f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg",
            manual=True,
            allow_seek=ch.default_allow_seek,
            sort_index=len(ch.videos),
        )
    )
    db.commit()
    persist_catalog_document(db)
    return RedirectResponse("/admin/catalog?flash=Video+added", status_code=303)


@router.post("/catalog/videos/{video_id}/delete")
def delete_video(video_id: int, request: Request, db: Session = Depends(get_db)):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    video = db.query(VideoRow).filter(VideoRow.id == video_id).first()
    if video:
        db.delete(video)
        db.commit()
        persist_catalog_document(db)
    return RedirectResponse("/admin/catalog?flash=Video+removed", status_code=303)


@router.post("/catalog/import")
def import_json(
    request: Request,
    catalog_json: str = Form(...),
    db: Session = Depends(get_db),
):
    admin = _require_admin(request, db)
    if admin is None:
        return RedirectResponse("/admin/login", status_code=303)
    try:
        payload = json.loads(catalog_json)
    except json.JSONDecodeError:
        return RedirectResponse("/admin/catalog?error=Invalid+JSON", status_code=303)
    if not isinstance(payload, dict) or "channels" not in payload:
        return RedirectResponse(
            "/admin/catalog?error=JSON+must+include+channels+array",
            status_code=303,
        )
    import_catalog_json(db, payload)
    return RedirectResponse("/admin/catalog?flash=Catalog+imported", status_code=303)
