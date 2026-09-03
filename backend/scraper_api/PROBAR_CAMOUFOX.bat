@echo off
cd /d "%~dp0"
if not exist .venv\Scripts\python.exe (
	echo No se encontro la virtualenv. Ejecuta INSTALAR_WINDOWS.bat primero.
	pause
	exit /b 1
)
call .venv\Scripts\python.exe main.py "leche entera" --headed --engine camoufox
pause
