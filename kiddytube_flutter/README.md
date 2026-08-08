# KiddyTube (Flutter)

Cross-platform kids browser for:

- **Android phones / tablets**
- **Android TV** (Leanback launcher + D-pad focus)
- **iPad / iOS**

**Apple TV (tvOS)** is intentionally out of scope. The production Kotlin app in [`../KiddyTube`](../KiddyTube) remains the shipping Android build until Flutter fully replaces it; this Flutter app is a **working** Android + iPad build, not a stub.

## Features (current)

- Catalog seed parity with Kotlin `SEED_VERSION` **16**
- Home **Shows** vs **Mix** (Mix/Shows toggle gated behind parent PIN)
- YouTube / direct HTTPS **player** (kid-minimal iframe chrome; autoplay next in channel)
- Continue watching with **periodic resume progress** (and clamp near start/end)
- Parent PIN dashboard (change PIN, API key, enable channels, seek toggles, release ready, refresh playlists, clear continue watching, export catalog)
- Release builds block kid playback until the factory PIN is changed
- Channel tiles use YouTube preview thumbs when available
- Android TV Leanback launcher + focus tiles; D-pad seek when allowSeek is on

## Setup

Flutter SDK may be bootstrapped under `../.tools/flutter`:

```bash
export PATH="$PWD/../.tools/flutter/bin:$PATH"
cd kiddytube_flutter
flutter pub get
flutter test
flutter analyze
```

### Run

```bash
# iPad simulator
flutter devices
flutter run -d <ipad-simulator-id>

# Android phone / emulator
flutter run -d <android-device>

# Android TV emulator / device (Leanback)
flutter run -d <android-tv>
```

Default parent PIN for development: **2580**.

Playlist sync needs a YouTube Data API key (set in Parent settings → stored in secure storage).

## Layout

```
lib/
  catalog/   models, seed v16, repository, sync, continue watching
  parent/    PIN, session, settings screen
  player/    YouTube iframe + video_player
  ui/        home + focus tiles
  main.dart
```
