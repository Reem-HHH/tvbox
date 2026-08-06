# KiddyTube — Channel Browser

A simple Android TV / tablet kids app: browse channel thumbnails, open a video library, play fullscreen without website chrome.

**Application ID:** `ae.kiddytube.app`  
**Version:** `2.0.0-browser`

## Screens

1. **Channels** — grid of tiles (Barney, Spacetoon, Sara & Duck, Peppa, Arabic Cartoons, Learn Arabic, Mini Muslim, Islamic Kids)
2. **Library** — video thumbnails + titles for that channel
3. **Player** — YouTube clean IFrame *or* Media3 for direct MP4/HLS URLs

Content is **parent-curated**. Fresh installs ship with starter YouTube playlist IDs / starter videos for each channel (official uploads where available). Always review content in the parent dashboard before kids use it daily.

| Channel | Starter source |
|---------|----------------|
| Barney | Scholastic Barney songs channel uploads |
| Spacetoon | Official Spacetoon Arabic uploads |
| Sara & Duck | Starter CBeebies episode IDs |
| Peppa Pig | Official Peppa uploads |
| Arabic Cartoons | Mansour Adventures playlist |
| Learn Arabic | Zaky / Kalam starter videos |
| Mini Muslim | MiniMuslims uploads + starter songs |
| Islamic Kids | Omar & Hana uploads |

Parent can change any playlist, add video IDs, or add direct MP4/HLS URLs.

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
- Without a YouTube API key, add video IDs or direct URLs manually
- Drive `/view` links are rejected; download to NAS or use a direct file URL
