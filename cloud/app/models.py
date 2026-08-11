from __future__ import annotations

from datetime import datetime, timezone
from typing import List, Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(dt: Optional[datetime]) -> datetime:
    """Normalize DB/API datetimes for safe compare (SQLite may strip tzinfo)."""
    if dt is None:
        return utcnow()
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


class AdminUser(Base):
    __tablename__ = "admin_users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    platform: Mapped[str] = mapped_column(String(40), default="unknown")
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    token_prefix: Mapped[str] = mapped_column(String(12), index=True)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_seen_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)


class PairingCode(Base):
    __tablename__ = "pairing_codes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    device_name_hint: Mapped[str] = mapped_column(String(120), default="")
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class CatalogDocument(Base):
    """Single-family catalog blob (JSON matching Flutter exportJson shape)."""

    __tablename__ = "catalog_documents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    # Always 1 for single-household installs.
    family_id: Mapped[str] = mapped_column(String(40), unique=True, default="default")
    payload_json: Mapped[str] = mapped_column(Text, default="{}")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    revision: Mapped[int] = mapped_column(Integer, default=1)


class ChannelRow(Base):
    """Normalized channel rows for admin editing (synced into CatalogDocument on save)."""

    __tablename__ = "channels"
    __table_args__ = (UniqueConstraint("channel_key", name="uq_channel_key"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    channel_key: Mapped[str] = mapped_column(String(80), index=True)
    title: Mapped[str] = mapped_column(String(200))
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    youtube_playlist_id: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    follow_uploads: Mapped[bool] = mapped_column(Boolean, default=False)
    default_allow_seek: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    source_type: Mapped[str] = mapped_column(String(40), default="youtubePlaylist")
    color: Mapped[int] = mapped_column(Integer, default=0xFF42A5F5)
    videos: Mapped[List["VideoRow"]] = relationship(
        back_populates="channel",
        cascade="all, delete-orphan",
        order_by="VideoRow.sort_index",
    )


class VideoRow(Base):
    __tablename__ = "videos"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    channel_id: Mapped[int] = mapped_column(ForeignKey("channels.id", ondelete="CASCADE"), index=True)
    video_key: Mapped[str] = mapped_column(String(120))
    title: Mapped[str] = mapped_column(String(300))
    youtube_video_id: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    direct_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    thumbnail_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    manual: Mapped[bool] = mapped_column(Boolean, default=True)
    allow_seek: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_index: Mapped[int] = mapped_column(Integer, default=0)
    channel: Mapped[ChannelRow] = relationship(back_populates="videos")


class WatchHistoryRow(Base):
    """Per-device continue-watching row (synced from Flutter RecentWatchStore)."""

    __tablename__ = "watch_history"
    __table_args__ = (
        UniqueConstraint("device_id", "channel_id", "video_id", name="uq_watch_device_video"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    device_id: Mapped[int] = mapped_column(ForeignKey("devices.id", ondelete="CASCADE"), index=True)
    channel_id: Mapped[str] = mapped_column(String(80), index=True)
    video_id: Mapped[str] = mapped_column(String(120), index=True)
    title: Mapped[str] = mapped_column(String(300), default="Video")
    youtube_video_id: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    direct_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    position_ms: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    device: Mapped[Device] = relationship()
