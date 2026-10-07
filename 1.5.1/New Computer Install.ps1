<#===============================================================================================================================
|Version: 1.5.1                                                                                                                |
|By Aaron Horan                                                                                                                  |
|Created 04.14.2020                                                                                                              |
|Update 03.13.2026                                                                                                               |
================================================================================================================================#>

# Store all the start up variables so you can clean up when the script finishes.
If ( $startupvariables ) { 
    Try { Remove-Variable -Name startupvariables -Scope Global -ErrorAction SilentlyContinue } Catch { } 
}
New-Variable -Force -Name startupVariables -Value ( Get-Variable | ForEach-Object { $_.Name } ) 

$myExe = 'New Computer Install'

Function Relaunch {
    If ( Test-Path "$env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\*$myExe.*" ) {
        Write-Host "[$(timeStamp)] I found you: $env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\*$myExe" -ForegroundColor Gray
        $runMe = Get-ChildItem "$env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\*\" | Where-Object { $_.BaseName -like "*$myExe*" } | Select-Object -ExpandProperty FullName
        Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File $runMe" -Verb RunAs
    } ElseIf ( Test-Path "${PSScriptRoot}\$myExe.exe" ) {
        Start-Process "${PSScriptRoot}\$myExe.exe" -Verb RunAs
    } ElseIf ( Test-Path "${PSScriptRoot}\$myExe.ps1" ) {
        Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } Else {
        Write-Warning "[$(timeStamp)] Unable to locate file [$myExe] in [$PSScriptRoot]. Cannot relaunch."
    }
} # End Relaunch Function

