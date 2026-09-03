@echo off
setlocal
cd /d "%~dp0"

echo === Conviene / Scraper supermercados ===
echo.

where py >nul 2>nul
if errorlevel 1 (
  echo No se encontro el launcher de Python ^(py^).
  echo Instala Python 3.12 o superior y volve a ejecutar este archivo.
  pause
  exit /b 1
)

set "PYTHON_CMD="
for %%V in (3.13 3.12 3.14) do (
  py -%%V --version >nul 2>nul
  if not errorlevel 1 (
    set "PYTHON_CMD=py -%%V"
    goto :python_found
  )
)

echo No se encontro una version compatible de Python.
echo Instala Python 3.13 o 3.12 y volve a ejecutar este archivo.
pause
exit /b 1

:python_found
echo Usando %PYTHON_CMD%

if exist .venv rmdir /s /q .venv
%PYTHON_CMD% -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python -m camoufox fetch

echo.
echo Instalacion terminada.
echo Prueba sugerida:
echo python main.py "leche entera" --headed --engine camoufox
pause
