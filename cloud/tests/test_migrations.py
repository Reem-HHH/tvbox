from sqlalchemy import inspect, text

from app.db import engine
from app.migrate import ensure_schema


def test_ensure_schema_creates_tables_and_alembic_version():
    from app.db import Base

    Base.metadata.drop_all(bind=engine)
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS alembic_version"))

    ensure_schema()
    tables = set(inspect(engine).get_table_names())
    assert "devices" in tables
    assert "watch_history" in tables
    assert "alembic_version" in tables
    assert "admin_users" in tables


def test_ensure_schema_stamps_legacy_create_all_db():
    from app.db import Base

    Base.metadata.drop_all(bind=engine)
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS alembic_version"))
    # Simulate pre-Alembic bootstrap.
    Base.metadata.create_all(bind=engine)
    assert "alembic_version" not in set(inspect(engine).get_table_names())
    assert "devices" in set(inspect(engine).get_table_names())

    ensure_schema()
    tables = set(inspect(engine).get_table_names())
    assert "alembic_version" in tables
    # Data tables still present (stamp, not recreate).
    assert "devices" in tables