If (!( [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent() ).IsInRole( [Security.Principal.WindowsBuiltInRole]"Administrator" )) {
    Write-Host "[$(timeStamp)] Administrator rights were not detected! Attempting to run as an administrator now.." -ForegroundColor Yellow
        Relaunch
        Exit
}

$ErrorActionPreference = 'SilentlyContinue' 

# Resize console window size
[console]::WindowWidth=135; [console]::WindowHeight=34; [console]::BufferWidth=[console]::WindowWidth

Function timeStamp {
    Return "{0:MM/dd/yy} {0:HH:mm:ss}" -f ( Get-Date )
} # End timeStamp Function

$StopWatch = New-Object System.Diagnostics.Stopwatch
    $StopWatch.Start()

    Write-Host "[$(timeStamp)] Running as Administrator!" -ForegroundColor Cyan
    Set-ExecutionPolicy RemoteSigned -force
Push-Location ${PSScriptRoot} -StackName Stack2

<# =================================================================================================================================
 Log Time + Script Variables     #>
    $scriptLogName = "New Computer Install"

    If ( $scriptLogName -eq "MyScriptName" ) { 
        Write-Warning "[$(timeStamp)] Please change the scriptLogName in the script and try again"
        Start-Sleep -s 5 
        Exit 
    }

    $Date = Get-Date -Format "ddddMM-dd-yyyy_HH.mm.ss"
    $Log = "C:\Windows\Temp\$scriptLogName" + "-" + $Date + ".log"
    $TARGETDIR = "C:\Windows\Temp\$scriptLogName*.log"
    $NumberToKeep = 3

    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
  
    $host.ui.RawUI.WindowTitle = "$scriptLogName by Aaron Horan"

<# =================================================================================================================================
 Remove Existing Log Files     #>
    If ( Test-Path -Path $TARGETDIR ) {
        Write-Host "[$(timeStamp)] Existing log file(s) found. Keeping the last $NumberToKeep and creating a new one for this session." -BackgroundColor Red -ForegroundColor White
            Get-ChildItem $TARGETDIR | Sort-Object Name -Descending | Select-Object -Skip $NumberToKeep | Remove-Item -Force
        Write-Host "[$(timeStamp)] Removed all but the last $NumberToKeep log files from $TARGETDIR" -BackgroundColor Red -ForegroundColor White
    }
 
<# =================================================================================================================================
Creates a log file for this process      #>
    Start-Transcript -Path $Log -Force | ForEach-Object { "[$(timeStamp)] $_" }
        Write-Host "[$(timeStamp)] Creating a new log file in $TARGETDIR at Time: $(timeStamp)" -BackgroundColor Red -ForegroundColor White

<# =================================================================================================================================
Install Chocolatey, updates Powershell, and sets Time Zone as needed      #>
Function PreRequisites {
    [CmdletBinding(SupportsShouldProcess)]

    $TARGETDIR = 'C:\ProgramData\Chocolatey\choco.exe'
    If (!( Test-Path -Path $TARGETDIR )) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression (( New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1' ))

        # Refresh environment variables in the current session so choco is immediately
        # available in PATH — no relaunch needed
        $env:ChocolateyInstall = "$env:ProgramData\chocolatey"
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
        Write-Host "[$(timeStamp)] Chocolatey installed and environment refreshed. Continuing script." -ForegroundColor Cyan
    }
    
    Write-Host "[$(timeStamp)] Chocolatey is installed. Continuing script." -ForegroundColor Gray

    $MyPowershell = $PSVersionTable.PSVersion
    If ( $MyPowershell -lt [Version]"5.0" ) {
        Write-Host "[$(timeStamp)] You are on version $MyPowershell. Attempting to upgrade now." -ForegroundColor Yellow
            cmd /c "choco upgrade -y powershell --force" | ForEach-Object { "[$(timeStamp)] $_" }
                Relaunch
                Exit
    }
    Write-Host "[$(timeStamp)] PowerShell version: $MyPowershell" -ForegroundColor Gray

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force | Out-Null

    Write-Host "[$(timeStamp)] Updating PowerShellGet.." -ForegroundColor Gray
    Try {
        Install-Module -Name PowerShellGet -Force -AllowClobber -SkipPublisherCheck -Scope AllUsers -ErrorAction Stop | Out-Null
        Import-Module PowerShellGet -Force -ErrorAction SilentlyContinue
        Write-Host "[$(timeStamp)] PowerShellGet updated and loaded." -ForegroundColor Gray
    } Catch {
        Write-Warning "[$(timeStamp)] PowerShellGet update failed — continuing with existing version. Error: [$($_.Exception.Message)]"
    }

    $instModules = @("PSWindowsUpdate")
    ForEach ( $module in $instModules ) {
        If ( $moduleInfo = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1 ) {
            Write-Host "[$(timeStamp)] Module [$module ($($moduleInfo.Version))] already installed." -ForegroundColor Gray
            Try { 
                Install-Module -Name $module -Force -AllowClobber -SkipPublisherCheck -Scope AllUsers -ErrorAction Stop | Out-Null
                Write-Host "[$(timeStamp)]   [$module] updated." -ForegroundColor Gray
            } Catch { 
                Write-Warning "[$(timeStamp)] Error updating [$module]: [$($_.Exception.Message)]"
            }
        } Else {
            Write-Host "[$(timeStamp)] Module [$module] not found. Installing now.." -ForegroundColor Cyan
            Install-Module $module -Confirm:$false -Force -AllowClobber -SkipPublisherCheck -Scope AllUsers
        }
    } # End ForEach

    Import-Module PowerShellGet -Force -ErrorAction SilentlyContinue

} # End PreRequisites function

<# =================================================================================================================================
Function to Display the Weather      #>
Function myWeather {
    Try {
        $geoData = Invoke-RestMethod -Uri "http://ipinfo.io/json" -TimeoutSec 10
        $City = $geoData.city
        $Region = $geoData.region
        Write-Host "[$(timeStamp)] Location detected: $City, $Region" -ForegroundColor Gray
    } Catch {
        Write-Host "[$(timeStamp)] Could not detect location — using IP-based auto-detect." -ForegroundColor Yellow
        $City = ""
    }

    Write-Host ""
    Try {
        $Weather = $( Invoke-WebRequest "http://wttr.in/$City" -UserAgent curl -UseBasicParsing -TimeoutSec 10 ).content -split "`n"
        $Weather[0..16]
    } Catch {
        Write-Host "[$(timeStamp)] Weather lookup failed. Continuing." -ForegroundColor Yellow
    }
    Write-Host ""
} # End myWeather Function

<# =================================================================================================================================
Function to Configure NTP Settings to go through time.nist.gov and set to EST time zone     #>
Function setTimeZone {
  	[CmdletBinding()]
  	Param (
		    [ValidateSet( 'Hawaiian','Pacific','Mountain','Central','Eastern' )][String]$myTimeZone = 'Eastern'
    )   

    [timezoneinfo]::ClearCachedData()
    $currentTimeZone = [timezoneinfo]::Local.id

        Write-Host "[$(timeStamp)] Time Zone check — current: $currentTimeZone" -ForegroundColor Gray
            If (!( ( Get-TimeZone ).id -eq "$myTimeZone Standard Time" )) {
                Write-Host "[$(timeStamp)] Setting time zone to [$myTimeZone] and NTP to time.nist.gov" -ForegroundColor Cyan
                    w32tm /config /manualpeerlist:time.nist.gov,0x8 /syncfromflags:manual /reliable:yes /update | Out-Null
                    Set-TimeZone -Id "$myTimeZone Standard Time"
                    [timezoneinfo]::ClearCachedData()
                        $currentTimeZone = [timezoneinfo]::Local.id
            } ElseIf ( ( Get-TimeZone ).id -eq "$myTimeZone Standard Time" ) { 
                Write-Host "[$(timeStamp)] Time zone already set to [$myTimeZone]. Skipping." -ForegroundColor Gray
            }

    Write-Host "[$(timeStamp)] Time Zone after update: $currentTimeZone" -ForegroundColor Gray
} # End setTimeZone Function

<# =================================================================================================================================
Function to remove bloatware apps. Comment out specifics to keep them     #>
Function RemoveBloatware {
<# Bloatware Removal - add exclusions where needed |.*photos.*|.*OneNote.*| etc etc
 if it messes up this reinstalls all : 
   Get-AppxPackage -allusers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
 -----------------------------------------------------------------------------
 to get a specific app name --- Get-AppxPackage -name *lenovo*
 E046963F.LenovoSettingsforEnterprise # Commercial Vantage
 E046963F.LenovoCompanion # Lenovo Vantage
 DellInc.DellSupportAssistforPCs # dell support assist for pcs
 HP Support Assistant # may not include an app - may be standalone exe
 ----------------------------------------------------------------------------- #>
    Write-Host "[$(timeStamp)] Removing Bloatware!" -ForegroundColor Cyan
        $excludedApps = '.*photos.*|.*calculator.*|.*OneNote.*|.*Store.*|.*Camera.*|.*Microsoft\.WindowsNotepad.*|.*MicrosoftTeams.*|.*DellSupportAssist.*|.*LenovoSettingsforEnterprise.*|.*LenovoCompanion.*|.*HP Support Assistant.*|.*WindowsScan.*'
        $unwantedApps = Get-AppxPackage -AllUsers -PackageTypeFilter Bundle | Where-Object { $_.Name -notmatch $excludedApps }
        $unwantedProvApps = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -notmatch $excludedApps }
    
    If ( $unwantedApps ) {
        $ErrorActionPreference = 'SilentlyContinue'
            Write-Host "[$(timeStamp)] Removing unwanted applications.." -ForegroundColor Gray
            $unwantedApps | Remove-AppxPackage
            ForEach ($provApp in $unwantedProvApps) { 
                Write-Host "[$(timeStamp)]   Removing provisioned app: [$($provApp.DisplayName)]" -ForegroundColor Gray
                $provApp | Remove-AppxProvisionedPackage -AllUsers
            }
        $ErrorActionPreference = 'Continue'        
    }
} # End RemoveBloatware Function

<# =================================================================================================================================
Function to get computer name and rename it     #>
Function GetComputerName {
    If ( $env:COMPUTERNAME -like "DESKTOP*" -or $env:COMPUTERNAME -like "Win-*" ) {
        $NewPCName = Read-Host "Please type a new computer name: "
            If ( $NewPCName.length -gt 15 ) {
                Clear-Variable NewPCName
                Write-Warning "[$(timeStamp)] Please keep the computer name to 15 characters or less."
                    GetComputerName
                    Return
            }
            If ( $NewPCName.length -lt 1 ) {
                Write-Warning "[$(timeStamp)] Please enter a value and try again"
                  GetComputerName
                  Return
            }
        Rename-Computer -NewName "$NewPCName" -Force #-Restart
    } Else {
        Write-Host "[$(timeStamp)] Computer name [$env:COMPUTERNAME] is already customized. Skipping rename." -ForegroundColor Gray
    }
} # End GetComputerName Function

<# =================================================================================================================================
Function to disable the show suggestions in start button     #>
Function DisableShowSuggestions {
    REG ADD "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f | Out-Null
        Write-Host "[$(timeStamp)] Show Suggestions in Start disabled (takes effect after reboot)" -ForegroundColor Gray
}

<# =================================================================================================================================
Function to disable the IPv6 Components     #>
Function DisableIPv6Components {
    REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v "DisabledComponents" /t REG_DWORD /d 0xFF /f | Out-Null
        Write-Host "[$(timeStamp)] IPv6 Components disabled" -ForegroundColor Gray
}

<# =================================================================================================================================
Function to set high performance mode     #>
Function HighPerformance {
    Write-Host "[$(timeStamp)] Setting power plan to High Performance.." -ForegroundColor Cyan
        Powercfg -SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        $myPowerScheme = Powercfg -getactivescheme
        Write-Host "[$(timeStamp)] $myPowerScheme" -ForegroundColor Gray
        Powercfg -Change -monitor-timeout-ac 60
        Powercfg -Change -monitor-timeout-dc 30
        Powercfg -Change -standby-timeout-ac 0
        Powercfg -Change -standby-timeout-dc 0
}

<# =================================================================================================================================
Function to install basic software via chocolatey     #>
Function ChocoSoftware {
    [CmdletBinding()]
    Param (
        [ValidateSet( 'Adobereader','Foxitreader' )][String]$PDFViewer = 'Adobereader'
    )

    $string1 = (( $PDFViewer[-99..-7] ) -join ' ' ) -replace ' ',''
    $string2 = (( $PDFViewer[-6..-1] ) -join ' ' ) -replace ' ',''

    Write-Host "[$(timeStamp)] Detecting GPU for driver selection.." -ForegroundColor Gray
        $getGPU = Get-CimInstance win32_VideoController | Select-Object -ExpandProperty Caption
            If ( $getGPU -like "*AMD Radeon*" ) { 
                $updateGPU = "amd-ryzen-chipset"
                $manuGPU = "AMD drivers"
                    Write-Host "[$(timeStamp)] GPU detected: AMD Radeon — will install [$manuGPU]" -ForegroundColor Cyan
            } ElseIf ( $getGPU -like "*NVIDIA GeForce*" ) {
                $updateGPU = "nvidia-display-driver geforce-experience"
                $manuGPU = "NVIDIA drivers"     
                    Write-Host "[$(timeStamp)] GPU detected: NVIDIA GeForce — will install [$manuGPU]" -ForegroundColor Cyan
            } Else {
                $updateGPU = ""
                $manuGPU = ""
                    Write-Host "[$(timeStamp)] No recognized GPU detected. Skipping GPU driver install." -ForegroundColor Yellow
            }

    Write-Host "[$(timeStamp)] Installing / upgrading software via Chocolatey.." -ForegroundColor Cyan
        $chocoArgs = "-NoProfile -ExecutionPolicy Bypass -Command `"choco upgrade 7zip googlechrome javaruntime microsoft-edge $PDFViewer $updateGPU -y --limit-output`""
        Start-Process powershell.exe -ArgumentList $chocoArgs -Wait

            1..10 | ForEach-Object {
                If ( Test-Path "$env:PROGRAMFILES\Google\Chrome\Application\chrome.exe" ) { } Else {
                    Start-Sleep -s 1
                        $LocalTempDir = $env:TEMP
                        $ChromeInstaller = "ChromeInstaller.exe"
                        (New-Object System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller")
                            & "$LocalTempDir\$ChromeInstaller" /silent /install
                        $Process2Monitor = "ChromeInstaller"
                            Do { 
                                $ProcessesFound = Get-Process | Where-Object { $Process2Monitor -contains $_.Name } | Select-Object -ExpandProperty Name
                                If ( $ProcessesFound ) { 
                                    Write-Host "[$(timeStamp)] Chrome installer still running..." -ForegroundColor Gray; Start-Sleep -Seconds 2 
                                } Else { 
                                    Remove-Item "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose 
                                } 
                            } Until ( !$ProcessesFound ) 
                }
            }       

    Write-Host "[$(timeStamp)] Packages attempted: 7Zip, Google Chrome, Java Runtime, $("$string1 $string2"), $manuGPU" -ForegroundColor Cyan
}

<# =================================================================================================================================
Function to install Drivers and Windows Updates     #>
Function DriverUpdates {
    $Session = New-Object -ComObject Microsoft.Update.Session           
    $Searcher = $Session.CreateUpdateSearcher() 

    $Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
    $Searcher.SearchScope =  1
    $Searcher.ServerSelection = 3

    $Criteria = "IsInstalled=0 and Type='Driver' and ISHidden=0"
        Write-Host "[$(timeStamp)] Searching for driver updates..." -ForegroundColor Gray
    $SearchResult = $Searcher.Search( $Criteria )          
    $Updates = $SearchResult.Updates

    $Updates | Select-Object Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | Format-List

    $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { $UpdatesToDownload.Add( $_ ) | Out-Null }
        Write-Host "[$(timeStamp)] Downloading drivers..." -ForegroundColor Gray
    $UpdateSession = New-Object -Com Microsoft.Update.Session
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    $Downloader.Download()

    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { 
        If ( $_.IsDownloaded ) { 
            $UpdatesToInstall.Add( $_ ) | Out-Null
        }
    }
    
        Write-Host "[$(timeStamp)] Installing drivers..." -ForegroundColor Cyan
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()
        If ( $InstallationResult.RebootRequired ) {
            Write-Host "[$(timeStamp)] Reboot required after driver installation." -ForegroundColor Yellow
        } Else { 
            Write-Host "[$(timeStamp)] Driver installation complete." -ForegroundColor Gray 
        }
} # End DriverUpdates Function

Function WindowUpdatesInstall {
    Write-Host "[$(timeStamp)] Checking for Windows Updates.." -ForegroundColor Cyan
        Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreRebootRequired -Verbose
        DriverUpdates

    Write-Host "[$(timeStamp)] Triggering update check via Settings GUI.." -ForegroundColor Gray
        Explorer.exe ms-settings:windowsupdate
            Start-Sleep -Seconds 5
        Explorer.exe ms-settings:windowsupdate-action
            Start-Sleep -Seconds 60
        Stop-Process -Name "SystemSettings"

    Write-Host "[$(timeStamp)] Windows Update check complete. Updates will continue in the background." -ForegroundColor Gray
}

<# =================================================================================================================================
Function to install old windows photo viewer     #>
Function WindowsPhotoViewer {
# modified from - https://github.com/farag2/Utilities/blob/master/Restore_Windows_Photo_Viewer.ps1  
    [CmdletBinding()]
        Param (
        [ValidateSet( 'Enable','Disable' )][String]$Restore = 'Enable'
    ) 

    If ( $Restore -eq 'Enable' ) {  
        Write-Host "[$(timeStamp)] Restoring Windows Photo Viewer.." -ForegroundColor Cyan

        If (!( Test-Path -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command )) {
            New-Item -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command -Force
        }
        If (!( Test-Path -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget )) {
            New-Item -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget -Force
        }

        New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open -Name MuiVerb -Type String -Value "@photoviewer.dll,-3043" -Force
        New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command -Name "(default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1" -Force
        New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget -Name Clsid -Type String -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}" -Force

        cmd.exe --% /c ftype Paint.Picture=%windir%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1
        cmd.exe --% /c ftype jpegfile=%windir%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1
        cmd.exe --% /c ftype pngfile=%windir%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1
        cmd.exe --% /c ftype TIFImage.Document=%windir%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1
        cmd.exe --% /c assoc .bmp=Paint.Picture
        cmd.exe --% /c assoc .jpg=jpegfile
        cmd.exe --% /c assoc .jpeg=jpegfile
        cmd.exe --% /c assoc .png=pngfile
        cmd.exe --% /c assoc .tif=TIFImage.Document
        cmd.exe --% /c assoc .tiff=TIFImage.Document
        cmd.exe --% /c assoc Paint.Picture\DefaultIcon=%SystemRoot%\System32\imageres.dll,-70
        cmd.exe --% /c assoc jpegfile\DefaultIcon=%SystemRoot%\System32\imageres.dll,-72
        cmd.exe --% /c assoc pngfile\DefaultIcon=%SystemRoot%\System32\imageres.dll,-71
        cmd.exe --% /c assoc TIFImage.Document\DefaultIcon=%SystemRoot%\System32\imageres.dll,-122

        Write-Host "[$(timeStamp)] Windows Photo Viewer restored." -ForegroundColor Gray
    }
} # End WindowsPhotoViewer Function

<# =================================================================================================================================
Function to disable fast startup     #>
Function DisableFastStartup {
    REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d "0" /f | Out-Null
    Write-Host "[$(timeStamp)] Fast Startup disabled." -ForegroundColor Gray
}

<# =================================================================================================================================
Function to import start menu     #>
Function ImportStartMenu {
    Write-Host "[$(timeStamp)] Importing Start Menu.." -ForegroundColor Cyan

    $Extract_ZipFile = ".\Backup.zip"
    $Extract_ZipOutput = ".\Backup\"
        Add-Type -AssemblyName System.IO.Compression.FileSystem  

    Function Unzip {  
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Extract_ZipFile, $Extract_ZipOutput)
    } # End Unzip Function

    Unzip "$Extract_ZipFile" "$Extract_ZipOutput"

    & ".\Restore.bat" 
    Remove-Item "C:\temp\Backup\" -Force

    # Get-AppxPackage -allusers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
    Write-Host "[$(timeStamp)] Start menu imported." -ForegroundColor Gray
} # End ImportStartMenu Function

Function UnpinStartMenu {
# Unpin all Start Menu tiles - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
# Note: This function has no counterpart. You have to pin the tiles back manually.
    [CmdletBinding()]
    Param (
        [ValidateSet( 'Hide','Show' )][String]$PinStartMenu = 'Show'
    ) 

    If ( $PinStartMenu -eq 'Hide' ) {
        Write-Host "[$(timeStamp)] Unpinning all Start Menu tiles..." -ForegroundColor Gray

        If ([System.Environment]::OSVersion.Version.Build -ge 15063 -And [System.Environment]::OSVersion.Version.Build -le 16299) {
            Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" -Include "*.group" -Recurse | ForEach-Object {
                $data = ( Get-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data" ).Data -Join ","
                $data = $data.Substring( 0, $data.IndexOf( ",0,202,30" ) + 9 ) + ",0,202,80,0,0"
                Set-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data" -Type Binary -Value $data.Split( "," )
            }
        } ElseIf ( [System.Environment]::OSVersion.Version.Build -ge 17134 ) {
            $key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*start.tilegrid`$windows.data.curatedtilecollection.tilecollection\Current"
            $data = $key.Data[0..25] + ( [byte[]](202,50,0,226,44,1,1,0,0) )
                Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $data
                Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
        }
    } Else { 
        Write-Host "[$(timeStamp)] Start menu tiles: no change requested." -ForegroundColor Gray
    }

} # End UnpinStartMenu Function

