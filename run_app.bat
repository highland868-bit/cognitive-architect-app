@echo off
cd /d "%~dp0"
REM Fixed --web-port: flutter run already auto-persists the Chrome
REM profile (localStorage, API key, voice choice) between dev sessions
REM on its own, via a per-project cache in .dart_tool/chrome-device --
REM no --user-data-dir flag needed for that part. But it picks a random
REM port each launch by default, and localStorage is scoped per-origin
REM INCLUDING port, so a fixed port is what actually makes that cache
REM useful across runs instead of landing in a different bucket every time.
flutter run -d chrome --web-port=52890
pause
