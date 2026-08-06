#!/bin/sh
set -eu
APK="${1:-app/build/outputs/apk/debug/app-debug.apk}"
adb install -r "$APK"
echo "Installed. Open KiddyTube once, then press Home and choose it as the launcher."