<# =================================================================================================================================
Function to prompt for a reboot     #>
Function RebootNow {
    $rebootNow = Read-Host "Your computer will need to be rebooted to apply all changes. Would you like to reboot now? [Y/N]: "

    If ( $rebootNow -eq "Y" ) {
        Write-Warning "[$(timeStamp)] Rebooting in a few seconds.. Thanks for using this script!"
        Start-Sleep -s 4
            CleanupForSites -enable $true
            cmd /c "shutdown /r /t 001"
    }
    If ( $rebootNow -eq "N" ) {
        Write-Warning "[$(timeStamp)] Please reboot manually at your convenience. Thanks for using this script!"
        Start-Sleep -s 3
            CleanupForSites -enable $true
    }
} # End RebootNow Function

<# =================================================================================================================================
 Get driver health state     #>
Function GetDriverHealth {
    $DeviceState = Get-CimInstance -Class Win32_PnpEntity -Namespace Root\CIMV2 | Where-Object { $_.ConfigManagerErrorCode -gt 0 }

    $script:DevicesInError = ForEach ( $Device In $DeviceState ) {      
        $Errortext = Switch ( $device.ConfigManagerErrorCode ) {
            0   {"This device is working properly."}
            1   {"This device is not configured correctly."}
            2   {"Windows cannot load the driver for this device."}
            3   {"The driver for this device might be corrupted, or your system may be running low on memory or other resources."}
            4   {"This device is not working properly. One of its drivers or your registry might be corrupted."}
            5   {"The driver for this device needs a resource that Windows cannot manage."}
            6   {"The boot configuration for this device conflicts with other devices."}
            7   {"Cannot filter."}
            8   {"The driver loader for the device is missing."}
            9   {"This device is not working properly because the controlling firmware is reporting the resources for the device incorrectly."}
            10  {"This device cannot start."}
            11  {"This device failed."}
            12  {"This device cannot find enough free resources that it can use."}
            13  {"Windows cannot verify this device's resources."}
            14  {"This device cannot work properly until you restart your computer."}
            15  {"This device is not working properly because there is probably a re-enumeration problem."}
            16  {"Windows cannot identify all the resources this device uses."}
            17  {"This device is asking for an unknown resource type."}
            18  {"Reinstall the drivers for this device."}
            19  {"Failure using the VxD loader."}
            20  {"Your registry might be corrupted."}
            21  {"System failure: Try changing the driver for this device. If that does not work, see your hardware documentation. Windows is removing this device."}
            22  {"This device is disabled."}
            23  {"System failure: Try changing the driver for this device. If that doesn't work, see your hardware documentation."}
            24  {"This device is not present, is not working properly, or does not have all its drivers installed."}
            25  {"Windows is still setting up this device."}
            26  {"Windows is still setting up this device."}
            27  {"This device does not have valid log configuration."}
            28  {"The drivers for this device are not installed."}
            29  {"This device is disabled because the firmware of the device did not give it the required resources."}
            30  {"This device is using an Interrupt Request (IRQ) resource that another device is using."}
            31  {"This device is not working properly because Windows cannot load the drivers required for this device."}
        } # End $Errortext switch

        [PSCustomObject] @{
            ErrorCode   = $device.ConfigManagerErrorCode
            ErrorText   = $Errortext
            Device      = $device.Caption
            Description = $device.Description
            Present     = $device.Present
            Status      = $device.Status
            StatusInfo  = $device.StatusInfo
        }

    } # End $DevicesInError ForEach 

} # End GetDriverHealth Function

