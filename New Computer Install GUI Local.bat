@echo off
setlocal
cd /d "%~dp0"

:: Self-elevate to admin if not already running elevated
if not "%1"=="am_admin" (
    powershell -NoProfile -Command "Start-Process -FilePath '%0' -ArgumentList 'am_admin' -Verb RunAs"
    exit /b
)

if exist "New Computer Install.exe" (
    "New Computer Install.exe" -Gui
    exit /b %errorlevel%
)

if exist "New Computer Install.ps1" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File ".\New Computer Install.ps1" -Gui
    exit /b %errorlevel%
)

echo Local New Computer Install files were not found in:
echo %CD%
pause
exit /b 1
