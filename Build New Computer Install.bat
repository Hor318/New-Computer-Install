@echo off
setlocal EnableExtensions
cd /d "%~dp0"

where pwsh.exe >nul 2>&1
if errorlevel 1 (set "PSHOST=powershell.exe") else (set "PSHOST=pwsh.exe")

echo ============================================================
echo  Building Aar318's New Computer Install v2.0.0
echo  The finished EXE will request administrator access at launch.
echo ============================================================
echo.

"%PSHOST%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $ProgressPreference='Continue'; Write-Host '[1/3] Validating the PowerShell source...' -ForegroundColor Cyan; & '.\New Computer Install.ps1' -SelfTest; Write-Host '[2/3] Loading the PS2EXE build module...' -ForegroundColor Cyan; try { Import-Module ps2exe -Force -ErrorAction Stop } catch { Write-Host 'PS2EXE is not installed; downloading it from PowerShell Gallery...' -ForegroundColor Yellow; Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber; Import-Module ps2exe -Force -ErrorAction Stop }; Write-Host '[3/3] Compiling the administrator manifest, icon, and version metadata...' -ForegroundColor Cyan; Invoke-ps2exe -inputFile '.\New Computer Install.ps1' -outputFile '.\New Computer Install.exe' -iconFile '.\Assets\New-Computer-Install.ico' -STA -DPIAware -supportOS -requireAdmin -title 'Aar318s New Computer Install' -description 'Selectable Windows setup, repair, and optimization tool' -company 'Hor318' -product 'Aar318s New Computer Install' -copyright 'Aaron Horan' -version '2.0.0.0'; if (!(Test-Path -LiteralPath '.\New Computer Install.exe')) { throw 'The compiler did not create the EXE.' }; $built=Get-Item -LiteralPath '.\New Computer Install.exe'; Write-Host ('Built {0:N0} bytes at {1}' -f $built.Length,$built.LastWriteTime) -ForegroundColor Green"

if errorlevel 1 (
  echo.
  echo Build failed. Review the error above.
  pause
  exit /b 1
)

echo.
echo Build complete: %~dp0New Computer Install.exe
echo The EXE includes a requireAdministrator manifest.
pause
