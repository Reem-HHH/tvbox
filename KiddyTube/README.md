# KiddyTube — Channel Browser

A simple Android phone / tablet / TV kids app: browse channel thumbnails, open a video library, play fullscreen without website chrome.

**Application ID:** `ae.kiddytube.app`  
**Version:** `2.1.0-chunky`

## Screens

1. **Channels** — soft blue grid (phone fewer columns, tablet denser, TV fixed at 3 for overscan/focus)
2. **Library** — video thumbnails + titles for that channel
3. **Player** — YouTube clean IFrame *or* Media3 for direct MP4/HLS URLs (tap to pause/play)

Content is **parent-curated**. The home grid is **one channel = one named show** (no generic mixes). Fresh installs ship with starter YouTube playlist IDs and/or curated video IDs. Always review content in the parent dashboard before kids use it daily.

Per-show descriptions, content lists, and child-friendliness / conservative ratings: [`docs/channels/`](docs/channels/README.md).

On launch (when online), KiddyTube auto-refreshes linked playlists using the YouTube Data API. Failed syncs keep previously saved videos.

| Channel | Starter source |
|---------|----------------|
| Barney & Friends | Official uploads playlist |
| Spacetoon أناشيد | Expanded curated songs / nasheeds |
| مودا مودي | Curated Ramadan / Eid songs |
| Dora the Explorer | Official Dora & Friends uploads |
| سمارتا وحقيبتها العجيبة | Curated Arabic Spacetoon episodes |
| طيور الجنة | Curated Islamic kids songs |
| Sarah & Duck | Official uploads + starter episodes |
| Peppa Pig | Official uploads playlist |
| Adam & Mishmish | Curated song / letters videos |
| Kiki wa Nadoush / Zakaria / Rayan / Sweet Kalima / Abata | Per-show Arabic learning clips |
| LEGO DUPLO / Play-Doh / Toy Kitchen | Per-show toy play curated IDs |
| Dancing Fruit | Curated Hey Bear Sensory dancing-fruit clips |
| Mini Muslim | MiniMuslims uploads + starters |
| داوود | Single Dawood TV hub (Juz Amma playlist) |
| Kids Music | بابا فين / ماما جابت بيبي / مابي أنام |
| Omar & Hana | Official uploads + starters |
| CoComelon | Official nursery-rhyme starters |
| Masha and the Bear | Official English episode starters |
| منصور | Official مغامرات منصور starters |

Parent can change any playlist, add video IDs, or add direct MP4/HLS URLs.

## YouTube API key

Auto-sync needs a YouTube Data API key (never commit secrets):

1. **Parent dashboard** — Set YouTube API key (preferred; stored on device), or
2. **local.properties** (debug builds) — copy [`local.properties.example`](local.properties.example):

```properties
YOUTUBE_API_KEY=your_key_here
```

Parent-saved keys override the build-time key.

## Parent access

- **Phone / tablet / TV:** tap the **lock** button in the top-right header, then enter the PIN
- **TV remote (also):** `↑ ↑ ↓ ↓ ← → ← → OK` or long-press Back (≥5s) on channels, library, or player

Default development PIN: `2580` — change it before enabling Release ready. Unlock grants a short in-memory parent session (~5 minutes).

**Release builds:** kid playback stays blocked until the factory PIN is replaced. After that change, `2580` is rejected. Debug builds keep `2580` until Release ready is enabled.

Parent can:
- Set YouTube Data API key
- Paste playlist URL/ID per channel and refresh (clearing a playlist is remembered — seed upgrades will not re-attach it)
- Opt in per channel to **follow playlist uploads** on auto-sync (curated lists stay put by default)
- Add manual YouTube video IDs
- Add direct media URLs over **HTTPS only** (`.mp4` / `.m3u8` — not `http://`, not Google Drive `/view` pages; cleartext is disabled in the manifest)
- Enable/disable channels
- Export catalog JSON (for a future iOS app)

## Build

Open the `KiddyTube` folder in Android Studio (Quail 3+). Project Gradle settings force Configuration Cache and Isolated Projects **off** so Studio sync tooling does not fail. After a sync failure, run `./gradlew --stop`, delete `.gradle/configuration-cache` if present, set Gradle JDK to Embedded JDK, then Sync again.

```bash
cd KiddyTube
./gradlew clean test lintDebug assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## Install on a phone (sideload)

Sideload packages live in [`dist/`](../dist/):

- **Flutter (latest):** [`dist/KiddyTube-flutter-0.1.0.apk`](../dist/KiddyTube-flutter-0.1.0.apk) — catalog seed v50, package `ae.kiddytube.kiddytube`
- **Kotlin (merged main):** [`dist/KiddyTube-2.1.0.apk`](../dist/KiddyTube-2.1.0.apk) — version 2.1.0, package `ae.kiddytube.app`

Phone steps:

1. Open the APK link in Chrome (or another Android browser)
2. Tap the downloaded file
3. Allow installs from that browser if Android asks
4. Tap **Install**, then open **KiddyTube**

These builds are signed for sideloading (not Play Store). Parent PIN: `2580`. The Flutter and Kotlin APKs use different package IDs, so both can be installed at once.

From a computer with USB debugging (Kotlin app):

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n ae.kiddytube.app/.ui.ChannelGridActivity
```

This is a normal app (not a HOME launcher). Open it from the apps list.

## iOS later

Android exports the same catalog JSON schema. A future iPad app can reuse that file with AVPlayer / WKWebView.

## Honest limits

- YouTube may briefly show branding before play
- Without a YouTube API key (parent or `local.properties`), starter video IDs still play; full playlist refresh will not run
- Drive `/view` links are rejected; download to NAS or use a direct HTTPS file URL
- Cleartext `http://` media URLs are rejected (validator + `usesCleartextTraffic=false`)
- The player only starts YouTube IDs / direct URLs that already exist in the parent catalog
