# Kids TV — Channel Browser

A simple Android TV / tablet kids app: browse channel thumbnails, open a video library, play fullscreen without website chrome.

**Application ID:** `ae.kidstv.launcher`  
**Version:** `2.0.0-browser`

## Screens

1. **Channels** — grid of tiles (Barney, Spacetoon, Sara & Duck, Peppa, Arabic Cartoons, Learn Arabic, Mini Muslim, Islamic Kids)
2. **Library** — video thumbnails + titles for that channel
3. **Player** — YouTube clean IFrame *or* Media3 for direct MP4/HLS URLs

Content is **parent-curated only** (playlist IDs, video IDs, or direct URLs). No automated content filter — you choose what is allowed.

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
cd KidsTVLauncher
./gradlew clean test lintDebug assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## Install

```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n ae.kidstv.launcher/.ui.ChannelGridActivity
```

This is a normal app (not a HOME launcher). Open it from the apps list.

## iOS later

Android exports the same catalog JSON schema. A future iPad app can reuse that file with AVPlayer / WKWebView.

## Honest limits

- YouTube may briefly show branding before play
- Without a YouTube API key, add video IDs or direct URLs manually
- Drive `/view` links are rejected; download to NAS or use a direct file URL
