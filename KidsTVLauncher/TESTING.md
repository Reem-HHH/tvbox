# Testing — Channel Browser

Default PIN: `2580`  
Parent unlock: `↑ ↑ ↓ ↓ ← → ← → OK` or Back long-press ≥5s

## Automated

```bash
./gradlew test lintDebug assembleDebug
```

## Android Studio / emulator

1. Open `KidsTVLauncher`
2. Run on Android TV AVD or tablet AVD
3. Expect channel grid (no autoplay)
4. Open a channel → empty library until parent adds content
5. Unlock parent → set YouTube API key + playlist ID → Refresh
6. Or add video IDs / direct `.mp4` URL → play

## Tablet touch

Confirm tiles open libraries and Back returns to the grid.

## TV remote

D-pad moves focus; OK opens; Back leaves player/library.

## Emergency

```bash
adb uninstall ae.kidstv.launcher
```
