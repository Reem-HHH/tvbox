# KiddyTube — Channel Browser

A simple Android phone / tablet / TV kids app: browse channel thumbnails, open a video library, play fullscreen without website chrome.

**Application ID:** `ae.kiddytube.app`  
**Version:** `2.1.0-chunky`

## Screens

1. **Channels** — soft blue grid (column count adapts for phone / tablet / TV)
2. **Library** — video thumbnails + titles for that channel
3. **Player** — YouTube clean IFrame *or* Media3 for direct MP4/HLS URLs (tap to pause/play)

Content is **parent-curated**. The home grid is **one channel = one named show** (no generic mixes). Fresh installs ship with starter YouTube playlist IDs and/or curated video IDs. Always review content in the parent dashboard before kids use it daily.

Per-show descriptions, content lists, and child-friendliness / conservative ratings: [`docs/channels/`](docs/channels/README.md).

On launch (when online), KiddyTube auto-refreshes linked playlists using the YouTube Data API. Failed syncs keep previously saved videos.

| Channel | Starter source |
|---------|----------------|
| Barney & Friends | Official uploads playlist |
| Spacetoon أناشيد | Curated nasheed IDs only |
| مودا مودي | Curated Ramadan / Eid songs |
| Sarah & Duck | Official uploads + starter episodes |
| Peppa Pig | Official uploads playlist |
| Adam & Mishmish | Curated song / letters videos |
| Kiki wa Nadoush / Zakaria / Rayan / Sweet Kalima / Abata | Per-show Arabic learning clips |
| LEGO DUPLO / Play-Doh / Toy Kitchen | Per-show toy play curated IDs |
| Mini Muslim | MiniMuslims uploads + starters |
| Omar & Hana | Official uploads + starters |

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
- **TV remote (also):** `↑ ↑ ↓ ↓ ← → ← → OK` or long-press Back (≥5s) on the channel home

Default development PIN: `2580` — change it before enabling Release ready.

Parent can:
- Set YouTube Data API key
- Paste playlist URL/ID per channel and refresh
- Add manual YouTube video IDs
- Add direct media URLs (Archive/NAS `.mp4` / `.m3u8` — **not** Google Drive `/view` pages)
- Enable/disable channels
- Export catalog JSON (for a future iOS app)

## Build

```bash
cd KiddyTube
./gradlew clean test lintDebug assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## Install

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
- Drive `/view` links are rejected; download to NAS or use a direct file URL
