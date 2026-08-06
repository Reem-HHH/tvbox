@echo off
set APK=%~1
if "%APK%"=="" set APK=app\build\outputs\apk\debug\app-debug.apk
adb devices >nul 2>&1
adb install -r "%APK%"
echo Installed. Open KiddyTube once, then press Home and choose it as the launcher.
