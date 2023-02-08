@echo off 
cd /D %~dp0
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
    
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/Hor318/New-Computer-Install/main/New%%20Computer%%20Install%%20Downloader.ps1)"
