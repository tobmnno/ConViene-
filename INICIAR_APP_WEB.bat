@echo off
setlocal
cd /d "%~dp0"

set DART_ANALYTICS_DISABLED=true
set FLUTTER_SUPPRESS_ANALYTICS=true

if exist "supabase.local.json" (
  set "SUPABASE_DEFINES=--dart-define-from-file=supabase.local.json"
) else (
  if not defined SUPABASE_URL goto missing_config
  if not defined SUPABASE_PUBLISHABLE_KEY goto missing_config
  set "SUPABASE_DEFINES=--dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_PUBLISHABLE_KEY=%SUPABASE_PUBLISHABLE_KEY%"
)

flutter --no-version-check run -d web-server --release --web-hostname 127.0.0.1 --web-port 53246 --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000 %SUPABASE_DEFINES%
goto done

:missing_config
echo Falta supabase.local.json. Copia supabase.local.example.json y completa la URL y la publishable key de Supabase.

:done
pause
