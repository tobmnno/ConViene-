@echo off
setlocal
cd /d "%~dp0"

set DART_ANALYTICS_DISABLED=true
set FLUTTER_SUPPRESS_ANALYTICS=true

flutter --no-version-check run -d web-server --web-hostname 127.0.0.1 --web-port 53246 --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000
pause
