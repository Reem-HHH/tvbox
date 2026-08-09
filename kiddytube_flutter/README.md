# KiddyTube (Flutter)

Cross-platform kids browser for:

- **Android phones / tablets**
- **Android TV** (Leanback launcher + D-pad focus)
- **iPad / iOS**

**Apple TV (tvOS)** is intentionally out of scope. The production Kotlin app in [`../KiddyTube`](../KiddyTube) remains available for parity; **Flutter** (`kiddytube_flutter/`) is the app to run day-to-day on phone, iPad, and Google TV.

## Features (current)

- Catalog seed parity with Kotlin `SEED_VERSION` **22**
- Home **Shows | Mix** side-by-side toggle (selected mode highlighted; change gated behind parent PIN)
- YouTube / direct HTTPS **player** (kid-minimal iframe chrome; autoplay next in channel; seek scrub overlay when allowed)
- Continue watching with **periodic resume progress** (clamped near start/end)
- Parent dashboard tabs: **Channels** · **Security** · **Home & Sync**
  - Change PIN, release ready, enable channels, Follow uploads, seek, add/delete videos
  - YouTube API key, refresh playlists, clear continue watching, export catalog
- **Cloud family catalog**: pair each device with a 6-digit code, pull shared channels from [`../cloud`](../cloud)
- Release builds block kid playback until the factory PIN is changed
- **Family title filter** on playlist sync (skips Halloween / Thanksgiving / LGBTQ-related titles)
- Recent seed highlights: مكة مباشر، القرآن مباشر، ماشا والدب، بليبي بالعربي، Disney Songs، أغاني ديزني، ماروكو الصغيرة
- Channel tiles use YouTube preview thumbs; TV-friendly grids and lighter scroll decoding

## Docs

| Doc | Who it’s for |
| --- | --- |
| **[About the app](docs/ABOUT_APP.md)** | You (admin) + household: PIN, home modes, channels, cloud, live Makkah, limits |
| **[Install & pair on TV / iPad](docs/RUN_TV_AND_IPAD.md)** | Step-by-step install, ADB, pairing |
| **[Cloud README](../cloud/README.md)** | Admin API + device tokens |
| **[Channel dossiers](../KiddyTube/docs/channels/README.md)** | Per-show notes / clean-fit |

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

Copy `local_defines.json.example` → `local_defines.json` and paste your YouTube API key (file is gitignored). Parent settings can still override it. Never commit real keys.

Default parent PIN for development: **2580**.

### Pair a device to the cloud catalog

1. On the Mac: Admin → **Devices** → Generate pairing code  
2. On the TV / iPad: Parent settings (PIN **2580**) → **Home & Sync**  
3. Set **Cloud server URL** to `http://<mac-lan-ip>:8787`  
4. **Pair device** → enter the 6-digit code  
5. **Pull catalog from cloud**

Devices and Mac must be on the same Wi‑Fi. iOS allows local HTTP; Android cleartext is enabled for LAN testing.

Playlist sync (separate from cloud) needs a YouTube Data API key (Parent settings → stored in secure storage). Synced titles that match the family blocklist are dropped automatically.

## Layout

```
lib/
  catalog/   models, seed v22, repository, sync + title filter, continue watching
  cloud/     pair + pull client for ../cloud API
  parent/    PIN, session, settings screen
  player/    YouTube iframe + video_player
  ui/        home (Shows|Mix), focus tiles, TV text dialogs
  main.dart
docs/
  ABOUT_APP.md          admin + household guide
  RUN_TV_AND_IPAD.md    install / pair checklist
```
