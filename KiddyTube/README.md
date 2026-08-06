# KiddyTube — Channel Browser

A simple Android TV / tablet kids app: browse channel thumbnails, open a video library, play fullscreen without website chrome.

**Application ID:** `ae.kiddytube.app`  
**Version:** `2.1.0-chunky`

## Screens

1. **Channels** — chunky sticker tiles on a sky/sun background
2. **Library** — video thumbnails + titles for that channel
3. **Player** — YouTube clean IFrame *or* Media3 for direct MP4/HLS URLs

Content is **parent-curated**. Fresh installs ship with starter YouTube playlist IDs / starter videos for each channel (official uploads where available). Always review content in the parent dashboard before kids use it daily.

On launch (when online), KiddyTube auto-refreshes linked playlists using the YouTube Data API. Failed syncs keep previously saved videos.

| Channel | Starter source |
|---------|----------------|
| Barney | Scholastic Barney songs channel uploads |
| Spacetoon | Official Spacetoon Arabic uploads |
| Sara & Duck | Official Sarah & Duck uploads + starter episodes |
| Peppa Pig | Official Peppa uploads |
| Arabic Cartoons | Mansour Adventures playlist |
| Learn Arabic | One4kids (Zaky) uploads + starter videos |
| Mini Muslim | MiniMuslims uploads + starter songs |
| Islamic Kids | Omar & Hana uploads |

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

Sequence: `↑ ↑ ↓ ↓ ← → ← → OK` or long-press Back (≥5s), then PIN.

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
