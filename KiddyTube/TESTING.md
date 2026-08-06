# Testing — Channel Browser

Default PIN: `2580`  
Parent unlock: `↑ ↑ ↓ ↓ ← → ← → OK` or Back long-press ≥5s

## Automated

```bash
./gradlew test lintDebug assembleDebug
```

## Android Studio / emulator

1. Open `KiddyTube`
2. Optionally add `YOUTUBE_API_KEY=...` to `local.properties`, then rebuild
3. Run on Android TV AVD or tablet AVD
4. Expect chunky sky/sun channel grid with **KiddyTube** title
5. With network + API key, sync chip shows “Updating…” then “Channels updated!”
6. Offline: chip shows “Offline — showing saved videos”; tiles keep cached content
7. Open a channel → library shows thumbnails/titles
8. Unlock parent → Refresh all playlists still works with force sync

## Tablet touch

Confirm tiles open libraries and Back returns to the grid. Focus/press should scale tiles.

## TV remote

D-pad moves focus (yellow sticker ring); OK opens; Back leaves player/library.

## Emergency

```bash
adb uninstall ae.kiddytube.app
```
