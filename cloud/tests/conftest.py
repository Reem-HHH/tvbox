import os
import tempfile

# Must run before app.db / Settings bind the engine.
_TMP = tempfile.mkdtemp(prefix="ktcloud_")
os.environ["DATABASE_URL"] = f"sqlite:///{_TMP}/test.db"
os.environ["ADMIN_EMAIL"] = "admin@example.com"
os.environ["ADMIN_PASSWORD"] = "test-admin-password-ok"
os.environ["SECRET_KEY"] = "test-secret-key-not-default-value"
os.environ["DEVICE_ENROLL_SECRET"] = "test-enroll-secret-ok"
os.environ["PUBLIC_BASE_URL"] = "http://127.0.0.1:8787"
os.environ.pop("PRODUCTION", None)

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.config import get_settings

get_settings.cache_clear()

from app.db import Base, SessionLocal, engine  # noqa: E402
from app.main import create_app  # noqa: E402
from app.migrate import ensure_schema  # noqa: E402
from app.rate_limit import auth_limiter  # noqa: E402


def _reset_db() -> None:
    Base.metadata.drop_all(bind=engine)
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS alembic_version"))
    ensure_schema()


@pytest.fixture()
def client():
    auth_limiter.reset()
    _reset_db()
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client
    SessionLocal().close()


@pytest.fixture()
def device_token(client: TestClient) -> str:
    response = client.post(
        "/v1/devices/enroll",
        json={
            "secret": "test-enroll-secret-ok",
            "name": "Test TV",
            "platform": "android",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()["token"]
