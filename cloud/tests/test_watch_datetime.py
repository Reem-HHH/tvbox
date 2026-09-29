from datetime import datetime, timezone

from app.models import as_utc


def test_as_utc_naive_assumes_utc():
    naive = datetime(2024, 1, 2, 3, 4, 5)
    aware = as_utc(naive)
    assert aware.tzinfo is not None
    assert aware == datetime(2024, 1, 2, 3, 4, 5, tzinfo=timezone.utc)


def test_as_utc_preserves_aware():
    src = datetime(2024, 6, 1, 12, 0, tzinfo=timezone.utc)
    assert as_utc(src) == src


def test_watch_upsert_updates_existing_on_sqlite(client, device_token):
    """Regression: naive SQLite datetimes must not TypeError on compare."""
    headers = {"Authorization": f"Bearer {device_token}"}
    first = client.put(
        "/v1/watch",
        headers=headers,
        json={
            "items": [
                {
                    "channel_id": "peppa",
                    "video_id": "vid1",
                    "title": "Ep 1",
                    "youtube_video_id": "dQw4w9WgXcQ",
                    "position_ms": 1000,
                    "updated_at_ms": 1_700_000_000_000,
                }
            ]
        },
    )
    assert first.status_code == 200, first.text
    assert first.json()["items"][0]["position_ms"] == 1000

    second = client.put(
        "/v1/watch",
        headers=headers,
        json={
            "items": [
                {
                    "channel_id": "peppa",
                    "video_id": "vid1",
                    "title": "Ep 1",
                    "youtube_video_id": "dQw4w9WgXcQ",
                    "position_ms": 9000,
                    "updated_at_ms": 1_700_000_100_000,
                }
            ]
        },
    )
    assert second.status_code == 200, second.text
    items = second.json()["items"]
    assert len(items) == 1
    assert items[0]["position_ms"] == 9000