<# =================================================================================================================================
 Install Missing Drivers     #>
Function InstallMissingDrivers {
    Write-Host "[$(timeStamp)] Checking for missing drivers and downloading available options." -ForegroundColor Gray

    $Session = New-Object -ComObject Microsoft.Update.Session           
    $Searcher = $Session.CreateUpdateSearcher() 
    $Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
    $Searcher.SearchScope =  1
    $Searcher.ServerSelection = 3

    $Criteria = "IsInstalled=0 and Type='Driver' and ISHidden=0"
        Write-Host "[$(timeStamp)] Searching for missing drivers..." -ForegroundColor Gray
    $SearchResult = $Searcher.Search( $Criteria )          
    $Updates = $SearchResult.Updates

    $Updates | Select-Object Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | Format-List

    $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { $UpdatesToDownload.Add( $_ ) | Out-Null }
        Write-Host "[$(timeStamp)] Downloading drivers..." -ForegroundColor Gray
    $UpdateSession = New-Object -Com Microsoft.Update.Session
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    $Downloader.Download()

    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { 
        If ( $_.IsDownloaded ) { 
            $UpdatesToInstall.Add( $_ ) | Out-Null
        } 
    }
        Write-Host "[$(timeStamp)] Installing drivers..." -ForegroundColor Cyan
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()
        If ( $InstallationResult.RebootRequired ) {  
            Write-Host "[$(timeStamp)] Reboot required after driver install." -ForegroundColor Red  
        } Else { 
            Write-Host "[$(timeStamp)] Driver install complete." -ForegroundColor Gray 
        }

    Write-Host "[$(timeStamp)] Done checking for drivers." -ForegroundColor Gray
} # End InstallMissingDrivers Function

<# =================================================================================================================================
 Address specific error codes     #>
Function ResolveIssues {
    Write-Host "[$(timeStamp)] Rescanning devices before running fixes.." -ForegroundColor Gray
        Start-Process -WindowStyle Hidden -Verb RunAs cmd '/c "echo rescan | diskpart & exit"'
        Start-Sleep -s 5
    Set-Content -Path "C:\temp\tempfile.tmp" -Value "" -Force

    If (( $script:DevicesInError ).ErrorCode -eq 22 ) { 
        Write-Host "[$(timeStamp)] Re-enabling disabled devices (error code 22).." -ForegroundColor Cyan
            Start-Sleep -s 1
            Get-PnpDevice | Where-Object { $_.Problem -eq 22 } | Enable-PnpDevice -Confirm:$false
    }

    If ( ($script:DevicesInError).ErrorCode -in @(2,3,4,8,18,21,23,24,28) ) { 
        Write-Host "[$(timeStamp)] Driver reinstall required for one or more devices.." -ForegroundColor Cyan
        Start-Sleep -s 2 
        InstallMissingDrivers
    }

    GetDriverHealth
} # End ResolveIssues Function

<# =================================================================================================================================
 Remove 'Meet Now'     #>
Function RemoveMeetNow {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1
    Write-Host "[$(timeStamp)] Meet Now disabled." -ForegroundColor Gray
} # End RemoveMeetNow Function

<# =================================================================================================================================
Function to select active hours for Windows Updates     #>
Function SetWindowsUpdateHours ( $startTime,$endTime ) {
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ActiveHoursStart" /t REG_DWORD /d "$startTime" /f | Out-Null
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ActiveHoursEnd" /t REG_DWORD /d "$endTime" /f | Out-Null
        Write-Host "[$(timeStamp)] Windows Update active hours: Start [$startTime:00] End [$endTime:00]" -ForegroundColor Gray
} # End SetWindowsUpdateHours

<# =================================================================================================================================
 Set auto arrange icons     #>
Function AutoArrange ( $enable ) {
    If ( $enable ) {
        Write-Host "[$(timeStamp)] Auto Arrange: [ON] — Align to grid: [ON]" -ForegroundColor Gray
            REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 1075839525 /F | Out-Null
            #REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 00000225 /F
    } ElseIf ( $enable -eq $false ) {
        Write-Host "[$(timeStamp)] Auto Arrange: [OFF] — Align to grid: [ON]" -ForegroundColor Gray
            REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 1075839524 /F | Out-Null
    } Else {
        Write-Host "[$(timeStamp)] AutoArrange: no option selected. Pass -enable `$true or `$false." -ForegroundColor Yellow
    }
} # End AutoArrange Function

Function CleanupForSites ( $enable ) {
    If ( $enable -eq $true ) {
        Function KillWindow {
            Get-Process | Where-Object { $_.MainWindowTitle } | Select-Object ProcessName, MainWindowTitle | 
                Where-Object { $_.ProcessName -eq "iexplore" } | Select-Object -Property MainWindowTitle -ExpandProperty MainWindowTitle > C:\temp\WindowTitle.txt

            $myWindowTitle = Get-Content "C:\temp\WindowTitle.txt" -Raw 
            taskkill /f /FI "WINDOWTITLE eq $myWindowTitle"
        } # End KillWindow Function

        Function clearCacheCookies {
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2
                Remove-Item -path "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\Temporary Internet Files\*.*" -Recurse -Force -EA SilentlyContinue | Out-Null
                Remove-Item -path "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\INetCache\*.*" -Recurse -Force -EA SilentlyContinue | Out-Null
        } # End clearCacheCookies Function

        KillWindow
        clearCacheCookies
    }
} # End CleanupForSites Function

