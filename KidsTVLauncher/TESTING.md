# Safe first test

## Before installing

Keep a USB keyboard or ADB connection available. On the first Home-app prompt, choose **Just once** until playback and the parent escape sequence work on your box.

## Build the APK

In Android Studio:

1. Open this project folder.
2. Let Gradle sync finish.
3. Select **Build > Build APK(s)**.
4. Find `app-debug.apk` in `app/build/outputs/apk/debug/`.

Or from a terminal:

```bash
./gradlew assembleDebug
```

## Install with ADB

```bash
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

## Test without making it permanent

1. Open **Kids TV** from the box's Apps screen.
2. Confirm a video loads.
3. Test OK, Left, Right, Up and Down.
4. Test the parent sequence:
   `Up, Up, Down, Down, Left, Right, Left, Right, OK`.
5. Press Home and select **Kids TV > Just once**.
6. Reboot the box.
7. Only after everything works, press Home and select **Kids TV > Always**.

## Emergency recovery

From a connected computer:

```bash
adb shell am start -a android.settings.SETTINGS
```

If necessary, uninstall the launcher:

```bash
adb uninstall ae.kidstv.launcher
```

## Browser preview

This tests the streaming page and playlists before installing Android:

```bash
python tools/preview.py
```

Open `http://127.0.0.1:8765/player.html` in a browser.
