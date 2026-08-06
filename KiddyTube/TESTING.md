# Testing — Channel Browser

Default PIN: `2580`

Parent unlock:
- Tap the **lock** button (top-right) on channels or library, then PIN
- TV also: `↑ ↑ ↓ ↓ ← → ← → OK` or Back long-press ≥5s on **channels, library, or player**
  (short Back still exits library/player; home keeps Back consumed for kiosk)

## Automated

```bash
./gradlew test lintDebug assembleDebug
```

## Phone / tablet / TV

1. Open `KiddyTube` on phone, tablet, or Android TV AVD
2. Optionally add `YOUTUBE_API_KEY=...` to `local.properties`, then rebuild
3. Expect soft blue channel grid with **KiddyTube** title and lock button
4. Columns: phone fewer, tablet medium, TV denser
5. One-tap a channel → library; one-tap a video → player
6. Tap lock → PIN → parent dashboard (session lasts ~5 minutes)
7. In player: tap toggles pause/play; system Back exits; backgrounding pauses playback
8. Rotate tablet/phone on library — grid reflows

## TV remote

D-pad focuses tiles and the lock button (sky focus ring); OK opens; short Back leaves player/library; long-press Back opens PIN.

## Emergency

```bash
adb uninstall ae.kiddytube.app
```