# Removes News And Interests from the taskbar
Function NewsAndInterestsTaskbar {
    Param (
        [Parameter(Mandatory = $true,ParameterSetName = "Show")]
        [switch]$Show,
        [Parameter(Mandatory = $true,ParameterSetName = "Hide")]
        [switch]$Hide
    )

    Switch ( $PSCmdlet.ParameterSetName ) {
        "Show" {
            Write-Host "[$(timeStamp)] News and Interests: shown" -ForegroundColor Gray
                Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name "EnableFeeds" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Force -ErrorAction SilentlyContinue
        }
        "Hide" {
            Write-Host "[$(timeStamp)] News and Interests: hidden" -ForegroundColor Gray
                If (!( Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' )) { 
                    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows' -Name 'Windows Feeds' -Force | Out-Null
                }
                New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name "EnableFeeds" -PropertyType DWord -Value 0 -Force | Out-Null
        }
    } # End switch
} # End NewsAndInterestsTaskbar Function

# Runs functions to get and enable any PnP devices that are not showing up
Function PnPDevices {
    GetDriverHealth

    If ( !$script:DevicesInError ) {
        Write-Host "[$(timeStamp)] All devices are in a healthy state." -ForegroundColor Gray
    } Else {
        Write-Host "[$(timeStamp)] Device errors detected:" -ForegroundColor Yellow
        Write-Output $script:DevicesInError | Format-Table -AutoSize
        Get-PnpDevice | Where-Object { $_.Problem -eq 22 } | Enable-PnpDevice -Confirm:$false
            If (!( Test-Path -Path C:\temp\tempfile.tmp )) { ResolveIssues }
    }

    Start-Sleep -s 3
        If ( Test-Path -Path C:\temp\tempfile.tmp ) { 
            Write-Host "[$(timeStamp)] Removing resolution placeholder." -ForegroundColor Gray
            Remove-Item C:\temp\tempfile.tmp -Force 
        }
} # End PnPDevices Function

# Enable verbose startup/shutdown status messages
Function EnableVerboseStatus {
    [CmdletBinding()]
    Param (
      [ValidateSet( 'Enable','Disable' )][String]$VerboseLoginStatus = 'Enable'
    ) 

    If ( $VerboseLoginStatus -eq 'Enable' ) {
        Write-Host "[$(timeStamp)] Verbose login status: enabled" -ForegroundColor Gray
            If (( Get-CimInstance -Class "Win32_OperatingSystem" ).ProductType -eq 1 ) {
                Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
            } Else {
                Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
            }
    }

    If ( $VerboseLoginStatus -eq 'Disable' ) {
        Write-Host "[$(timeStamp)] Verbose login status: disabled" -ForegroundColor Gray
            If (( Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1 ) {
                Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
            } Else {
                Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 0
            }
    }

} # End EnableVerboseStatus Function

Function ShowShutdownOnLockScreen {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Show','Hide' )][String]$ShowShutdownOnLockScreen = 'Show'
    )

    If ( $ShowShutdownOnLockScreen -eq 'Show' ) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Type DWord -Value 1
            Write-Host "[$(timeStamp)] Shutdown on lock screen: shown" -ForegroundColor Gray
    }
    ElseIf ( $ShowShutdownOnLockScreen -eq 'Hide' ) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Type DWord -Value 0
            Write-Host "[$(timeStamp)] Shutdown on lock screen: hidden" -ForegroundColor Gray
    }

} # End ShowShutdownOnLockScreen

Function ShowNetworkOnScreen {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Show','Hide' )][String]$ShowNetworkOnScreen = 'Show'
    ) 
  
    If ( $ShowNetworkOnScreen -eq 'Show' ) {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DontDisplayNetworkSelectionUI" -ErrorAction SilentlyContinue
            Write-Host "[$(timeStamp)] Network on lock screen: shown" -ForegroundColor Gray
    }

    If ( $ShowNetworkOnScreen -eq 'Hide' ) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DontDisplayNetworkSelectionUI" -Type DWord -Value 1
            Write-Host "[$(timeStamp)] Network on lock screen: hidden" -ForegroundColor Gray
    }

} # End ShowNetworkOnScreen Function

Function EnableRestorePoints {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$RestorePoints = 'Enable'
    )

    If ( $RestorePoints -eq 'Enable' ) {
        Write-Host "[$(timeStamp)] Enabling System Restore on $env:SYSTEMDRIVE.." -ForegroundColor Cyan
            Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE"
            vssadmin Resize ShadowStorage /On=$env:SYSTEMDRIVE /For=$env:SYSTEMDRIVE /MaxSize=10GB
    }

    If ( $RestorePoints -eq 'Disable' ) {
        Write-Host "[$(timeStamp)] Disabling System Restore on $env:SYSTEMDRIVE.." -ForegroundColor Gray
            Disable-ComputerRestore -Drive "$env:SYSTEMDRIVE"
            vssadmin Delete Shadows /For=$env:SYSTEMDRIVE /Quiet
    }

} # End EnableRestorePoints Function

# Enable F8 legacy Boot menu
Function F8BootMenu {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$Toggle = 'Enable'
    ) 

    If ( $Toggle -eq 'Enable' ) {
        bcdedit /set `{current`} BootMenuPolicy Legacy | Out-Null
            Write-Host "[$(timeStamp)] F8 legacy boot menu: enabled" -ForegroundColor Gray
    }

    If ( $Toggle -eq 'Disable' ) {
        bcdedit /set `{current`} BootMenuPolicy Standard | Out-Null
            Write-Host "[$(timeStamp)] F8 legacy boot menu: disabled" -ForegroundColor Gray
    }

} # End F8BootMenu Function

Function AppSuggestionAndInstallation {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$Toggle = 'Disable'
    ) 

    If ( $Toggle -eq 'Disable' ) {
        Write-Host "[$(timeStamp)] App suggestions and auto-install: disabled" -ForegroundColor Gray
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-314559Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Type DWord -Value 0
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 0
                If (!( Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" )) {
                  New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Force | Out-Null
                }
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Type DWord -Value 0
                If (!( Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" )) {
                  New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Force | Out-Null
                }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Name "AllowSuggestedAppsInWindowsInkWorkspace" -Type DWord -Value 0
    
        If ( [System.Environment]::OSVersion.Version.Build -ge 17134 ) {
            $key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*windows.data.placeholdertilecollection\Current"
            Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $key.Data[0..15]
            Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
        }
    }

    If ( $Toggle -eq 'Enable' ) {
        Write-Host "[$(timeStamp)] App suggestions and auto-install: enabled" -ForegroundColor Gray
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353694Enabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353696Enabled" -Type DWord -Value 1
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 1
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-314559Enabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Name "AllowSuggestedAppsInWindowsInkWorkspace" -ErrorAction SilentlyContinue
    }

} # End AppSuggestionAndInstallation Function

<# =================================================================================================================================
Function to add OEM info if it does not exist     #>
Function AddOEMInfo {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$Toggle = 'Enable'
    ) 

    If ( $Toggle -eq 'Enable' ) {
        $regStrings = @{
            'Logo' = 'C:\Windows\System32\oemlogo.bmp'
            'Manufacturer' = 'Omnis Computers'
            'SupportPhone' = '(518) 372-7829'
            'SupportURL' = 'https://www.omniscomputers.com'
        }
      
        $regKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
        $regKeyAdd = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
        $value = (Get-ItemProperty $regKey)

        If ( $value.Logo -is [string] ) { 
            Write-Host "[$(timeStamp)] OEM Logo: already set [$($value.Logo)]" -ForegroundColor Gray
        } Else { 
            Write-Host "[$(timeStamp)] OEM Logo: missing — adding [$($regStrings.Logo)]" -ForegroundColor Cyan
            REG ADD $regKeyAdd /v 'Logo' /t REG_SZ /d $regStrings.Logo /f | Out-Null
                If (!( Test-Path $regStrings.Logo )) { 
                    Write-Host "[$(timeStamp)] OEM Logo file not found at [$($regStrings.Logo)]. Copying now." -ForegroundColor Yellow
                    Copy-Item -Path .\Dependencies\oemlogo.bmp -Destination $regStrings.Logo -Force 
                }     
        }

        If ( $value.Manufacturer -is [string] ) { 
            Write-Host "[$(timeStamp)] OEM Manufacturer: already set [$($value.Manufacturer)]" -ForegroundColor Gray
        } Else { 
            Write-Host "[$(timeStamp)] OEM Manufacturer: missing — adding [$($regStrings.Manufacturer)]" -ForegroundColor Cyan
            REG ADD $regKeyAdd /v 'Manufacturer' /t REG_SZ /d $regStrings.Manufacturer /f | Out-Null
        }    
        If ( $value.SupportPhone -is [string] ) { 
            Write-Host "[$(timeStamp)] OEM Support Phone: already set [$($value.SupportPhone)]" -ForegroundColor Gray
        } Else { 
            Write-Host "[$(timeStamp)] OEM Support Phone: missing — adding [$($regStrings.SupportPhone)]" -ForegroundColor Cyan
            REG ADD $regKeyAdd /v 'SupportPhone' /t REG_SZ /d $regStrings.SupportPhone /f | Out-Null
        }    
        If ( $value.SupportURL -is [string] ) { 
            Write-Host "[$(timeStamp)] OEM Support URL: already set [$($value.SupportURL)]" -ForegroundColor Gray
        } Else { 
            Write-Host "[$(timeStamp)] OEM Support URL: missing — adding [$($regStrings.SupportURL)]" -ForegroundColor Cyan
            REG ADD $regKeyAdd /v 'SupportURL' /t REG_SZ /d $regStrings.SupportURL /f | Out-Null
        }

        Write-Host "[$(timeStamp)] OEM information check complete." -ForegroundColor Gray

    } # End If Toggle Enabled

    If ( $Toggle -eq 'Disable' ) { Write-Host "[$(timeStamp)] OEM info check: skipped." -ForegroundColor Gray }

} # End AddOEMInfo Function

