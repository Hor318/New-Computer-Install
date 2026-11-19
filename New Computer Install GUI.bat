@echo off
cd /D "%~dp0"

:: Download the current GitHub release and launch it in GUI mode.
if not "%1"=="am_admin" (
    powershell -NoProfile -Command "Start-Process -FilePath '%0' -ArgumentList 'am_admin' -Verb RunAs"
    exit /b
)

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; $path=Join-Path $env:TEMP ('NCI-Downloader-'+[guid]::NewGuid().ToString('N')+'.ps1'); try { Invoke-WebRequest 'https://raw.githubusercontent.com/Hor318/New-Computer-Install/main/New%%20Computer%%20Install%%20Downloader.ps1' -OutFile $path -UseBasicParsing -ErrorAction Stop; & $path -Gui; exit $LASTEXITCODE } finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }"
