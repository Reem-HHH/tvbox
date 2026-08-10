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
uvicorn app.main:app --reload --host 0.0.0.0 --port 8787
```

Open [http://127.0.0.1:8787/admin](http://127.0.0.1:8787/admin).

## Production: Render + Neon (free)

Host the admin + API on the public internet so TV/iPad can auto-enroll from anywhere:

→ **[DEPLOY_RENDER_NEON.md](DEPLOY_RENDER_NEON.md)** step-by-step (Neon Postgres + Render Web Service).

Summary: Neon for `DATABASE_URL`, Render runs `uvicorn` from `cloud/`, set `PUBLIC_BASE_URL` and `DEVICE_ENROLL_SECRET`, bake the same secret + URL into Flutter via `local_defines.json`.

## Device registration (auto-enroll)

Preferred for household installs:

```http
POST /v1/devices/enroll
Content-Type: application/json

{"secret":"<DEVICE_ENROLL_SECRET>","name":"Living room TV","platform":"android"}
```

Response includes a one-time `token`. Store it securely on the device.

### Optional: pairing code

1. Admin → **Devices** → **Generate pairing code**
2. On the device:

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

## Next app integration (not in this folder yet)

- Flutter: settings screen “Pair device” (enter code) + persist token
- On launch / parent Refresh: `GET /v1/catalog` → write into local `CatalogRepository`
- Keep local seed as offline fallback when cloud unreachable

## Production notes

- Prefer **[DEPLOY_RENDER_NEON.md](DEPLOY_RENDER_NEON.md)** (Render Web Service + Neon Postgres)
- Put TLS in front if you self-host; set `PUBLIC_BASE_URL` to your https URL
- `DATABASE_URL` accepts Neon `postgresql://…?sslmode=require` (auto-rewritten for psycopg3)
- Change `ADMIN_PASSWORD` and `SECRET_KEY` before exposing the server
- Free Render sleeps when idle — first wake can be slow; optional uptime ping on `/health`
