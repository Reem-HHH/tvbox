# About KiddyTube

Practical notes for **you (admin)** and anyone using the app with kids.  
Primary app going forward: **Flutter** (`kiddytube_flutter/`) on phone, iPad, and Android TV.

---

## What the app is

KiddyTube is a kids video browser with a locked parent area. Kids see only the channels you enable. Parents manage PIN, catalog, YouTube sync, and optional cloud pairing.

| Audience | Platforms |
| --- | --- |
| Kids + parents | Android phone/tablet, Android TV (Google TV), iPad/iOS |
| Not supported | Apple TV (tvOS) |

Day-to-day use is this Flutter app. The older Kotlin Android TV app was moved out of this repo into the sibling archive `KiddyTube-kotlin-archive/` (frozen; not maintained here).

---

## For parents / household users

### Unlock parent settings

- Default **dev PIN: `2580`**
- On **release** builds, change this PIN before kids can watch (Security → Change PIN).
- Prefer Face ID / fingerprint when offered; otherwise enter the PIN.
- Home **Shows | Mix** toggle also asks for the parent PIN.

### Home screen

- **Shows** — one tile per channel (recommended for young kids).
- **Mix** — all videos from enabled channels in one grid.
- **Continue watching** — resumes near where they left off.
- Logo + lock open parent settings.

### Channels kids get by default (seed v26 highlights)

Islamic / Arabic-first shows, preschool series, plus recent adds:

| Tile | Notes |
| --- | --- |
| قرآن للنوم ورقية | Sleep Quran + ruqyah VODs only (no live streams) |
| ماشا والدب | Arabic Masha |
| بليبي وميكا | Arabic Blippi + Meeka |
| ماروكو الصغيرة | Arabic Maruko |
| Disney Songs | EN sing-alongs + Mickey/Pooh (no auto Follow) |
| Kids Music | Toyor / Hala / Osratouna songs + البندورة الحمراء |
| بابار | Treehouse Babar & Badou (English allowlist) |
| حديقة المرح | WildBrain Arabic Night Garden |
| داوود، عمر وهنا، سبيستون أناشيد، … | Existing seed library |

Full dossiers: [`channels/`](channels/).

### Family content rules

On playlist sync, titles matching **Halloween, Thanksgiving, Christmas, Christian/other religious propaganda, Pride/LGBTQ** (and common Arabic spellings) are **skipped**.  
Sync also skips **YouTube Shorts** (up to ~3 minutes / `#shorts`) and **live / upcoming** broadcasts when **adding** new items.  
Refresh is **append-only**: existing channel videos are never removed by sync (parents can still delete manually).  
This is API/title-based only — not a visual filter. Uploads-heavy channels keep **Follow off** by default; only curated playlists (داوود hub, Numberblocks S1) Follow daily.

---

## For you (admin)

### Day-to-day Flutter commands

```bash
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$PATH"
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
cp -n local_defines.json.example local_defines.json   # YouTube key + cloud URL/secret once
flutter devices
flutter run --release --dart-define-from-file=local_defines.json -d <device-id>
```

Never commit `local_defines.json` (gitignored).

### Parent tabs (Flutter)

1. **Channels** — enable shows, Follow uploads, seek, add/delete videos, playlist ID  
2. **Security** — Change PIN, Release ready, Lock  
3. **Home & Sync** — Shows/Mix, YouTube API key, refresh playlists, cloud status / pull, export catalog  

### Cloud catalog (optional shared house library)

- Service: `cloud/` — FastAPI admin + auto-enroll / pairing  
- Local: `uvicorn app.main:app --host 0.0.0.0 --port 8787`  
- Production: **Render + Neon** — see [`../../cloud/DEPLOY_RENDER_NEON.md`](../../cloud/DEPLOY_RENDER_NEON.md)  
- Admin UI: `http://127.0.0.1:8787/admin` (local) or `https://….onrender.com/admin`  
- Installs: prefer pairing codes from the cloud admin. Optional auto-enroll needs `CLOUD_AUTO_ENROLL=true` plus URL/secret in `local_defines.json`.  
- Watch history: Continue Watching can be synced manually (Parent → Sync watch history); Admin → Devices shows paired installs
- Devices only pull the cloud catalog when a parent taps **Pull catalog from cloud** (no auto daily pull)
- Edits on a device stay local unless you export and import via admin, then pull on other devices

See [`../cloud/README.md`](../cloud/README.md) and [`RUN_TV_AND_IPAD.md`](RUN_TV_AND_IPAD.md).

### Quran sleep / ruqyah channels

Seed **v26** removed rotating live stream IDs from sleep Quran / ruqyah. Seed **v31** merges those into one home tile (`live_makkah` — قرآن للنوم ورقية); the old `live_quran` tile is retired and its videos are absorbed on upgrade. Broken live items are dropped; the player also auto-skips unplayable videos in a queue.

### Adding / editing shows

- Seed upgrades (`SEED_VERSION`) merge new channels into existing installs once.  
- Prefer curated video lists for family-sensitive brands (Disney, Blippi).  
- Channel write-ups live under `docs/channels/`.

### Branch / shipping

- Active polish branch has historically been `polish/flutter-ios-next` (PR into `main`).  
- Don’t commit Gradle wrapper noise or `.idea/`.  
- Don’t commit YouTube API keys.

### Known limits

- Title filter ≠ full content moderation.  
- Cloud is LAN-friendly by default (not a public HTTPS deploy unless you set that up).  
- Leaving `flutter run` attached keeps a terminal session open after install — quit with `q` or kill the process when done.

---

## Quick links

| Doc | Purpose |
| --- | --- |
| [README.md](../README.md) | Flutter project overview + setup |
| [SHIP_CHECKLIST.md](SHIP_CHECKLIST.md) | Exact next steps after hardening (TV, PR, signing, cloud, PIN) |
| [RUN_TV_AND_IPAD.md](RUN_TV_AND_IPAD.md) | Install / pair checklist |
| [../cloud/README.md](../cloud/README.md) | Cloud admin API |
| [channels/README.md](channels/README.md) | Per-show notes |
