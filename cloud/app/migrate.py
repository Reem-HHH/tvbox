"""Apply Alembic migrations on startup (with legacy create_all stamp)."""

from __future__ import annotations

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import inspect

from .config import get_settings
from .db import engine


def _alembic_config() -> Config:
    root = Path(__file__).resolve().parents[1]
    cfg = Config(str(root / "alembic.ini"))
    cfg.set_main_option("script_location", str(root / "alembic"))
    cfg.set_main_option("sqlalchemy.url", get_settings().sqlalchemy_database_url)
    return cfg


def ensure_schema() -> None:
    """
    Upgrade to head.

    Databases created with the old Base.metadata.create_all path (tables present,
    no alembic_version) are stamped at 0001_initial so later revisions still run.
    """
    cfg = _alembic_config()
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    if "alembic_version" not in tables and "devices" in tables:
        command.stamp(cfg, "0001_initial")
    command.upgrade(cfg, "head")
