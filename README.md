# KiddyTube (`tvbox`)

Active monorepo for the **Flutter** kids app and **cloud** admin — not the old Kotlin TV app.

| Folder | Purpose |
| --- | --- |
| [`kiddytube_flutter/`](kiddytube_flutter/) | App for Android phone, Google TV, and iPad/iOS |
| [`cloud/`](cloud/) | FastAPI admin + device pairing + catalog / watch sync |
| [`render.yaml`](render.yaml) | Render Blueprint for deploying `cloud/` |
| [`.github/workflows/flutter.yml`](.github/workflows/flutter.yml) | Flutter CI |

## Quick start

```bash
# App
cd kiddytube_flutter
flutter pub get
flutter run --dart-define-from-file=local_defines.json

# Cloud (local)
cd ../cloud
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8787
```

Docs: [`kiddytube_flutter/docs/ABOUT_APP.md`](kiddytube_flutter/docs/ABOUT_APP.md) · [`kiddytube_flutter/docs/RUN_TV_AND_IPAD.md`](kiddytube_flutter/docs/RUN_TV_AND_IPAD.md) · [`cloud/DEPLOY_RENDER_NEON.md`](cloud/DEPLOY_RENDER_NEON.md)

## Archived Kotlin app

The former native Android TV project (`KiddyTube/`) and related launcher zip / `build-apk` workflow live in the **sibling** folder:

`../KiddyTube-kotlin-archive/`

That archive is frozen and not part of this project’s plans.
