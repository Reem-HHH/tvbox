# Safe first test

## Before installing

Keep a USB keyboard or ADB connection available. On the first Home-app prompt, choose **Just once** until playback and parent PIN unlock work on your box.

## Build the APK

In Android Studio:

1. Open this project folder.
2. Let Gradle sync finish.
3. Select **Build > Build APK(s)**.
4. Find `app-debug.apk` in `app/build/outputs/apk/debug/`.

Or from a terminal:

```bash
./gradlew assembleDebug
./gradlew test
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
4. Open parent access with the installer trigger (keep this private from kids):
   `Up, Up, Down, Down, Left, Right, Left, Right, OK`
5. On first unlock, create a **4–8 digit parent PIN**, then confirm the parent menu opens.
6. Cancel / resume and confirm playback returns.
7. Try a wrong PIN five times and confirm temporary lockout.
8. Press Home and select **Kids TV > Just once**.
9. Reboot the box.
10. Only after everything works, press Home and select **Kids TV > Always**.
11. Optional: from the parent menu, try **Pin Kids TV (screen pinning)** and confirm the system UX on your firmware.

## Kiosk honesty checklist

- Voice / Google Assistant buttons may still work if the OEM never delivers those keys to the app.
- Recents / app-switch hardware keys may bypass an ordinary HOME app.
- Screen pinning is optional and user-confirmable; durable kiosk mode needs device owner / MDM.

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
