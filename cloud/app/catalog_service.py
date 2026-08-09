from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Dict, Optional

from sqlalchemy.orm import Session, joinedload

from .models import CatalogDocument, ChannelRow, VideoRow, utcnow

EMPTY_CATALOG = {
    "seedVersion": 0,
    "homeLibraryMode": "channels",
    "channels": [],
}


def catalog_from_rows(db: Session) -> Dict:
    channels = (
        db.query(ChannelRow)
        .options(joinedload(ChannelRow.videos))
        .order_by(ChannelRow.sort_order.asc(), ChannelRow.id.asc())
        .all()
    )
    payload = {
        "seedVersion": 0,
        "homeLibraryMode": "channels",
        "channels": [
            {
                "id": ch.channel_key,
                "title": ch.title,
                "sourceType": ch.source_type,
                "enabled": ch.enabled,
                "youtubePlaylistId": ch.youtube_playlist_id,
                "followUploads": ch.follow_uploads,
                "defaultAllowSeek": ch.default_allow_seek,
                "sortOrder": ch.sort_order,
                "color": ch.color,
                "playlistManagedByParent": True,
                "videos": [
                    {
                        "id": v.video_key,
                        "title": v.title,
                        "youtubeVideoId": v.youtube_video_id,
                        "directUrl": v.direct_url,
                        "thumbnailUrl": v.thumbnail_url,
                        "manual": v.manual,
                        "allowSeek": v.allow_seek,
                    }
                    for v in ch.videos
                ],
            }
            for ch in channels
        ],
        "updatedAt": datetime.now(timezone.utc).isoformat(),
    }
    return payload


def persist_catalog_document(db: Session, payload: Optional[Dict] = None) -> CatalogDocument:
    if payload is None:
        payload = catalog_from_rows(db)
    doc = db.query(CatalogDocument).filter(CatalogDocument.family_id == "default").first()
    raw = json.dumps(payload, ensure_ascii=False, indent=2)
    if doc is None:
        doc = CatalogDocument(family_id="default", payload_json=raw, revision=1)
        db.add(doc)
    else:
        doc.payload_json = raw
        doc.updated_at = utcnow()
        doc.revision += 1
    db.commit()
    db.refresh(doc)
    return doc


def get_catalog_document(db: Session) -> CatalogDocument:
    doc = db.query(CatalogDocument).filter(CatalogDocument.family_id == "default").first()
    if doc is None:
        return persist_catalog_document(db, EMPTY_CATALOG)
    return doc


def import_catalog_json(db: Session, payload: Dict) -> CatalogDocument:
    """Replace normalized rows from a Flutter/native export JSON."""
    db.query(VideoRow).delete()
    db.query(ChannelRow).delete()
    channels = payload.get("channels") or []
    for index, raw in enumerate(channels):
        ch = ChannelRow(
            channel_key=str(raw.get("id") or f"channel_{index}"),
            title=str(raw.get("title") or raw.get("id") or f"Channel {index}"),
            enabled=bool(raw.get("enabled", True)),
            youtube_playlist_id=raw.get("youtubePlaylistId"),
            follow_uploads=bool(raw.get("followUploads", False)),
            default_allow_seek=bool(raw.get("defaultAllowSeek", True)),
            sort_order=int(raw.get("sortOrder") or index),
            source_type=str(raw.get("sourceType") or "youtubePlaylist"),
            color=int(raw.get("color") or 0xFF42A5F5),
        )
        db.add(ch)
        db.flush()
        for v_index, vraw in enumerate(raw.get("videos") or []):
            db.add(
                VideoRow(
                    channel_id=ch.id,
                    video_key=str(vraw.get("id") or f"video_{v_index}"),
                    title=str(vraw.get("title") or vraw.get("id") or "Video"),
                    youtube_video_id=vraw.get("youtubeVideoId"),
                    direct_url=vraw.get("directUrl"),
                    thumbnail_url=vraw.get("thumbnailUrl"),
                    manual=bool(vraw.get("manual", False)),
                    allow_seek=bool(vraw.get("allowSeek", True)),
                    sort_index=v_index,
                )
            )
    db.commit()
    return persist_catalog_document(db)
