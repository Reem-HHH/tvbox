from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..auth import get_current_device, pair_device
from ..catalog_service import get_catalog_document
from ..config import get_settings
from ..db import get_db
from ..models import Device
import json

router = APIRouter(prefix="/v1", tags=["device-api"])


class PairRequest(BaseModel):
    code: str = Field(min_length=4, max_length=8)
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
def pair(body: PairRequest, db: Session = Depends(get_db)):
    settings = get_settings()
    device, token = pair_device(db, body.code, body.name, body.platform)
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
