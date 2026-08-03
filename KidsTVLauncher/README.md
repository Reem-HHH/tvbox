# Kids TV Launcher — Clean TV Mode

A small Android / Android TV launcher that boots directly into a full-screen stream of approved official YouTube playlists.

## What Clean TV Mode changes

- No app buttons, labels, channel banners, loading messages, or volume pop-ups.
- Requests YouTube's supported `controls=0` player mode.
- Disables YouTube keyboard input, fullscreen button, annotations, touch, mouse, and air-mouse interaction.
- The remote controls playback through the YouTube IFrame API.
- **OK no longer pauses.** It only starts playback if autoplay was blocked. This avoids the title/channel panel that YouTube displays while paused.
- The embedded player is hidden before the native parent menu opens, so the menu is not placed over the player.

## Important YouTube limitation

YouTube can still show branding, a video title/channel avatar before playback, ads, errors, or end-state UI. These elements cannot be legally cropped, covered, or removed with unsupported tricks. For a guaranteed zero-YouTube interface, use local video files or licensed direct video/HLS URLs instead of YouTube.

## Remote controls

- **OK / Enter:** Start playback if stopped or blocked
- **Right / Channel Up / Media Next:** Next episode
- **Left / Channel Down / Media Previous:** Previous episode
- **Up / Down:** Device volume
- **1–4:** Select a channel directly
- **Page Up / Page Down:** Next or previous playlist/channel
- **Back / Home / Menu:** Blocked during child use

## Parent escape sequence

Press:

`Up, Up, Down, Down, Left, Right, Left, Right, OK`

This opens a native parent menu where you can open Android Settings or choose another Home app.

## Change the programmes

Edit:

`app/src/main/assets/channels.json`

Each entry needs a display name and a YouTube playlist ID. Use only playlists you are allowed to embed.

## Build

Open the folder in Android Studio and select **Build > Build APK(s)**, or run:

```bash
./gradlew assembleDebug
```

The APK is created at:

`app/build/outputs/apk/debug/app-debug.apk`

## Install

```bash
adb install -r app-debug.apk
```

During early testing, select **Just once** when Android asks which Home app to use.
