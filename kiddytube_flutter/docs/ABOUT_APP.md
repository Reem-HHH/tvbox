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

The older Kotlin TV app in `KiddyTube/` still exists for parity; day-to-day use is Flutter.

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

### Channels kids get by default (seed v25 highlights)

Islamic / Arabic-first shows, preschool series, plus recent adds:

| Tile | Notes |
| --- | --- |
| مكة مباشر / القرآن مباشر | Live + sleep Quran (black screen), ruqyah for home; live IDs can change |
| ماشا والدب | Arabic Masha |
| بليبي بالعربي | Arabic Blippi |
| ماروكو الصغيرة | Arabic Maruko |
| Disney Songs | EN sing-alongs + Mickey/Pooh (no auto Follow) |
| Kids Music | Toyor / Hala / Osratouna songs + البندورة الحمراء |
| بابار | Treehouse Babar & Badou (English allowlist) |
| حديقة المرح | WildBrain Arabic Night Garden |
| داوود، عمر وهنا، سبيستون أناشيد، … | Existing seed library |

Full dossiers: [`../KiddyTube/docs/channels/`](../KiddyTube/docs/channels/).

### Family content rules

On playlist sync, titles matching **Halloween, Thanksgiving, Pride/LGBTQ** (and common Arabic spellings) are **skipped**.  
This is title-based only — not a visual filter. New Disney / Blippi-style channels use **curated lists** (no Follow uploads) so holiday/Pride promos are less likely to appear.

---

## For you (admin)

### Day-to-day Flutter commands

```bash
export PATH="/Users/reema/Documents/tv box /tvbox/.tools/flutter/bin:$PATH"
cd "/Users/reema/Documents/tv box /tvbox/kiddytube_flutter"
cp -n local_defines.json.example local_defines.json   # YouTube API key once
flutter devices
flutter run --release --dart-define-from-file=local_defines.json -d <device-id>
```

Never commit `local_defines.json` (gitignored).

### Parent tabs (Flutter)

1. **Channels** — enable shows, Follow uploads, seek, add/delete videos, playlist ID  
2. **Security** — Change PIN, Release ready, Lock  
3. **Home & Sync** — Shows/Mix, YouTube API key, refresh playlists, cloud URL / pair / pull, export catalog  

### Cloud catalog (optional shared house library)

- Service: `cloud/` — FastAPI admin + per-device pairing codes  
- Start: `uvicorn app.main:app --host 0.0.0.0 --port 8787`  
- Admin UI: `http://127.0.0.1:8787/admin`  
- Devices: set **Cloud server URL** to `http://<your-mac-lan-ip>:8787`, pair with 6-digit code, **Pull catalog**  
- Devices **pull** from admin; edits on a device stay local unless you re-import via admin  

See [`../cloud/README.md`](../cloud/README.md) and [`RUN_TV_AND_IPAD.md`](RUN_TV_AND_IPAD.md).

### Live Makkah / Quran

Live YouTube IDs **rotate**. If مكة/قرآن مباشر stop working:

1. Open https://www.youtube.com/@SaudiQuranTv/live  
2. Copy the current video ID  
3. Parent → Channels → update that channel’s video  

### Adding / editing shows

- Seed upgrades (`SEED_VERSION`) merge new channels into existing installs once.  
- Prefer curated video lists for family-sensitive brands (Disney, Blippi).  
- Channel write-ups live under `KiddyTube/docs/channels/`.

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
| [RUN_TV_AND_IPAD.md](RUN_TV_AND_IPAD.md) | Install / pair checklist |
| [../cloud/README.md](../cloud/README.md) | Cloud admin API |
| [../KiddyTube/docs/channels/README.md](../KiddyTube/docs/channels/README.md) | Per-show notes |