Function BlockAutoDownload {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Enable'    
    )

    If ( $Toggle -eq 'Enable' ) { 
        Write-Host "[$(timeStamp)] Auto-download of apps from Store: blocked" -ForegroundColor Gray
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 2 /f | Out-Null
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f | Out-Null
    }

    If ( $Toggle -eq 'Disable' ) { 
        Write-Host "[$(timeStamp)] Auto-download block: skipped" -ForegroundColor Gray
    }
}

Function UserExperienceReporting {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Disable'    
    )

    If ( $Toggle -eq 'Enable' ) { 
        Write-Host "[$(timeStamp)] User Experience Reporting (CEIP): enabled" -ForegroundColor Gray
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 1 /f | Out-Null
    }

    If ( $Toggle -eq 'Disable' ) { 
        Write-Host "[$(timeStamp)] User Experience Reporting (CEIP): disabled" -ForegroundColor Gray
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f | Out-Null
    }
}

Function LoginAnimation {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Disable'    
    )

    If ( $Toggle -eq 'Enable' ) { 
        Write-Host "[$(timeStamp)] First logon animation: enabled" -ForegroundColor Gray
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 1 /f | Out-Null
    }

    If ( $Toggle -eq 'Disable' ) { 
        Write-Host "[$(timeStamp)] First logon animation: disabled" -ForegroundColor Gray
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 0 /f | Out-Null
    }
}

Function RevertContextMenuW11 {
    Param(
        [ValidateSet('Enable','Disable')]
        $RestoreMenu
    )

    If ( $RestoreMenu -eq 'Enable' ) {
        Function BuildCheck {
            Param( $buildCheck )
            If ($buildCheck -ge 22000) { $winVer = "Win11" } Else { $winVer = "Win10orLower Version [$buildCheck]" }
                Return $winVer
        }

        $current_build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild).CurrentBuild
        $converted_build = BuildCheck $current_build

        $cmd = New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Value "" -Force
        $cmdExplorer = { taskkill /f /im explorer.exe ; Start-Process explorer.exe }

            Switch ($converted_build) {
                "Win11" { Write-Host "[$(timeStamp)] Win11 context menu reverted to classic. Build: [$current_build]" -ForegroundColor Cyan ; $cmd | Out-Null ; & $cmdExplorer }
                Default { Write-Host "[$(timeStamp)] Not Win11 [$converted_build] — context menu unchanged." -ForegroundColor Gray }
            }
    } Else {
        Write-Host "[$(timeStamp)] Context menu: no change requested." -ForegroundColor Gray
    }

}

Function Win11Widgets {
    Param(
        [ValidateSet('Enable','Disable')]
        $Status
    )

    If ( $Status -eq 'Disable' ) {
        Function BuildCheck {
            Param( $buildCheck )
            If ($buildCheck -ge 22000) { $winVer = "Win11" } Else { $winVer = "Win10orLower Version [$buildCheck]" }
                Return $winVer
        }

        $current_build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild).CurrentBuild
        $converted_build = BuildCheck $current_build

        Switch ($converted_build) {
            "Win11" { 
                Write-Host "[$(timeStamp)] Removing Win11 Widgets. Build: [$current_build]" -ForegroundColor Cyan
                winget uninstall "Windows Web Experience Pack" --silent
                taskkill /f /im explorer.exe
                Start-Process explorer.exe
            }
            Default { Write-Host "[$(timeStamp)] Not Win11 [$converted_build] — widgets unchanged." -ForegroundColor Gray }
        }
    } Else {
        Write-Host "[$(timeStamp)] Win11 widgets: no change requested." -ForegroundColor Gray
    }

}

<# =================================================================================================================================
   *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
               Modified Snippets from Sophia Script - https://github.com/farag2/Windows-10-Sophia-Script     
   *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
   =============================================================================================================================== #>
