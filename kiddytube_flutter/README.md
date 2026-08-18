# KiddyTube (Flutter)

Cross-platform kids browser for:

- **Android phones / tablets**
- **Android TV** (Leanback launcher + D-pad focus)
- **iPad / iOS**

**Apple TV (tvOS)** is intentionally out of scope. This Flutter app is the day-to-day product for phone, iPad, and Google TV. The old native Kotlin Android TV app is archived outside this repo (see sibling folder `KiddyTube-kotlin-archive/`).

## Features (current)

- Curated catalog seed **v43** (allowlisted channels / videos)
- Home **Shows | Mix** side-by-side toggle (selected mode highlighted; change gated behind parent PIN)
- YouTube / direct HTTPS **player** (kid-minimal iframe chrome; autoplay next in channel; seek scrub overlay when allowed)
- Continue watching with **periodic resume progress** (clamped near start/end)
- Parent dashboard tabs: **Channels** · **Security** · **Home & Sync**
  - Change PIN, release ready, enable channels, Follow uploads, seek, add/delete videos
  - YouTube API key, refresh playlists, clear continue watching, export catalog
- **Cloud family catalog**: pair each device with a 6-digit code, pull shared channels from [`../cloud`](../cloud)
- Release builds block kid playback until the factory PIN is changed
- **Family title + tag filter** on playlist sync (skips Halloween / Thanksgiving / LGBTQ-related titles and YouTube tags)
- Recent seed highlights: مكة مباشر، القرآن مباشر، ماشا والدب، بليبي بالعربي، Disney Songs، ماروكو الصغيرة، بابار، حديقة المرح
- Channel tiles use YouTube preview thumbs; TV-friendly grids and lighter scroll decoding

## Docs

| Doc | Who it’s for |
| --- | --- |
| **[About the app](docs/ABOUT_APP.md)** | You (admin) + household: PIN, home modes, channels, cloud, live Makkah, limits |
| **[Ship checklist](docs/SHIP_CHECKLIST.md)** | Exact next steps: TV check, PR, signing, cloud pair, change PIN |
| **[Run TV and iPad](docs/RUN_TV_AND_IPAD.md)** | Install / pair checklist |
| **[Install & pair on TV / iPad](docs/RUN_TV_AND_IPAD.md)** | Step-by-step install, ADB, pairing |
| **[Cloud README](../cloud/README.md)** | Admin API + device tokens |
| **[Channel dossiers](docs/channels/README.md)** | Per-show notes / clean-fit |

## Setup

Flutter SDK may be bootstrapped under `../.tools/flutter`:

```bash
export PATH="$PWD/../.tools/flutter/bin:$PATH"
cd kiddytube_flutter
flutter pub get
flutter test
flutter analyze
```

### Run cloud admin (on your Mac)

```bash
cd ../cloud
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8787
```

Open http://127.0.0.1:8787/admin on the Mac. Note your Mac’s LAN IP (`ipconfig getifaddr en0`), e.g. `http://192.168.1.20:8787`.

### Run the Flutter app

```bash
# List devices
flutter devices

# Physical / wireless iPad
flutter run --dart-define-from-file=local_defines.json -d <ipad-device-id>

# Android TV (Leanback) — USB or wireless adb
flutter run --release --dart-define-from-file=local_defines.json -d <android-tv-id>
```

Copy `local_defines.json.example` → `local_defines.json` and set YouTube API key plus optional `CLOUD_BASE_URL` (file is gitignored). Prefer pairing codes; only set `CLOUD_ENROLL_SECRET` with `CLOUD_AUTO_ENROLL=true` if you want silent enroll. Never commit real secrets.

Default parent PIN for development: **2580**.

### Connect to the cloud catalog

Cloud catalog and watch history sync are **manual only** on devices — nothing pulls automatically on launch or refresh. Use Parent → Home & Sync → **Pull catalog from cloud** / **Sync watch history**.

**Preferred — pairing:** set `CLOUD_BASE_URL` (optional), open Parent → Home & Sync → Pair, enter the 6-digit admin code.

**Optional — auto-enroll:** set `DEVICE_ENROLL_SECRET` on the cloud, matching `CLOUD_ENROLL_SECRET` plus `"CLOUD_AUTO_ENROLL": "true"` in `local_defines.json`, then install with `--dart-define-from-file=local_defines.json`.

**Import to cloud admin:** prefer **Upload .json file** on Catalog → Import (large pastes often fail in the browser).

## Layout

```
lib/
  catalog/   models, seed, repository, sync + title/tag filter, continue watching
  cloud/     enroll + pair + pull client for ../cloud API
  parent/    PIN, session, settings screen
  player/    YouTube iframe + video_player
  ui/        home (Shows|Mix), focus tiles, TV text dialogs
  main.dart
docs/
  ABOUT_APP.md          admin + household guide
  RUN_TV_AND_IPAD.md    install / pair checklist
```
