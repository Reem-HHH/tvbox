# Run KiddyTube (Flutter) on iPad & Android TV

One Flutter app for phone, iPad, and Android TV. Use this checklist whenever you need to install or re-pair devices.

Default parent PIN (dev): **2580**

---

## 0. Prerequisites

- Mac with Flutter (repo may include `../.tools/flutter`)
- iPad and/or Android TV on the **same Wi‑Fi** as the Mac
- Cloud admin running when you want shared catalog sync

```bash
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$PATH"
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
cp -n local_defines.json.example local_defines.json   # once: paste YouTube API key
flutter pub get
flutter devices
```

### Open in Android Studio (install on TV)

Open the **Flutter project folder**, not a single file:

`/Users/reema/Documents/tv box /tvbox/kiddytube_flutter`

1. Android Studio → **File → Open** → select the `kiddytube_flutter` folder.
2. Do **not** open only `android/`, and do **not** open the old native app at `KiddyTube/` — those are not this Flutter project.
3. Wait for Gradle/Flutter indexing to finish (bottom status bar).
4. Install the **Flutter** and **Dart** plugins if prompted (**Settings → Plugins**).
5. In the device dropdown (top toolbar), pick your **Android TV / Google TV**, then click **Run**.

#### If Android Studio only shows iOS simulators

That usually means Studio is listing Apple simulators, not that the TV is offline. Your TV is an **Android** device via ADB.

1. On the TV: enable **Developer options** → **ADB debugging** + **Wireless debugging** / network debugging.
2. On the Mac, confirm ADB sees the TV:

```bash
export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
adb devices -l
```

You want a line with `device` (not `offline`). Example: `Google_TV_Streamer`.

3. If empty, connect by IP (TV and Mac on same Wi‑Fi). Find the TV IP in its network settings, then:

```bash
adb connect <tv-ip>:5555
adb devices -l
```

4. Prefer installing from the **terminal** (most reliable for wireless Google TV):

```bash
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$HOME/Library/Android/sdk/platform-tools:$PATH"
flutter devices
flutter run --dart-define-from-file=local_defines.json -d <android-tv-id>
```

Use the id Flutter prints for the Google TV / Android device (not `macos`, not an iPhone simulator).

5. In Android Studio: open the device dropdown → look for an **Android** entry (may say “wireless”). Click the refresh icon next to the device list. If only iOS appears, use step 4.

---

## 1. Start the cloud admin (Mac)

```bash
cd "/Users/reema/Documents/tv box /tvbox/cloud"
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8787
```

- Admin UI: [http://127.0.0.1:8787/admin](http://127.0.0.1:8787/admin)
- Default login (from `cloud/.env`): `admin@example.com` / `change-me-now`
- Find Mac LAN IP:

```bash
ipconfig getifaddr en0
```

Example cloud URL for devices: `http://192.168.1.20:8787`  
(`0.0.0.0` in uvicorn is required so phones/TVs can reach the Mac.)

On the admin site: **Devices → Generate pairing code** when you are ready to pair.

---

## 2. Install / run on iPad

1. Unlock the iPad; connect with USB **or** enable wireless debugging / trust the Mac.
2. Accept “Trust This Computer” if prompted; enable **Developer Mode** on the iPad if iOS asks.
3. List devices and run:

```bash
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$PATH"
flutter devices
flutter run --dart-define-from-file=local_defines.json -d <ipad-device-id>
```

First install can take several minutes. Leave the cable connected until the app launches.

**Simulator (optional):**

```bash
open -a Simulator
flutter run --dart-define-from-file=local_defines.json -d <ipad-simulator-id>
```

Note: Simulator uses the Mac network, so cloud URL can be `http://127.0.0.1:8787`. A **physical** iPad must use the Mac’s LAN IP, not `127.0.0.1`.

---

## 3. Install / run on Android TV

**Easiest with Android Studio:** open `kiddytube_flutter` (see **Open in Android Studio** above), pick the TV, click **Run**.

Or from the terminal:

1. On the TV: **Settings → Device preferences → About → Build number** (tap ~7 times) → open **Developer options**.
2. Enable **ADB debugging** (and **Network debugging** / wireless debugging if you use Wi‑Fi adb).
3. Connect:
   - **USB**, or
   - **Wireless:** `adb connect <tv-ip-address>:5555`
4. Run:

```bash
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$PATH"
flutter devices
flutter run --dart-define-from-file=local_defines.json -d <android-tv-id>
```

The app appears in the Android TV launcher (Leanback). Use the remote / D-pad to navigate.

---

## 4. Pair each device to the family catalog

Do this once per TV / iPad (each device gets its own token).

1. Mac admin → **Devices** → **Generate pairing code** (6 digits, expires in ~10 minutes).
2. On the device: open KiddyTube → parent unlock (PIN **2580**) → **Home & Sync**.
3. **Cloud server URL** → e.g. `http://<mac-lan-ip>:8787`
4. **Pair device** → enter the code → name the device (e.g. “Living room TV”).
5. **Pull catalog from cloud**.

After that, opening the app can pull the cloud catalog about once per day when paired. Use **Pull catalog from cloud** anytime for an immediate refresh.

To remove a device: **Unpair this device** in the app, and **Revoke** it in the web admin.

---

## 5. Edit content for all devices

1. Mac → [http://127.0.0.1:8787/admin](http://127.0.0.1:8787/admin) → **Catalog**
2. Add/remove channels and videos (or **Import** a catalog JSON export from the app)
3. On each device: **Pull catalog from cloud** (or wait for the daily pull)

---

## Troubleshooting

| Problem | What to try |
|--------|-------------|
| `flutter devices` empty | Wake/unlock device; reconnect USB; for TV run `adb devices`; for iPad trust the Mac |
| Pair / pull fails | Mac + device on same Wi‑Fi; cloud started with `--host 0.0.0.0`; URL uses LAN IP not `127.0.0.1` on physical devices |
| iPad blocks HTTP | App allows local networking (`NSAllowsLocalNetworking`); still use `http://` LAN IP |
| Android cleartext | App allows cleartext for LAN testing (`usesCleartextTraffic`) |
| Wrong catalog | Confirm you paired this device and pulled after editing the admin catalog |
| Parent lock | Dev PIN is **2580** until you change it under **Security** |

---

## Quick command cheat sheet

```bash
# Flutter
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$PATH"
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
flutter devices
flutter run --dart-define-from-file=local_defines.json -d <device-id>

# Cloud
cd "/Users/reema/Documents/tv box /tvbox/cloud"
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8787

# Mac LAN IP
ipconfig getifaddr en0
```

More project notes: [README.md](../README.md) · Cloud API: [../../cloud/README.md](../../cloud/README.md)
