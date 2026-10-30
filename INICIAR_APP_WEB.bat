@echo off
setlocal
set "ROOT=%~dp0"
cd /d "%ROOT%"

set DART_ANALYTICS_DISABLED=true
set FLUTTER_SUPPRESS_ANALYTICS=true

set "FLUTTER=C:\PROGRA~1\Sdk\FLUTTE~1.5-S\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" (
  where flutter >nul 2>&1
  if errorlevel 1 (
    echo No encontre Flutter. Agrega flutter al PATH o instala el SDK esperado.
    exit /b 1
  )
  set "FLUTTER=flutter"
)
)

if exist "%ROOT%supabase.local.json" goto config_file
if not defined SUPABASE_URL goto missing_config
if not defined SUPABASE_PUBLISHABLE_KEY goto missing_config

"%FLUTTER%" --no-version-check run -d web-server --release --web-hostname 127.0.0.1 --web-port 53246 --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000 --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_PUBLISHABLE_KEY=%SUPABASE_PUBLISHABLE_KEY%
goto done

:config_file
"%FLUTTER%" --no-version-check run -d web-server --release --web-hostname 127.0.0.1 --web-port 53246 --dart-define=CONVIENE_API_BASE_URL=http://127.0.0.1:8000 "--dart-define-from-file=%ROOT%supabase.local.json"
goto done

:missing_config
echo Falta supabase.local.json y tampoco hay SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY en el entorno.

:done
pause
