# KiddyTube (Flutter)

Cross-platform kids browser aimed at **one UI** on:

- Android phones / tablets  
- Android TV (Leanback launcher + D-pad focus)  
- iOS phones / tablets  

**Apple TV (tvOS)** is intentionally later. The production Kotlin app in [`../KiddyTube`](../KiddyTube) stays shipping until Flutter catches up.

## Phase 1 (this folder)

- Catalog models + scaffold seed (verified YouTube starter IDs)
- Home **Shows** vs **Mix** (persisted)
- Shared focus tiles (touch + remote)
- Android TV manifest hooks (`LEANBACK_LAUNCHER`, optional leanback)

Not in Phase 1: YouTube player, parent PIN dashboard, playlist sync API, Watch Next.

## Setup

Flutter SDK was bootstrapped under `../.tools/flutter` if needed:

```bash
export PATH="$PWD/../.tools/flutter/bin:$PATH"
cd kiddytube_flutter
flutter pub get
flutter test
flutter run                 # phone / simulator
flutter run -d <android-tv> # Android TV emulator / device
```

## Layout

```
lib/
  catalog/   models, seed, shuffle/flatten, repository
  ui/        home + focus tiles
  main.dart
```
