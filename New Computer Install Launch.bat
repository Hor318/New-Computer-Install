@echo off
cd /D "%~dp0"

:: Self-elevate to admin if not already running elevated
if not "%1"=="am_admin" (
    powershell -Command "Start-Process -FilePath '%0' -ArgumentList 'am_admin' -Verb RunAs"
    exit /b
)

:: Download and execute the latest downloader script from GitHub
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod 'https://raw.githubusercontent.com/Hor318/New-Computer-Install/main/New%%20Computer%%20Install%%20Downloader.ps1')"