Function SophiaSnippets {
    Write-Host "[$(timeStamp)] Running Sophia snippets.." -ForegroundColor Cyan

    Function CreateTempTask {
        Write-Host "[$(timeStamp)] Scheduled task: Temp folder cleanup every 62 days" -ForegroundColor Gray
        
        $Argument = "Get-ChildItem -Path $env:TEMP -Force -Recurse | Remove-Item -Recurse -Force"
        $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument $Argument
        $Trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 62 -At 9am
        $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
        $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $Description = "Clean up temporary files in $env:TEMP every 62 days"
        $Parameters = @{
            "TaskName"    = "Temp"
            "TaskPath"    = "Temp Cleanup Script"
            "Principal"   = $Principal
            "Action"      = $Action
            "Description" = $Description
            "Settings"    = $Settings
            "Trigger"     = $Trigger
        }

        Register-ScheduledTask @Parameters -Force | Out-Null
    }

    Function CreateCleanUpTask {
        Write-Host "[$(timeStamp)] Scheduled task: Windows Cleanup every 90 days" -ForegroundColor Gray
        Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches | 
            ForEach-Object -Process {
                Remove-ItemProperty -Path $_.PsPath -Name StateFlags1337 -Force -ErrorAction Ignore
            }

        $VolumeCaches = @(
            "Delivery Optimization Files",
            "Device Driver Packages",
            "Previous Installations",
            "Setup Log Files",
            "Temporary Setup Files",
            "Windows Defender",
            "Windows Upgrade Log Files"
        )

        ForEach ( $VolumeCache in $VolumeCaches ) {
          New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$VolumeCache" -Name StateFlags1337 -PropertyType DWord -Value 2 -Force | Out-Null
        }

        $PS1Script = '
  $app = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\cleanmgr.exe"

  [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
  $Template = [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText01
  [xml]$ToastTemplate = ([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($Template).GetXml())

  [xml]$ToastTemplate = @"
  <toast launch="app-defined-string">
    <visual>
      <binding template="ToastGeneric">
        <text>Windows Cleanup is running...</text>
      </binding>
    </visual>
  </toast>
  "@

  $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
  $ToastXml.LoadXml($ToastTemplate.OuterXml)

  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show($ToastXml)

  Start-Sleep -Seconds 60

  $ProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
  $ProcessInfo.FileName = "$env:SystemRoot\system32\cleanmgr.exe"
  $ProcessInfo.Arguments = "/sagerun:1337"
  $ProcessInfo.UseShellExecute = $true
  $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized

  $Process = New-Object -TypeName System.Diagnostics.Process
  $Process.StartInfo = $ProcessInfo
  $Process.Start() | Out-Null

  Start-Sleep -Seconds 3
  $SourceMainWindowHandle = (Get-Process -Name cleanmgr).MainWindowHandle

  function MinimizeWindow {
    [CmdletBinding()]
    param ( [Parameter(Mandatory = $true)] $Process )
    $ShowWindowAsync = @{
      Namespace = "WinAPI"
      Name = "Win32ShowWindowAsync"
      Language = "CSharp"
      MemberDefinition = @"
  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@
    }
    if (-not ("WinAPI.Win32ShowWindowAsync" -as [type])) { Add-Type @ShowWindowAsync }
    $MainWindowHandle = (Get-Process -Name $Process).MainWindowHandle
    [WinAPI.Win32ShowWindowAsync]::ShowWindowAsync($MainWindowHandle, 2)
  }

  while ($true) {
    $CurrentMainWindowHandle = (Get-Process -Name cleanmgr).MainWindowHandle
    if ([int]$SourceMainWindowHandle -ne [int]$CurrentMainWindowHandle) {
      MinimizeWindow -Process cleanmgr
      break
    }
    Start-Sleep -Milliseconds 5
  }

  $ProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
  $ProcessInfo.FileName = "$env:SystemRoot\system32\dism.exe"
  $ProcessInfo.Arguments = "/Online /English /Cleanup-Image /StartComponentCleanup /NoRestart"
  $ProcessInfo.UseShellExecute = $true
  $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized

  $Process = New-Object -TypeName System.Diagnostics.Process
  $Process.StartInfo = $ProcessInfo
  $Process.Start() | Out-Null
  '
        $EncodedScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes( $PS1Script ))

        $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-WindowStyle Hidden -EncodedCommand $EncodedScript"
        $Trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 90 -At 9am
        $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
        $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
        $Description = "Run Windows Disk Cleanup and DISM component cleanup every 90 days"
        $Parameters = @{
            "TaskName"    = "Windows Cleanup"
            "TaskPath"    = "Sophia Script"
            "Principal"   = $Principal
            "Action"      = $Action
            "Description" = $Description
            "Settings"    = $Settings
            "Trigger"     = $Trigger
        }

        Register-ScheduledTask @Parameters -Force | Out-Null
    } # End CreateCleanUpTask Function

    Function CreateSoftwareDistributionTask {
        Write-Host "[$(timeStamp)] Scheduled task: SoftwareDistribution cleanup every 4 weeks" -ForegroundColor Gray

        $Argument = "
          (Get-Service -Name wuauserv).WaitForStatus('Stopped', '01:00:00')
          Get-ChildItem -Path $env:SystemRoot\SoftwareDistribution\Download -Recurse -Force | Remove-Item -Recurse -Force
        "
        $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument $Argument
        $Trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Thursday -At 9am
        $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
        $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $Description = "Clean up the SoftwareDistribution Download folder every 4 weeks"
        $Parameters = @{
            "TaskName"    = "SoftwareDistribution"
            "TaskPath"    = "Sophia Script"
            "Principal"   = $Principal
            "Action"      = $Action
            "Description" = $Description
            "Settings"    = $Settings
            "Trigger"     = $Trigger
        }

        Register-ScheduledTask @Parameters -Force | Out-Null
    } # End CreateSoftwareDistributionTask Function

    Function AppsSmartScreen {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
        [switch]$Disable,
        [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
        [switch]$Enable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Disable" {
                Write-Host "[$(timeStamp)] SmartScreen for apps: disabled" -ForegroundColor Gray
                New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name SmartScreenEnabled -PropertyType String -Value Off -Force | Out-Null
            }
            "Enable" {
                Write-Host "[$(timeStamp)] SmartScreen for apps: enabled" -ForegroundColor Gray
                New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name SmartScreenEnabled -PropertyType String -Value Warn -Force | Out-Null
            }
        } # End Switch
    } # End AppsSmartScreen Function

    Function AppSuggestions {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(Mandatory = $true, ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Hide" {
                Write-Host "[$(timeStamp)] App suggestions in Start: hidden" -ForegroundColor Gray
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338388Enabled -PropertyType DWord -Value 0 -Force | Out-Null
            }
            "Show" {
                Write-Host "[$(timeStamp)] App suggestions in Start: shown" -ForegroundColor Gray
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338388Enabled -PropertyType DWord -Value 1 -Force | Out-Null
            }
        } # End Switch
    } # End AppSuggestions Function

    Function NumLock {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Enable" {
                Write-Host "[$(timeStamp)] Num Lock at startup: enabled" -ForegroundColor Gray
                New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483650 -Force | Out-Null
            }
            "Disable" {
                Write-Host "[$(timeStamp)] Num Lock at startup: disabled" -ForegroundColor Gray
                New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483648 -Force | Out-Null
            }
        } # End Switch
    } # End NumLock Function

    Function FoldersLaunchSeparateProcess {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Enable" {
                Write-Host "[$(timeStamp)] Folders in separate process: enabled" -ForegroundColor Gray
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 1 -Force | Out-Null
            }
            "Disable" {
                Write-Host "[$(timeStamp)] Folders in separate process: disabled" -ForegroundColor Gray
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 0 -Force | Out-Null
            }
        } # End Switch
    } # End FoldersLaunchSeparateProcess

    Function PCTurnOffDevice {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
        [switch]$Disable,
        [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
        [switch]$Enable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Disable" {
                Write-Host "[$(timeStamp)] Network adapter power management: querying adapters.." -ForegroundColor Gray
                If (( Get-CimInstance -ClassName Win32_ComputerSystem).PCSystemType -ne 2 ) {
                    $adapterJob = Start-Job { Get-NetAdapter -Physical | Get-NetAdapterPowerManagement }
                    If ( $adapterJob | Wait-Job -Timeout 15 ) {
                        $Adapters = Receive-Job $adapterJob | Where-Object { $_.AllowComputerToTurnOffDevice -ne "Unsupported" }
                        ForEach ( $Adapter in $Adapters ) {
                            $Adapter.AllowComputerToTurnOffDevice = "Disabled"
                            $Adapter | Set-NetAdapterPowerManagement
                        }
                        Write-Host "[$(timeStamp)] Network adapter power management: disabled" -ForegroundColor Gray
                    } Else {
                        Write-Host "[$(timeStamp)] Network adapter query timed out. Skipping adapter power management." -ForegroundColor Yellow
                        Stop-Job $adapterJob
                    }
                    Remove-Job $adapterJob -Force
                }
            }
            "Enable" {
                Write-Host "[$(timeStamp)] Network adapter power management: querying adapters.." -ForegroundColor Gray
                If (( Get-CimInstance -ClassName Win32_ComputerSystem).PCSystemType -ne 2 ) {
                    $adapterJob = Start-Job { Get-NetAdapter -Physical | Get-NetAdapterPowerManagement }
                    If ( $adapterJob | Wait-Job -Timeout 15 ) {
                        $Adapters = Receive-Job $adapterJob | Where-Object { $_.AllowComputerToTurnOffDevice -ne "Unsupported" }
                        ForEach ( $Adapter in $Adapters ) {
                            $Adapter.AllowComputerToTurnOffDevice = "Enabled"
                            $Adapter | Set-NetAdapterPowerManagement
                        }
                        Write-Host "[$(timeStamp)] Network adapter power management: enabled" -ForegroundColor Gray
                    } Else {
                        Write-Host "[$(timeStamp)] Network adapter query timed out. Skipping adapter power management." -ForegroundColor Yellow
                        Stop-Job $adapterJob
                    }
                    Remove-Job $adapterJob -Force
                }
            }
        } # End Switch
    } # End PCTurnOffDevice Function

    Function WindowsManageDefaultPrinter {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Disable" {
                Write-Host "[$(timeStamp)] Windows default printer management: disabled" -ForegroundColor Gray
                New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 1 -Force | Out-Null
            }
            "Enable" {
                Write-Host "[$(timeStamp)] Windows default printer management: enabled" -ForegroundColor Gray
                New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 0 -Force | Out-Null
            }
        } # End Switch
    } # End WindowsManageDefaultPrinter Function

    Function ControlPanelView {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "LargeIcons")]
        [switch]$LargeIcons,
        [Parameter(Mandatory = $true, ParameterSetName = "Category")]
        [switch]$Category
        )

        Switch ($PSCmdlet.ParameterSetName) {
            "LargeIcons" {
                Write-Host "[$(timeStamp)] Control Panel view: Large Icons" -ForegroundColor Gray
                If (!( Test-Path -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel )) {
                    New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force | Out-Null
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force | Out-Null
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 1 -Force | Out-Null
            }
            "Category" {
              Write-Host "[$(timeStamp)] Control Panel view: Category" -ForegroundColor Gray
              If (!( Test-Path -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel )) {
                  New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force | Out-Null
              }
              New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force | Out-Null
              New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 0 -Force | Out-Null
            }
        } # End Switch
    } # End ControlPanelView Function

    Function WindowsInkWorkspace {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(Mandatory = $true, ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ($PSCmdlet.ParameterSetName) {
            "Hide" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace -Name PenWorkspaceButtonDesiredVisibility -PropertyType DWord -Value 0 -Force | Out-Null
                Write-Host "[$(timeStamp)] Windows Ink Workspace: hidden" -ForegroundColor Gray
            }
            "Show" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace -Name PenWorkspaceButtonDesiredVisibility -PropertyType DWord -Value 1 -Force | Out-Null
                Write-Host "[$(timeStamp)] Windows Ink Workspace: shown" -ForegroundColor Gray
            }
        } # End Switch
    } # End WindowsInkWorkspace Function

    Function PeopleTaskbar {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(Mandatory = $true, ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Hide" {
                Write-Host "[$(timeStamp)] People on taskbar: hidden" -ForegroundColor Gray
                If (!( Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People )) {
                    New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Force | Out-Null
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWord -Value 0 -Force | Out-Null
            }
            "Show" {
                Write-Host "[$(timeStamp)] People on taskbar: shown" -ForegroundColor Gray
                If (!( Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People )) {
                    New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Force | Out-Null
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWord -Value 1 -Force | Out-Null
            }
        } # End Switch
    } # End PeopleTaskbar Function

    Function TaskViewButton {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(Mandatory = $true, ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Hide" {
                Write-Host "[$(timeStamp)] Task View button: hidden" -ForegroundColor Gray
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 0 -Force | Out-Null
            }
            "Show" {
                Write-Host "[$(timeStamp)] Task View button: shown" -ForegroundColor Gray
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 1 -Force | Out-Null
            }
        } # End Switch
    } # End TaskViewButton Function

    Function OpenFileExplorerTo {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "ThisPC")]
        [switch]$ThisPC,
        [Parameter(Mandatory = $true, ParameterSetName = "QuickAccess")]
        [switch]$QuickAccess
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "ThisPC" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 1 -Force | Out-Null
                Write-Host "[$(timeStamp)] File Explorer opens to: This PC" -ForegroundColor Gray
            }
            "QuickAccess" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 2 -Force | Out-Null
                Write-Host "[$(timeStamp)] File Explorer opens to: Quick Access" -ForegroundColor Gray
            }
        } # End Switch
    } # End OpenFileExplorerTo Function

    Function ThisPC {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Show")]
        [switch]$Show,
        [Parameter(Mandatory = $true, ParameterSetName = "Hide")]
        [switch]$Hide
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Show" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -PropertyType DWord -Value 0 -Force | Out-Null
                Write-Host "[$(timeStamp)] This PC on desktop: shown" -ForegroundColor Gray
            }
            "Hide" {
                Remove-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Force -ErrorAction SilentlyContinue
                Write-Host "[$(timeStamp)] This PC on desktop: hidden" -ForegroundColor Gray
            }
        } # End Switch
    } # End ThisPC Function

    Function AppsSilentInstalling {
        Param (
        [Parameter(Mandatory = $true, ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(Mandatory = $true, ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Enable" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 1 -Force | Out-Null
                Write-Host "[$(timeStamp)] Silent app installation: enabled" -ForegroundColor Gray
            }
            "Disable" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 0 -Force | Out-Null
                Write-Host "[$(timeStamp)] Silent app installation: disabled" -ForegroundColor Gray
            }
        } # End Switch
    } # End AppsSilentInstalling Function

    # Call each of the Sophia functions
    AppsSilentInstalling -Disable
    AppsSmartScreen -Disable
    AppSuggestions -Hide
    ControlPanelView -LargeIcons
    CreateTempTask
    CreateCleanUpTask
    CreateSoftwareDistributionTask
    FoldersLaunchSeparateProcess -Enable
    NumLock -Enable
    OpenFileExplorerTo -ThisPC
    PCTurnOffDevice -Disable
    PeopleTaskbar -Hide
    TaskViewButton -Hide
    ThisPC -Show
    WindowsInkWorkspace -Hide
    WindowsManageDefaultPrinter -Disable

} # End SophiaSnippets Function

