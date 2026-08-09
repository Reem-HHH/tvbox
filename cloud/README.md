# KiddyTube Cloud (custom admin + per-device sync)

Single-admin cloud catalog for your household. You edit content in a **web admin**; each TV / phone / iPad **registers separately** (option B) and pulls the shared catalog with its own token.

## Features

- Admin login (email/password from `.env`)
- Catalog management: add/delete channels & YouTube videos, enable/disable, import app `exportJson`
- Device pairing: generate 6-digit code → device calls `POST /v1/devices/pair` → stores token
- Revoke any device from the admin UI
- `GET /v1/catalog` (Bearer device token) returns JSON compatible with Flutter/native catalog export shape

## Quick start

```bash
cd cloud
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# edit ADMIN_EMAIL, ADMIN_PASSWORD, SECRET_KEY
mkdir -p data
uvicorn app.main:app --reload --host 0.0.0.0 --port 8787
```

Open [http://127.0.0.1:8787/admin](http://127.0.0.1:8787/admin).

## Device registration (B)

1. Admin → **Devices** → **Generate pairing code**
2. On the device (future app UI), call:

```http
POST /v1/devices/pair
Content-Type: application/json

{"code":"123456","name":"Living room TV","platform":"android_tv"}
```

Response includes a one-time `token`. Store it securely on the device.

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

- Flutter / native: settings screen “Pair device” (enter code) + persist token
- On launch / parent Refresh: `GET /v1/catalog` → write into local `CatalogRepository`
- Keep local seed as offline fallback when cloud unreachable

## Production notes

- Put TLS in front (Caddy/nginx) and set `PUBLIC_BASE_URL` to your https URL
- Switch `DATABASE_URL` to Postgres when deploying
- Change `ADMIN_PASSWORD` and `SECRET_KEY` before exposing the server
