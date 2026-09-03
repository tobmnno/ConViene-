@echo off
setlocal
cd /d "%~dp0"

if not exist ".venv\Scripts\python.exe" (
  echo No encontre .venv. Crealo con:
  echo py -3.13 -m venv .venv
  echo .venv\Scripts\python.exe -m pip install -r requirements.txt
  echo .venv\Scripts\python.exe -m camoufox fetch
  exit /b 1
)

".venv\Scripts\python.exe" -m uvicorn api:app --host 127.0.0.1 --port 8000 --reload