<# =================================================================================================================================
 Enable disabled devices and check for drivers to install     #>
Function EnableDevicesInstallDrivers {
    Write-Host "[$(timeStamp)] Checking for device errors and installing missing drivers.." -ForegroundColor Gray
    GetDriverHealth
    If ( $script:DevicesInError ) {
        Write-Host "[$(timeStamp)] Device errors found. Attempting to resolve.." -ForegroundColor Yellow
        $script:DevicesInError | Format-Table -AutoSize
        ResolveIssues
    } Else {
        Write-Host "[$(timeStamp)] All devices are healthy." -ForegroundColor Gray
    }
} # End EnableDevicesInstallDrivers Function

<# =================================================================================================================================
====================================================================================================================================
                                              ***    Main Script Code here!    ***
====================================================================================================================================
================================================================================================================================== #>

    PreRequisites
    PnPDevices

    Clear-Host

    myWeather
    
    EnableDevicesInstallDrivers

        AddOEMInfo -Toggle Enable
        AppSuggestionAndInstallation -Toggle Disable
        #AutoArrange -enable $false
        AutoArrange -enable $true
        BlockAutoDownload -Toggle Enable
        ChocoSoftware
        #CleanupForSites -enable $true
        DisableFastStartup
        DisableIPv6Components
        DisableShowSuggestions
        EnableRestorePoints -RestorePoints Enable
        EnableVerboseStatus -VerboseLoginStatus Enable
        F8BootMenu -Toggle Enable
        HighPerformance
        #ImportStartMenu
        CleanupForSites -enable $false
        LoginAnimation -Toggle Disable
        NewsAndInterestsTaskbar -Hide
        RemoveBloatware
        RemoveMeetNow
        RevertContextMenuW11 -RestoreMenu Enable
        setTimeZone -myTimeZone Eastern
        SetWindowsUpdateHours -startTime 20 -endTime 05
        ShowNetworkOnScreen -ShowNetworkOnScreen Show
        ShowShutdownOnLockScreen -ShowShutdownOnLockScreen Show
        UnpinStartMenu -PinStartMenu Show
        UserExperienceReporting -Toggle Disable
        WindowsPhotoViewer -Restore Enable
        Win11Widgets -Status Disable

        SophiaSnippets
        WindowUpdatesInstall
           
            Stop-Process -Name Explorer
        GetComputerName


<# =================================================================================================================================
Passes all the information of the operations made into the log file     #>

    Set-ItemProperty -Path $registryPath -Name "SystemRestorePointCreationFrequency" -Value 1440 -Force
        $regQuery = Get-ItemProperty $registryPath | findstr /i "SystemRestorePointCreationFrequency"
            Write-Host "[$(timeStamp)] SystemRestorePointCreationFrequency: should be 1440 (1 day) — Value: $regQuery" -ForegroundColor Gray

    Write-Host "[$(timeStamp)] Script finished. Log: $TARGETDIR" -BackgroundColor Red -ForegroundColor White

    $StopWatch.Stop()
        Write-Host "[$(timeStamp)] Time elapsed: $($StopWatch.Elapsed)" -ForegroundColor Gray
        Write-Host "[$(timeStamp)] Time elapsed in milliseconds: $($StopWatch.ElapsedMilliseconds)" -ForegroundColor Gray

        Stop-Transcript | ForEach-Object { "[$(timeStamp)] $_" }

Function CleanMemory {
    Get-Variable |
        Where-Object { 
            $startupVariables -notcontains $_.Name 
        } | ForEach-Object {
            Try { 
                Remove-Variable -Name "$($_.Name)" -Force -Scope "global" -ErrorAction Stop -WarningAction SilentlyContinue
            } Catch { }
        }
} # End CleanMemory Function
    CleanMemory
    #Invoke-Item $Log

Pop-Location -StackName Stack2
$ErrorActionPreference = 'Continue'

RebootNow