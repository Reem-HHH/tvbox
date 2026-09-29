# Household ship checklist

Exact steps after the review/hardening work on `polish/flutter-ios-next`. Do these in order.

## Already done (code)

- Shorts filter (up to 3 minutes) + prune leftover Follow-off sync junk (seed v27)
- Cloud hardening (CSRF, rate limits, Alembic, pairing-first enroll)
- Security: stronger PIN hash, HTTPS-first cloud URLs, release cleartext off
- Branch pushed to GitHub

## Still on you

| Item | Status |
|------|--------|
| Spot-check TV (Sarah & Duck / Shorts) | You |
| Merge PR into `main` | You (or ask Agent to open PR) |
| `android/key.properties` + release keystore | Missing until you create them |
| Strong Render / Neon secrets | You verify |
| Change parent PIN from `2580` on each device | You |

---

## 1. Spot-check the TV

1. Open **KiddyTube** on the Google TV Streamer.
2. Open **Sarah & Duck** — only curated full episodes, no Shorts/promos.
3. Play one episode; confirm seek and Back.
4. Spot-check 1–2 other channels that used to Follow uploads.
5. Parent lock (PIN **2580** if unchanged) → **Home & Sync**:
   - Confirm connected or pair if needed.
   - If connected: **Pull catalog**, then re-check Sarah & Duck.

If Shorts remain, note **channel name + video title**.

---

## 2. Merge the feature branch

1. Open the PR: `polish/flutter-ios-next` → `main` (create with `gh pr create` if none exists).
2. Wait for CI (Flutter / cloud tests).
3. Merge when green.
4. If Render deploys from `main`, confirm the cloud service redeployed.

---

## 3. Production Android signing

Required before sharing release APKs with other households. Without this, release builds fall back to **debug** keys.

```bash
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter/android"
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp key.properties.example key.properties
```

Edit `key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

- Keep `key.properties` and `upload-keystore.jks` **out of git**; back them up offline.
- Build:

```bash
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$PATH"
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
flutter build apk --release --dart-define-from-file=local_defines.json
```

---

## 4. Cloud / household

### If already on Render

1. Render → service → **Environment**: confirm real values (not placeholders) for:
   - `ADMIN_EMAIL` / `ADMIN_PASSWORD`
   - `SECRET_KEY`
   - `DATABASE_URL` (Neon + `sslmode=require`)
   - `PUBLIC_BASE_URL` = `https://YOUR-SERVICE.onrender.com`
   - `DEVICE_ENROLL_SECRET` only if you use auto-enroll
2. Open `https://YOUR-SERVICE.onrender.com/admin` → log in.
3. **Devices** → **Generate pairing code**.
4. On each device: Parent → **Home & Sync** → URL → **Pair** → **Pull catalog**.
5. Admin **Catalog**: prefer full episodes; do not paste `/shorts/` links.

### If not deployed yet

Follow [../../cloud/DEPLOY_RENDER_NEON.md](../../cloud/DEPLOY_RENDER_NEON.md), then pair as above.

### App defines (`local_defines.json`)

Pairing-first example:

```json
{
  "YOUTUBE_API_KEY": "your-key",
  "CLOUD_BASE_URL": "https://YOUR-SERVICE.onrender.com",
  "CLOUD_ENROLL_SECRET": "",
  "CLOUD_AUTO_ENROLL": "false"
}
```

---

## 5. Change the parent PIN

On **each** device:

1. Unlock parent settings (current PIN; default **2580**).
2. **Security** → **Change PIN**.
3. Unlock once with the new PIN to confirm.
4. Optional: enable biometrics only after the PIN is no longer the default.

Release builds block kid playback until the factory PIN is changed.

---

## Suggested order

1. TV spot-check (§1)
2. Merge PR (§2)
3. Change PIN on the living-room TV (§5)
4. Verify cloud secrets + pair/pull (§4)
5. Create keystore before any shared release APK (§3)
