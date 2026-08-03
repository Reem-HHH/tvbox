# Test report

Checked on 3 August 2026:

## Passed here

- `channels.json` parses and contains four unique playlist IDs.
- Android manifest and drawable/style XML files are well formed.
- The embedded player JavaScript passes Node syntax validation.
- `MainActivity.java` passes a Java 17 static compilation against Android API-shaped stubs.
- The local browser preview server correctly serves `player.html` and `channels.json`.
- Shell helper scripts pass syntax validation.

## Requires your Android box

- Full Gradle/Android SDK APK compilation.
- YouTube playback inside that box's Android System WebView.
- Autoplay behavior after boot.
- Remote key-code mapping on that specific remote.
- Default Home/launcher behavior on that manufacturer's firmware.

During the first installation, select **Just once**, not **Always**, until the parent escape sequence has been verified.
