# KiddyTube Cloud (custom admin + per-device sync)

Single-admin cloud catalog for your household. You edit content in a **web admin**; each TV / phone / iPad **registers separately** (option B) and pulls the shared catalog with its own token.

## Features

- Admin login (email/password from `.env`)
- Catalog management: add/delete channels & YouTube videos, enable/disable, import app `exportJson`
- Device auto-enroll: builds with `CLOUD_ENROLL_SECRET` call `POST /v1/devices/enroll` (no pairing code)
- Device pairing (optional): generate 6-digit code → `POST /v1/devices/pair` → stores token
- Revoke any device from the admin UI
- `GET /v1/catalog` (Bearer device token) returns JSON compatible with Flutter catalog export shape
- Watch history: `PUT/GET /v1/watch` per device; admin Devices page shows recent plays

## Quick start (local)

```bash
cd cloud
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# edit ADMIN_EMAIL, ADMIN_PASSWORD, SECRET_KEY, DEVICE_ENROLL_SECRET
mkdir -p data
# Schema migrations run automatically on startup (Alembic). Manual:
#   alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8787
```

Open [http://127.0.0.1:8787/admin](http://127.0.0.1:8787/admin).

New schema changes: add a revision under `alembic/versions/`, then `alembic upgrade head` (also runs on app start / Render boot).

## Production: Render + Neon (free)

Host the admin + API on the public internet so TV/iPad can auto-enroll from anywhere:

→ **[DEPLOY_RENDER_NEON.md](DEPLOY_RENDER_NEON.md)** step-by-step (Neon Postgres + Render Web Service).

Summary: Neon for `DATABASE_URL`, Render runs `uvicorn` from `cloud/`, set `PUBLIC_BASE_URL`. Prefer pairing codes for devices; optional `DEVICE_ENROLL_SECRET` only if you enable Flutter `CLOUD_AUTO_ENROLL`.

## Device registration (pairing first)

Preferred for household installs — **no enroll secret in the APK**:

1. Admin → **Devices** → **Generate pairing code**
2. On the device (Parent → Home & Sync → Pair), or:

```http
POST /v1/devices/pair
Content-Type: application/json

{"code":"123456","name":"Living room TV","platform":"android_tv"}
```

3. Fetch catalog:

```http
GET /v1/catalog
Authorization: Bearer <device_token>
```

4. To remove a device: Admin → Devices → **Revoke**.

### Optional: auto-enroll

Requires baking `CLOUD_ENROLL_SECRET` into the app **and** `CLOUD_AUTO_ENROLL=true`. Prefer pairing instead.

```http
POST /v1/devices/enroll
Content-Type: application/json

{"secret":"<DEVICE_ENROLL_SECRET>","name":"Living room TV","platform":"android"}
```

Response includes a one-time `token`. Store it securely on the device.
## Catalog JSON shape

Matches Flutter `CatalogRepository.exportJson()`:

```json
{
  "seedVersion": 0,
  "homeLibraryMode": "channels",
  "channels": [
    {
      "id": "peppa",
      "title": "Peppa Pig",
      "enabled": true,
      "youtubePlaylistId": null,
      "followUploads": false,
      "defaultAllowSeek": true,
      "sortOrder": 0,
      "videos": [
        {
          "id": "xxxxxxxxxxx",
          "title": "Episode",
          "youtubeVideoId": "xxxxxxxxxxx",
          "manual": true,
          "allowSeek": true
        }
      ]
    }
  ]
}
```

You can paste an export from the current app into **Catalog → Import**.

## Flutter app integration

The Flutter client in [`../kiddytube_flutter`](../kiddytube_flutter) already supports:

- Parent → Home & Sync → **Pair device** (6-digit code) + persisted token
- Manual **Pull catalog** / **Sync watch history** into local `CatalogRepository`
- Local seed as offline fallback when cloud is unreachable

## Production notes

- Prefer **[DEPLOY_RENDER_NEON.md](DEPLOY_RENDER_NEON.md)** (Render Web Service + Neon Postgres)
- Put TLS in front if you self-host; set `PUBLIC_BASE_URL` to your https URL
- `DATABASE_URL` accepts Neon `postgresql://…?sslmode=require` (auto-rewritten for psycopg3)
- Change `ADMIN_PASSWORD` and `SECRET_KEY` before exposing the server
- Production (`https://` `PUBLIC_BASE_URL`, `PRODUCTION=true`, or Render’s `RENDER` env) refuses default admin password / secret key and refuses SQLite
- Pair / enroll / login are rate-limited by the proxy-appended client IP (rightmost `X-Forwarded-For` hop)
- Run API tests: `pip install -r requirements.txt && pytest` from `cloud/`
- Free Render sleeps when idle — first wake can be slow; optional uptime ping on `/health`
