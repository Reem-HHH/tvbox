# Test report

Checked on 3 August 2026; updated with the parent-PIN / hardening work.

## Automated in-repo (CI / `./gradlew test`)

These are **real** unit tests under `app/src/test`:

- `AssetPathSanitizerTest` — whitelist + traversal rejection
- `ParentUnlockGateTest` — trigger timeout, PIN hash verify, failure lockout

CI also runs `./gradlew assembleDebug` (and now `test`). That does **not** prove YouTube playback or OEM remote behavior.

## Manual / offline smoke (not CI)

Documented separately so they are not confused with automated green builds:

- `channels.json` parses and contains configured playlist IDs.
- Manifest / drawable / style XML are well formed.
- Browser preview via `python tools/preview.py` serves `player.html` and `channels.json`.
- Shell helper scripts pass syntax validation.

## Requires your Android box

- Full Gradle/Android SDK APK install on device.
- YouTube playback inside that box's Android System WebView.
- Autoplay behavior after boot.
- Remote key-code mapping on that specific remote.
- Parent PIN create / unlock / lockout on a physical remote.
- Default Home/launcher behavior on that manufacturer's firmware.
- Whether Assist / Recents / OEM keys escape kids mode despite in-app blocking.
- Optional screen-pinning confirmation UX.

During the first installation, select **Just once**, not **Always**, until parent PIN unlock has been verified. Keep ADB available for emergency recovery (`TESTING.md`).
