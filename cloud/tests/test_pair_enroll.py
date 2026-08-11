from app.auth import create_pairing_code
from app.config import get_settings
from app.db import SessionLocal


def test_pair_consumes_code_once(client):
    db = SessionLocal()
    try:
        code = create_pairing_code(db, get_settings(), "Living room")
        pair_code = code.code
    finally:
        db.close()

    first = client.post(
        "/v1/devices/pair",
        json={"code": pair_code, "name": "TV A", "platform": "android"},
    )
    assert first.status_code == 200, first.text
    token_a = first.json()["token"]
    assert token_a

    second = client.post(
        "/v1/devices/pair",
        json={"code": pair_code, "name": "TV B", "platform": "android"},
    )
    assert second.status_code == 400


def test_enroll_rejects_bad_secret(client):
    response = client.post(
        "/v1/devices/enroll",
        json={"secret": "wrong-secret-xxxxxxxx", "name": "X", "platform": "ios"},
    )
    assert response.status_code == 403


def test_enroll_rate_limit(client):
    # Exhaust IP window (limit 10 / 60s) on a dedicated forwarded IP.
    headers = {"X-Forwarded-For": "203.0.113.50"}
    last = None
    for i in range(12):
        last = client.post(
            "/v1/devices/enroll",
            headers=headers,
            json={
                "secret": "wrong-secret-xxxxxxxx",
                "name": f"X{i}",
                "platform": "ios",
            },
        )
    assert last is not None
    assert last.status_code == 429
