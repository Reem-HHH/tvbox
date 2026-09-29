"""Initial schema (matches app.models).

Revision ID: 0001_initial
Revises:
Create Date: 2026-08-11

"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "admin_users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_admin_users_email", "admin_users", ["email"], unique=True)

    op.create_table(
        "devices",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("platform", sa.String(length=40), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("token_prefix", sa.String(length=12), nullable=False),
        sa.Column("revoked", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_devices_token_hash", "devices", ["token_hash"], unique=True)
    op.create_index("ix_devices_token_prefix", "devices", ["token_prefix"], unique=False)

    op.create_table(
        "pairing_codes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(length=8), nullable=False),
        sa.Column("device_name_hint", sa.String(length=120), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_pairing_codes_code", "pairing_codes", ["code"], unique=True)

    op.create_table(
        "catalog_documents",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("family_id", sa.String(length=40), nullable=False),
        sa.Column("payload_json", sa.Text(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
    )
    op.create_index(
        "ix_catalog_documents_family_id",
        "catalog_documents",
        ["family_id"],
        unique=True,
    )

    op.create_table(
        "channels",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("channel_key", sa.String(length=80), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.Column("youtube_playlist_id", sa.String(length=120), nullable=True),
        sa.Column("follow_uploads", sa.Boolean(), nullable=False),
        sa.Column("default_allow_seek", sa.Boolean(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("source_type", sa.String(length=40), nullable=False),
        sa.Column("color", sa.Integer(), nullable=False),
        sa.UniqueConstraint("channel_key", name="uq_channel_key"),
    )
    op.create_index("ix_channels_channel_key", "channels", ["channel_key"], unique=False)

    op.create_table(
        "videos",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("channel_id", sa.Integer(), nullable=False),
        sa.Column("video_key", sa.String(length=120), nullable=False),
        sa.Column("title", sa.String(length=300), nullable=False),
        sa.Column("youtube_video_id", sa.String(length=20), nullable=True),
        sa.Column("direct_url", sa.String(length=500), nullable=True),
        sa.Column("thumbnail_url", sa.String(length=500), nullable=True),
        sa.Column("manual", sa.Boolean(), nullable=False),
        sa.Column("allow_seek", sa.Boolean(), nullable=False),
        sa.Column("sort_index", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["channel_id"], ["channels.id"], ondelete="CASCADE"),
    )
    op.create_index("ix_videos_channel_id", "videos", ["channel_id"], unique=False)

    op.create_table(
        "watch_history",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("device_id", sa.Integer(), nullable=False),
        sa.Column("channel_id", sa.String(length=80), nullable=False),
        sa.Column("video_id", sa.String(length=120), nullable=False),
        sa.Column("title", sa.String(length=300), nullable=False),
        sa.Column("youtube_video_id", sa.String(length=20), nullable=True),
        sa.Column("direct_url", sa.String(length=500), nullable=True),
        sa.Column("position_ms", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["device_id"], ["devices.id"], ondelete="CASCADE"),
        sa.UniqueConstraint(
            "device_id",
            "channel_id",
            "video_id",
            name="uq_watch_device_video",
        ),
    )
    op.create_index("ix_watch_history_device_id", "watch_history", ["device_id"], unique=False)
    op.create_index(
        "ix_watch_history_channel_id",
        "watch_history",
        ["channel_id"],
        unique=False,
    )
    op.create_index("ix_watch_history_video_id", "watch_history", ["video_id"], unique=False)
    op.create_index(
        "ix_watch_history_updated_at",
        "watch_history",
        ["updated_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_table("watch_history")
    op.drop_table("videos")
    op.drop_table("channels")
    op.drop_table("catalog_documents")
    op.drop_table("pairing_codes")
    op.drop_table("devices")
    op.drop_table("admin_users")
