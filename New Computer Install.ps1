<#===============================================================================================================================
|Version: 1.4.6                                                                                                                |
|By Aaron Horan                                                                                                                  |
|Created 04.14.2020                                                                                                              |
|Update 03.07.2023                                                                                                               |
================================================================================================================================#>

# Store all the start up variables so you can clean up when the script finishes.
If ( $startupvariables ) { 
    Try { Remove-Variable -Name startupvariables -Scope Global -ErrorAction SilentlyContinue } Catch { } 
}
New-Variable -Force -Name startupVariables -Value ( Get-Variable | ForEach-Object { $_.Name } ) 

$myExe = 'New Computer Install'

Function Relaunch {
    If ( Test-Path "$env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\*$myExe.*" ) { 
        "I found you: $env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\*$myExe" 
        $runMe = Get-ChildItem "$env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\*\" | Where-Object { $_.BaseName -like "*$myExe*" } | Select-Object -ExpandProperty FullName 
            Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File $runMe" -Verb RunAs 
    } ElseIf (!( Test-Path "${PSScriptRoot}\$myExe.exe" )) { 
        Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
    } ElseIf (!( Test-Path "${PSScriptRoot}\$myExe.ps1" )) { 
        Write-Warning "Unable to locate file [$myExe]" 
        Break 
    } 
} # End Relaunch Function

If (!( [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent() ).IsInRole( [Security.Principal.WindowsBuiltInRole]"Administrator" )) {
    Write-Host "Administrator rights were not detected! Attempting to run as an administrator now.."
        Relaunch
        Exit
}

$ErrorActionPreference = 'SilentlyContinue' 

# Resize console window size
[console]::WindowWidth=135; [console]::WindowHeight=34; [console]::BufferWidth=[console]::WindowWidth

Function timeStamp {
    Return "{0:MM/dd/yy} {0:HH:mm:ss}" -f ( Get-Date )
} # End timeStamp Function

$StopWatch = New-Object System.Diagnostics.Stopwatch # create a stopwatch object and begin timer
    $StopWatch.Start()

    Write-Output "[$(timeStamp)] Running as Administrator!"
    Set-ExecutionPolicy RemoteSigned -force
Push-Location ${PSScriptRoot} -StackName Stack2 # Set working directory to script root path

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
  
    $host.ui.RawUI.WindowTitle = “$scriptLogName by Aaron Horan” # Set Window Title

<# =================================================================================================================================
 Remove Existing Log Files     #>
    If ( Test-Path -Path $TARGETDIR ) {
        Write-Host "[$(timeStamp)] Log file(s) $_ Found. Keeping the last $NumberToKeep and creating a new one for this session." -BackgroundColor Red -ForegroundColor White
            Get-ChildItem $TARGETDIR | Sort-Object Name -Desc | Select-Object -Skip $NumberToKeep | Remove-Item -Force
        Write-Host "[$(timeStamp)] Removed all but the last $NumberToKeep log files from $TARGETDIR" -BackgroundColor Red -ForegroundColor White
    }
 
<# =================================================================================================================================
Creates a log file for this process      #>
    Start-Transcript -Path $Log  -Force | ForEach-Object { "[$(timeStamp)] $_" }
        Write-Host "[$(timeStamp)] Creating a new log file in $TARGETDIR at Time: $(timeStamp)" -BackgroundColor Red -ForegroundColor White

<# =================================================================================================================================
Install Chocolatey, updates Powershell, and sets Time Zone as needed      #>
Function PreRequisites {
    [CmdletBinding(SupportsShouldProcess)]

    $TARGETDIR = 'C:\ProgramData\Chocolatey\choco.exe'
    If (!( Test-Path -Path $TARGETDIR )) {
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression (( New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1' ))
            Relaunch
            Exit
    }
    
Write-Output "[$(timeStamp)] Chocolatey is (now?) installed. Continuing script."

# Check Powershell Version and Update if it is less than 5.0.00000.000
$MyPowershell = $PSVersionTable.PSVersion
    If ( $MyPowershell -lt "5.0.00000.000" ) {
        Write-Host "[$(timeStamp)] You are on version $MyPowershell. Attempting to upgrade now."
            cmd /c "choco upgrade -y powershell --force" | ForEach-Object { "[$(timeStamp)] $_" }
                Relaunch
                Exit
    }
Write-host "[$(timeStamp)] You are on version $MyPowershell which is greater than 5.0.00000.000 . Congrats!"

# Install Nuget
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force 

# Install modules for this script
$instModules = "PSWindowsUpdate"
    ForEach ( $module in $instModules ) {
        If ( $moduleInfo = Get-Module -ListAvailable -Name $module ) {
            Write-Host "[$(timeStamp)] Module [$module ($($moduleInfo.Version))] is already installed." -ForegroundColor Cyan
                Try { 
                  Write-Host "[$(timeStamp)]   Updating to the latest version if needed [Latest Available: $module ($( (Find-Module "$module").Version | ForEach-Object {$_ -join ' '} ))]" -ForegroundColor Gray 
                  Update-Module -Name $module -ErrorAction Stop
                } Catch { 
                  $psError = $_.Exception.Message 
                  Write-Warning "[$(timeStamp)] Error: [$($psError)]" 
                }
        } Else {
            Write-Warning "[$(timeStamp)] Module [$module] is not installed. Installing now.."
            Install-Module $module -Confirm:$false -Force
        }
    } # End ForEach

} # End PreRequisites function

<# =================================================================================================================================
Function to Display the Weather      #>
Function myWeather {
    Write-Host ""
       $Weather = $( Invoke-WebRequest "http://wttr.in/$City" -UserAgent curl -UseBasicParsing ).content -split "`n" 
       $Weather[0..16]
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

        Write-Host "[$(timeStamp)] Checking the time zone and setting it if needed" -ForegroundColor Cyan -BackgroundColor Black
        Write-Host "[$(timeStamp)] Time Zone before running command at $Date is set to: $currentTimeZone" -ForegroundColor Cyan -BackgroundColor Black
            If (!( ( Get-TimeZone ).id -eq "$myTimeZone Standard Time" )) {
                Write-Host "[$(timeStamp)] Setting Internet Time to go through time.nist.gov" -ForegroundColor Cyan -BackgroundColor Black
                    w32tm /config /manualpeerlist:time.nist.gov,0x8 /syncfromflags:manual /reliable:yes /update | Out-Null
                    Set-TimeZone -Id "$myTimeZone Standard Time"
                    [timezoneinfo]::ClearCachedData()
                        $currentTimeZone = [timezoneinfo]::Local.id
            } ElseIf ( ( Get-TimeZone ).id -eq "$myTimeZone Standard Time" ) { 
                Write-Host "[$(timeStamp)] The Time Zone for PC $env:COMPUTERNAME is already set to $myTimeZone. Moving on." -ForegroundColor Cyan -BackgroundColor Black 
            }

    Write-Host "[$(timeStamp)] Time Zone after running command at $Date is set to: $currentTimeZone" -ForegroundColor Cyan -BackgroundColor Black
} # End setTimeZone Function

<# =================================================================================================================================
Function to remove bloatware apps. Comment out specifics to keep them     #>
Function RemoveBloatware {
<# Bloatware Removal - add exclusions where needed |.*photos.*|.*OneNote.*| etc etc
 if it messes up this reinstalls all : 
   Get-AppxPackage –allusers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
 -----------------------------------------------------------------------------
 to get a specific app name --- Get-AppxPackage -name *lenovo*
 E046963F.LenovoSettingsforEnterprise # Commercial Vantage
 E046963F.LenovoCompanion # Lenovo Vantage
 DellInc.DellSupportAssistforPCs # dell support assist for pcs]
 HP Support Assistant # may not include an app - may be standalone exe
 ----------------------------------------------------------------------------- #>
    Write-Host "[$(timeStamp)] Removing Bloatware! Who the f wants it anyway?!" -ForegroundColor Cyan  
        $excludedApps = '.*photos.*|.*calculator.*|.*OneNote.*|.*Store.*|.*Camera.*|.*Microsoft.WindowsNotepad*.|.*DellSupportAssist*.|.*LenovoSettingsforEnterprise*.|.*LenovoCompanion*.|.*HP Support Assistant*.|.*WindowsScan*.'
        $unwantedApps = Get-AppxPackage -AllUsers -PackageTypeFilter Bundle | Where-Object { $_.Name -notmatch $excludedApps }
        $unwantedProvApps = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -notmatch $excludedApps }
    
    If ( $unwantedApps ) {
        $ErrorActionPreference = 'SilentlyContinue'
            Write-Host "[$(timeStamp)] Attempting to remove unwanted applications now.." -ForegroundColor Gray
            $unwantedApps | Remove-AppxPackage
            ForEach ($provApp in $unwantedProvApps) { 
                Write-Host "[$(timeStamp)] Attempting to remove app [$provApp]" -ForegroundColor Gray
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
            }
            If ( $NewPCName.length -lt 1 ) {
                Write-Warning "[$(timeStamp)] Please enter a value and try again"
                  GetComputerName
            }
        Rename-Computer -NewName "$NewPCName" -Force #-Restart
    } ElseIf ( $env:COMPUTERNAME -like "DESKTOP*" -or $env:COMPUTERNAME -like "Win-*" ) {
        Return "[$(timeStamp)] Computer name is already set [$env:COMPUTERNAME] to something other than the default naming convention [DESKTOP-*]"	
    }
} # End GetComputerName Function

<# =================================================================================================================================
Function to disable the show suggestions in start button     #>
Function DisableShowSuggestions {
    REG ADD "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f
        Write-Host "[$(timeStamp)] Show suggestions should be disabled in the start button now but will not take effect until a reboot"
}

<# =================================================================================================================================
Function to disable the IPv6 Components     #>
Function DisableIPv6Components {
    REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v "DisabledComponents" /t REG_DWORD /d 0xFF /f
        Write-Host "[$(timeStamp)] IPv6 Components have been disabled"
}

<# =================================================================================================================================
Function to set high performance mode     #>
Function HighPerformance {
    Write-Host "[$(timeStamp)] Attempting to set power settings to high performance." -ForegroundColor Cyan
        Powercfg -SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        $myPowerScheme = Powercfg -getactivescheme
    Write-Host "[$(timeStamp)] Current $myPowerScheme"
        Powercfg -Change -monitor-timeout-ac 60 # turn display off after 60 min battery plugged in
        Powercfg -Change -monitor-timeout-dc 30 # turn display off after 30 min battery
        Powercfg -Change -standby-timeout-ac 0 # sets sleep to never plugged in
        Powercfg -Change -standby-timeout-dc 0 # sets sleep to never
            Start-Sleep -s 1
}

<# =================================================================================================================================
Function to install basic software via chocolatey     #>

Function ChocoSoftware {
    [CmdletBinding()]
    Param (
        [ValidateSet( 'Adobereader','Foxitreader' )][String]$PDFViewer = 'Adobereader'
    )

    # Split the strings up to dynamically display the reader chosen
    $string1 = (( $PDFViewer[-99..-7] ) -join ' ' ) -replace ' ',''
    $string2 = (( $PDFViewer[-6..-1] ) -join ' ' ) -replace ' ',''

    Write-Host "[$(timeStamp)] Detecting if a GPU exists and instaling software as needed.." -ForegroundColor Cyan
        $getGPU = Get-CimInstance win32_VideoController | Select-Object -ExpandProperty Caption
            If ( $getGPU -like "*AMD Radeon*" ) { 
                $updateGPU = "amd-ryzen-chipset"
                $manuGPU = "AMD drivers"
                    Write-Host "[$(timeStamp)] Installing [$manuGPU].." -ForegroundColor Cyan
            } ElseIf ( $getGPU -like "*NVIDIA GeForce*" ) {
                $updateGPU = "nvidia-display-driver geforce-experience"
                $manuGPU = "NVIDIA drivers"     
                    Write-Host "[$(timeStamp)] Installing [$manuGPU].." -ForegroundColor Cyan
            } Else {
                $updateGPU = ""
                $manuGPU = ""
                    Write-Host "[$(timeStamp)] GPU not detected! If you believe this is a mistake, please raise an issue on Github and be sure to list your GPU.." -ForegroundColor Cyan
            }

    Write-Host "[$(timeStamp)] Installing / Upgrading basic software.." -ForegroundColor Cyan
        Start-Process powershell.exe -ArgumentList "choco upgrade 7zip googlechrome javaruntime microsoft-edge $PDFViewer $updateGPU","-y","--limit-output" -Wait
        #choco upgrade 7zip googlechrome javaruntime microsoft-edge $PDFViewer -y --limit-output
            1..10 | ForEach-Object {
                If ( Test-Path "$env:PROGRAMFILES\Google\Chrome\Application\chrome.exe" ) { } Else {
                    #choco upgrade googlechrome -y --limit-output
                    start-sleep -s 1
                        $LocalTempDir = $env:TEMP
                        $ChromeInstaller = "ChromeInstaller.exe"
                        (New-Object    System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller")
                            & "$LocalTempDir\$ChromeInstaller" /silent /install
                        $Process2Monitor =  "ChromeInstaller"
                            Do { 
                                $ProcessesFound = Get-Process | Where-Object { $Process2Monitor -contains $_.Name } | Select-Object -ExpandProperty Name
                                If ( $ProcessesFound ) { 
                                    "Still running: $($ProcessesFound -join ', ')" | Write-Host; Start-Sleep -Seconds 2 
                                } Else { 
                                    Remove-Item "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose 
                                } 
                            } Until ( !$ProcessesFound ) 
                }
            }       

    Write-Host "[$(timeStamp)] The following software packages have attempted to install: 7Zip, Google Chrome, Java Runtime, $("$string1 $string2"), $manuGPU"
}

<# =================================================================================================================================
Function to install Drivers and Windows Updates     #>
Function DriverUpdates {
    #search and list all missing Drivers
    $Session = New-Object -ComObject Microsoft.Update.Session           
    $Searcher = $Session.CreateUpdateSearcher() 

    $Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
    $Searcher.SearchScope =  1 # MachineOnly
    $Searcher.ServerSelection = 3 # Third Party

    $Criteria = "IsInstalled=0 and Type='Driver' and ISHidden=0"
        Write-Host("[$(timeStamp)] Searching Driver-Updates...") -ForegroundColor Cyan  
    $SearchResult = $Searcher.Search( $Criteria )          
    $Updates = $SearchResult.Updates

    #Show available Drivers
    $Updates | Select-Object Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | Format-List

    #Download the Drivers from Microsoft
    $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { $UpdatesToDownload.Add( $_ ) | out-null }
        Write-Host("[$(timeStamp)] Downloading Drivers...") -ForegroundColor Cyan  
    $UpdateSession = New-Object -Com Microsoft.Update.Session
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    $Downloader.Download()

    #Check if the Drivers are all downloaded and trigger the Installation
    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
    $updates | ForEach-Object { 
        If ( $_.IsDownloaded ) { 
            $UpdatesToInstall.Add( $_ ) | out-null 
        }
    }
    
        Write-Host("[$(timeStamp)] Installing Drivers...") -ForegroundColor Cyan  
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()
        If ( $InstallationResult.RebootRequired ) {  
        } Else { 
            Write-Host("[$(timeStamp)] Done..") -ForegroundColor Cyan 
        }
} # End DriverUpdates Function

Function WindowUpdatesInstall {
    Write-Host "[$(timeStamp)] Now checking for Windows Updates.." -ForegroundColor Cyan 
        Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreRebootRequired -Verbose
        DriverUpdates

    # Run GUI options to ensure updates run via /u/user01401 - https://www.reddit.com/r/PowerShell/comments/p1jrt0/i_am_creating_a_powershell_script_that_will_check/
    Write-Host "[$(timeStamp)] Checking updates via the GUI - this should take about a minute before closing.."
        Explorer.exe ms-settings:windowsupdate # Open update window
            Start-Sleep -Seconds 5 # GUI option Necessary pause for slow GUI
        Explorer.exe ms-settings:windowsupdate-action # Check for updates
            Start-Sleep -Seconds 60 #Wait for update check
        Stop-Process -Name "SystemSettings" # Close update window

    Write-Host "[$(timeStamp)] Updates will continue in the background. Moving on.."    
    Write-Host "[$(timeStamp)] Finished checking for Windows Updates"
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
        Write-Host "[$(timeStamp)] Now adding the old Windows Photo Viewer.." -ForegroundColor Cyan

        # Add "Windows Photo Viewer" to Open with context menu
        If (!( Test-Path -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command )) {
            New-Item -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command -Force
        }
        If (!( Test-Path -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget )) {
            New-Item -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget -Force
        }

        New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open -Name MuiVerb -Type String -Value "@photoviewer.dll,-3043" -Force
        New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command -Name "(default)" -Type ExpandString -Value "%SystemRoot%\System32\rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1" -Force
        New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget -Name Clsid -Type String -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}" -Force

        # Associate BMP, JPEG, PNG, TIF to "Windows Photo Viewer"
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
    }
} # End WindowsPhotoViewer Function

<# =================================================================================================================================
Function to disable fast startup     #>
Function DisableFastStartup {
    Write-Host "[$(timeStamp)] Now disabling Fast Startup" -ForegroundColor Cyan 
        REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d "0" /f
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

    # If it messes up this reinstalls all
    # Get-AppxPackage –allusers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
    Write-Host "[$(timeStamp)] Start menu has been imported"
} # End ImportStartMenu Function

Function UnpinStartMenu {
# Unpin all Start Menu tiles - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
# Note: This function has no counterpart. You have to pin the tiles back manually.
    [CmdletBinding()]
    Param (
        [ValidateSet( 'Hide','Show' )][String]$PinStartMenu = 'Show'
    ) 

    If ( $PinStartMenu -eq 'Hide' ) {
        Write-Output "[$(timeStamp)] Unpinning all Start Menu tiles..."

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
        Write-Output "[$(timeStamp)] Skipping the option to hide start menu tiles. If this is a mistake please set the parameter to 'Hide'" 
    }

} # End UnpinStartMenu Function

<# =================================================================================================================================
Function to prompt for a reboot     #>
Function RebootNow {
    $rebootNow = Read-Host "Your computer will need to be rebooted to apply the changes made from this script.. Would you like to reboot now? [Y/N]: "

    If ( $rebootNow -eq "Y" ) {
        Write-Warning "[$(timeStamp)] Your computer will automatically reboot in a few seconds.. Thanks for using this script!"
        Start-Sleep -s 4
            CleanupForSites -enable $true # clears IE stuff
            cmd /c "shutdown /r /t 001"
    }
    If ( $rebootNow -eq "N" ) {
        Write-Warning "[$(timeStamp)] Please reboot the computer manually at your convenience. Thanks for using this script!"
        Start-Sleep -s 3
            CleanupForSites -enable $true # clears IE stuff
    }
} # End RebootNow Function

<# =================================================================================================================================
 Enable disabled devices and check for drivers to install     #>
Function EnableDevicesInstallDrivers {
# Core function of script to get errors
    Function GetDriverHealth {
        $DeviceState = Get-WmiObject -Class Win32_PnpEntity -ComputerName localhost -Namespace Root\CIMV2 | Where-Object {$_.ConfigManagerErrorCode -gt 0}

        #$DevicesInError = ForEach ( $Device In $DeviceState ) {
        ForEach ( $Device In $DeviceState ) {      
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
                ErrorCode = $device.ConfigManagerErrorCode
                ErrorText = $Errortext
                Device = $device.Caption
                Description = $device.Description
                Present = $device.Present
                Status = $device.Status
                StatusInfo = $device.StatusInfo
            }

        } # End $DevicesInError ForEach 

    } # End GetDriverHealth Function

<# =================================================================================================================================
 Install Missing Drivers     #>
Function InstallMissingDrivers {
    Write-Host "[$(timeStamp)] Checking for missing drivers and downloading available options."

    #search and list all missing Drivers
    $Session = New-Object -ComObject Microsoft.Update.Session           
    $Searcher = $Session.CreateUpdateSearcher() 
    $Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
    $Searcher.SearchScope =  1 # MachineOnly
    $Searcher.ServerSelection = 3 # Third Party

    $Criteria = "IsInstalled=0 and Type='Driver' and ISHidden=0"
        Write-Host "[$(timeStamp)] Searching Driver-Updates..." -ForegroundColor Cyan  
    $SearchResult = $Searcher.Search( $Criteria )          
    $Updates = $SearchResult.Updates

    #Show available Drivers
    $Updates | Select-Object Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | Format-List

    #Download the Drivers from Microsoft
    $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
    $updates | ForEach-Object { $UpdatesToDownload.Add( $_ ) | Out-Null }
        Write-Host "[$(timeStamp)] Downloading Drivers..." -ForegroundColor Cyan  
    $UpdateSession = New-Object -Com Microsoft.Update.Session
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    $Downloader.Download()

    #Check if the Drivers are all downloaded and trigger the Installation
    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
    $Updates | ForEach-Object { 
        If ( $_.IsDownloaded ) { 
            $UpdatesToInstall.Add( $_ ) | Out-Null
        } 
    }
        Write-Host "[$(timeStamp)] Installing Drivers..." -ForegroundColor Cyan  
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()
        If ( $InstallationResult.RebootRequired ) {  
            Write-Host "[$(timeStamp)] Reboot required! please reboot now.." -ForegroundColor Red  
        } Else { 
            Write-Host "[$(timeStamp)] Done.." -ForegroundColor Cyan 
        }

    Write-Host "[$(timeStamp)] Done checking for drivers."
} # End InstallMissingDrivers Function

<# =================================================================================================================================
 Address specific error codes     #>
Function ResolveIssues {
    Write-Host "[$(timeStamp)] Rescanning for devices before running fixes.." -ForegroundColor Cyan
        Start-Process -WindowStyle Hidden -Verb RunAs cmd '/c "echo rescan | diskpart & exit"'
        Start-Sleep -s 5
    Write-Host "" > C:\temp\tempfile.tmp

    If (( $DevicesInError ).ErrorCode -eq 22 ) { 
        Write-Host "[$(timeStamp)] Attempting to reenable disabled devices" -ForegroundColor Cyan 
            Start-Sleep -s 1
            Get-PnpDevice | Where-Object { $_.Problem -eq 22 } | Enable-PnpDevice -Confirm:$false
    }

    If (( $DevicesInError ).ErrorCode -eq "2" -or "3" -or "4" -or "8" -or "18" -or "21" -or "23" -or "24" -or "28" ) { 
        Write-Host "[$(timeStamp)] Attempting to reinstall drivers" -ForegroundColor Cyan 
        Start-Sleep -s 2 
            $(InstallMissingDrivers)
    }

    GetDriverHealth
} # End ResolveIssues Function

<# =================================================================================================================================
 Remove 'Meet Now' - 1 disable 0 enable     #>
Function RemoveMeetNow {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1
} # End RemoveMeetNow Function

<# =================================================================================================================================
Function to select active hours for Windows Updates     #>
Function SetWindowsUpdateHours ( $startTime,$endTime ) {
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ActiveHoursStart" /t REG_DWORD /d "$startTime" /f
    REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ActiveHoursEnd" /t REG_DWORD /d "$endTime" /f
        Write-Host "[$(timeStamp)] Active Hours for Windows Updates are now set to Start at [$startTime/24] and End at [$endTime/24]"
} # End SetWindowsUpdateHours

<# =================================================================================================================================
 Set auto arrange icons     #>
Function AutoArrange ( $enable ) {
    If ( $enable ) {
        Write-Host "[$(timeStamp)] Setting Auto Arrange to [ON] and Align icons to grid to [ON]" -ForegroundColor Gray
            REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 1075839525 /F # auto arrange on
            #REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 00000225 /F # auto sort on
    } ElseIf ( $enable -eq "$false" ) {
        Write-Host "[$(timeStamp)] Setting Auto Arrange to [OFF] and Align icons to grid to [ON]" -ForegroundColor Gray
            REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 1075839524 /F
    } Else {
        Write-Host "[$(timeStamp)] No option was selected. If this is a mistake please set -enable to either '$true' or '$false'" -ForegroundColor Gray
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
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 #TempIEFiles
            RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 #Cookies
                Remove-Item -path "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\Temporary Internet Files\*.*" -Recurse -Force -EA SilentlyContinue -Verbose | Out-Null
                Remove-Item -path "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\INetCache\*.*" -Recurse -Force -EA SilentlyContinue -Verbose | Out-Null
        } # End clearCacheCookies Function

        Function CleanMemory {
            Get-Variable | Where-Object { $startupVariables -notcontains $_.Name } |
                ForEach-Object { 
                    Try { 
                        Remove-Variable -Name "$($_.Name)" -Force -Scope "global" -ErrorAction Stop -WarningAction SilentlyContinue
                    } Catch { }
                    Try { 
                        Remove-Variable -Name "$($_.Name)" -Force -Scope "local" -ErrorAction Stop -WarningAction SilentlyContinue
                    } Catch { }
                    Try { 
                        Remove-Variable -Name "$($_.Name)" -Force -Scope "script" -ErrorAction Stop -WarningAction SilentlyContinue
                    } Catch { }
                }
        } # End CleanMemory Function
      
        KillWindow
        clearCacheCookies
        CleanMemory
    } # End CleanupForSites -eq $true
} # End CleanupForSites Function

# Removes News And Interests from the taskbar
Function NewsAndInterestsTaskbar {
    Param (
        [Parameter(Mandatory = $true,ParameterSetName = "Show")]
        [switch]
        $Show,
        [Parameter(Mandatory = $true,ParameterSetName = "Hide")]
        [switch]
        $Hide
    )

    Switch ( $PSCmdlet.ParameterSetName )	{
        "Show" {
            Write-Host "[$(timeStamp)] Showing News and Interests in the taskbar" -ForegroundColor Cyan
                Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name "EnableFeeds" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Force -ErrorAction SilentlyContinue
        }
        "Hide" {
            Write-Host "[$(timeStamp)] Hiding News and Interests in the taskbar" -ForegroundColor Cyan
                If (!( Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' )) { 
                    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows' -Name 'Windows Feeds' -Force 
                }
                New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name "EnableFeeds" -PropertyType DWord -Value 0 -Force
        }
    } # End switch
} # End NewsAndInterestsTaskbar Function

# Runs functions to get and enable any PnP devices that are not showing up
Function PnPDevices {
    $(GetDriverHealth)
        #If (!( $DevicesInError )) {
        If ( $DevicesInError ) {
           Write-Host "[$(timeStamp)] Devices are currently in a Healthy state" -ForegroundColor Cyan
        } Else {
            Write-Output $DevicesInError | Format-Table -AutoSize

            Get-PnpDevice | Where-Object { $_.Problem -eq 22 } | Enable-PnpDevice -Confirm:$false
                If (!( Test-Path -Path C:\temp\tempfile.tmp )) { $(ResolveIssues) }
        }

        # "Cleanup"
        Start-Sleep -s 3
            If ( Test-Path -Path C:\temp\tempfile.tmp ) { 
                Write-Host "[$(timeStamp)] Found placeholder for resolution function. Removing now." -ForegroundColor Cyan
                Remove-Item C:\temp\tempfile.tmp -Force 
            }
} # End PnPDevices Function

# Enable verbose startup/shutdown status messages - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function EnableVerboseStatus {
    [CmdletBinding()]
    Param (
      [ValidateSet( 'Enable','Disable' )][String]$VerboseLoginStatus = 'Enable'
    ) 

    # Enable Verbose Login Status Messages
    If ( $VerboseLoginStatus -eq 'Enable' ) {
        Write-Output "[$(timeStamp)] Enabling verbose startup/shutdown status messages..."
            If (( Get-CimInstance -Class "Win32_OperatingSystem" ).ProductType -eq 1 ) {
                Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
            } Else {
                Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
            }
    }

    # Disable Verbose Login status messages
    If ( $VerboseLoginStatus -eq 'Disable' ) {
        Write-Output "[$(timeStamp)] Disabling verbose startup/shutdown status messages..."
            If (( Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1 ) {
                Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
            } Else {
                Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 0
            }
    }

} # End EnableVerboseStatus Function

Function ShowShutdownOnLockScreen {
# Show shutdown options on lock screen - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Show','Hide' )][String]$ShowShutdownOnLockScreen = 'Show'
    )

    If ( $ShowShutdownOnLockScreen -eq 'Show' ) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Type DWord -Value 1
            Write-Output "[$(timeStamp)] Showing shutdown options on Lock Screen..."
    }

    If ( $ShowShutdownOnLockScreen -eq 'Show' ) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Type DWord -Value 0	  
            Write-Output "[$(timeStamp)] Hiding shutdown options from Lock Screen..."
    }

} # End ShowShutdownOnLockScreen

Function ShowNetworkOnScreen {
# Show network icon on lock screen - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Show','Hide' )][String]$ShowNetworkOnScreen = 'Show'
    ) 
  
    If ( $ShowNetworkOnScreen -eq 'Show' ) {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DontDisplayNetworkSelectionUI" -ErrorAction SilentlyContinue
            Write-Output "[$(timeStamp)] Showing network options on Lock Screen..."
    }

    If ( $ShowNetworkOnScreen -eq 'Hide' ) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DontDisplayNetworkSelectionUI" -Type DWord -Value 1
            Write-Output "[$(timeStamp)] Hiding network options from Lock Screen..."
    }

} # End ShowNetworkOnScreen Function

Function EnableRestorePoints {
# Enable restore points and shadow storage - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$RestorePoints = 'Enable'
    )

    # Enable System Restore for system drive - Not applicable to Server
    If ( $RestorePoints -eq 'Enable' ) {
        Write-Output "[$(timeStamp)] Enabling System Restore for system drive..."
            Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE"
            vssadmin Resize ShadowStorage /On=$env:SYSTEMDRIVE /For=$env:SYSTEMDRIVE /MaxSize=10GB
    }

    # Note: This does not delete already existing restore points as the deletion of restore points is irreversible. In order to do that, run also following command.
    If ( $RestorePoints -eq 'Disable' ) {
        Write-Output "[$(timeStamp)] Disabling System Restore for system drive..."
            Disable-ComputerRestore -Drive "$env:SYSTEMDRIVE"
            vssadmin Delete Shadows /For=$env:SYSTEMDRIVE /Quiet
    }

} # End EnableRestorePoints Function

# Enable F8 legacy Boot menu - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function F8BootMenu {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$Toggle = 'Enable'
    ) 

    # Enable F8 boot menu options
    If ( $Toggle -eq 'Enable' ) {
        bcdedit /set `{current`} BootMenuPolicy Legacy | Out-Null
            Write-Output "[$(timeStamp)] Enabling F8 boot menu options..."
    }

    # Disable F8 boot menu options
    If ( $Toggle -eq 'Disable' ) {
        bcdedit /set `{current`} BootMenuPolicy Standard | Out-Null
            Write-Output "[$(timeStamp)] Disabling F8 boot menu options..."
    }

} # End F8BootMenu Function

Function AppSuggestionAndInstallation {
# Enable or disable app suggestions and automatic installation - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$Toggle = 'Disable'
    ) 

  # Disable Application suggestions and automatic installation
    If ( $Toggle -eq 'Disable' ) {
        Write-Output "[$(timeStamp)] Disabling Application suggestions..."
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
    
        # Empty placeholder tile collection in registry cache and restart Start Menu process to reload the cache
        If ( [System.Environment]::OSVersion.Version.Build -ge 17134 ) {
            $key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*windows.data.placeholdertilecollection\Current"
            Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $key.Data[0..15]
            Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
        }
    }

    # Enable Application suggestions and automatic installation
    If ( $Toggle -eq 'Enable' ) {
        Write-Output "[$(timeStamp)] Enabling Application suggestions..."
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
            Write-Host "[$(timeStamp)] The Logo value exists already [$($value.Logo)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray
        } Else { 
            Write-Host "[$(timeStamp)] The Logo value is missing. Adding the following value [$($regStrings.Logo)]." -ForegroundColor Gray
            REG ADD $regKeyAdd /v 'Logo' /t REG_SZ /d $regStrings.Logo /f 
                If (!( Test-Path $regStrings.Logo )) { 
                    Write-Host "[$(timeStamp)] The Logo is missing from directory [$($regStrings.Logo)]. Attempting to copy it now." -ForegroundColor Gray
                    Copy-Item -Path .\Dependencies\oemlogo.bmp -Destination $regStrings.Logo -Force 
                }     
        }

        If ( $value.Manufacturer -is [string] ) { 
            Write-Host "[$(timeStamp)] The Manufacturer value exists already [$($value.Manufacturer)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray
        } Else { 
            Write-Host "[$(timeStamp)] The Manufacturer value is missing. Adding the following value [$($regStrings.Manufacturer)]." -ForegroundColor Gray
            REG ADD $regKeyAdd /v 'Manufacturer' /t REG_SZ /d $regStrings.Manufacturer /f 
        }    
        If ( $value.SupportPhone -is [string] ) { 
            Write-Host "[$(timeStamp)] The Support Phone value exists already [$($value.SupportPhone)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray 
        } Else { 
            Write-Host "[$(timeStamp)] The Support Phone value is missing. Adding the following value [$($regStrings.SupportPhone)]." -ForegroundColor Gray 
            REG ADD $regKeyAdd /v 'SupportPhone' /t REG_SZ /d $regStrings.SupportPhone /f 
        }    
        If ( $value.SupportURL -is [string] ) { 
            Write-Host "[$(timeStamp)] The Support URL value exists already [$($value.SupportURL)]. Please remove this if you would like to replace the existing value." -ForegroundColor Gray 
        } Else { 
            Write-Host "[$(timeStamp)] The Support URL value is missing. Adding the following value [$($regStrings.SupportURL)]." -ForegroundColor Gray 
            REG ADD $regKeyAdd /v 'SupportURL' /t REG_SZ /d $regStrings.SupportURL /f 
        }

        Write-Host "[$(timeStamp)] Any OEM Information that was missing has now been replaced with suggested values" -ForegroundColor DarkGray

    } # End If Toggle Enabled

    If ( $Toggle -eq 'Disable' ) { Write-Host "[$(timeStamp)] Skipping OEM Information check." -ForegroundColor Gray }

} # End AddOEMInfo Function

Function BlockAutoDownload {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Enable'    
    )

    If ( $Toggle -eq 'Enable' ) { 
        Write-Host "[$(timeStamp)] Enabling Automatic download of Apps" -ForegroundColor Gray 
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 2 /f
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f
    }

    If ( $Toggle -eq 'Disable' ) { 
        Write-Host "[$(timeStamp)] Skipping Blocking Automatic download of Apps" -ForegroundColor Gray 
    }
}

Function UserExperienceReporting {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Disable'    
    )

    If ( $Toggle -eq 'Enable' ) { 
        Write-Host "[$(timeStamp)] Enabling the User Experience Reporting" -ForegroundColor Gray 
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 1 /f
    }

    If ( $Toggle -eq 'Disable' ) { 
        Write-Host "[$(timeStamp)] Disabling the User Experience Reporting" -ForegroundColor Gray 
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f
    }
}

Function LoginAnimation {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Disable'    
    )

    If ( $Toggle -eq 'Enable' ) { 
        Write-Host "[$(timeStamp)] Enabling 'Hi! We're installing the apps...' animation" -ForegroundColor Gray 
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 1 /f
    }

    If ( $Toggle -eq 'Disable' ) { 
        Write-Host "[$(timeStamp)] Disabling 'Hi! We're installing the apps...' animation" -ForegroundColor Gray 
        Reg Add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableFirstLogonAnimation /t REG_DWORD /d 0 /f
    }
}

Function RevertContextMenuW11 {
    Param(
        [ValidateSet('Enable','Disable')]
        $RestoreMenu
    )

    If ( $RestoreMenu -eq 'Enable' ) {
        Function BuildCheck {
            Param(
            $buildCheck
            )
     
            If ($buildCheck -ge 22000) { $winVer = "Win11" } Else { $winVer = "Win10orLower Version [$buildCheck]" }
                return $winVer
            }

        $current_build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild).CurrentBuild
        $converted_build = BuildCheck $current_build

        # Enable old right click context menu in windows 11
        $cmd = New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Value "" -Force
        $cmdExplorer = taskkill /f /im explorer.exe ; Start-Process explorer.exe

            Switch ($converted_build) {
                "Win11" { Write-Host "[$(timeStamp)] Reverting to old context menu. Using build [$converted_build ($current_build)]" -ForegroundColor DarkGray ; $cmd | Out-Null ; $cmdExplorer }
                Default    { Write-Host "[$(timeStamp)] Not running Win11. Skipping" -ForegroundColor DarkGray }
            }
    } Else {
        Write-Host "[$(timeStamp)] Leaving context menu alone" -ForegroundColor DarkGray
    }

}

Function Win11Widgets {
    Param(
        [ValidateSet('Enable','Disable')]
        $Status
    )

    If ( $Status -eq 'Disable' ) {
        Function BuildCheck {
            Param(
            $buildCheck
            )
     
            If ($buildCheck -ge 22000) { $winVer = "Win11" } Else { $winVer = "Win10orLower Version [$buildCheck]" }
                return $winVer
            }

        $current_build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild).CurrentBuild
        $converted_build = BuildCheck $current_build

        # Enable old right click context menu in windows 11
        $cmd = winget uninstall "Windows Web Experience Pack" --silent
        $cmdExplorer = taskkill /f /im explorer.exe ; Start-Process explorer.exe

        Switch ($converted_build) {
            "Win11" { Write-Host "[$(timeStamp)] Removing Windows 11 widgets from taskbar. Using build [$converted_build ($current_build)]" -ForegroundColor DarkGray ; $cmd | Out-Null ; $cmdExplorer }
            Default    { Write-Host "[$(timeStamp)] Not running Win11. Skipping" -ForegroundColor DarkGray }
        }
    } Else {
        Write-Host "[$(timeStamp)] Leaving Windows 11 widgets in taskbar alone" -ForegroundColor DarkGray
    }

}

<# =================================================================================================================================
   *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
               Modified Snippets from Sophia Script - https://github.com/farag2/Windows-10-Sophia-Script     
   *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
   =============================================================================================================================== #>
Function SophiaSnippets {
    Write-Host "[$(timeStamp)] Running Misc snippets of code now.." -ForegroundColor Cyan

    # Scheduled task to clean up %temp% folder
    Function CreateTempTask {
        Write-Host "[$(timeStamp)] Creating scheduled task to clean temp files ($env:TEMP) automatically" -ForegroundColor Cyan
        
        $Argument = "Get-ChildItem -Path $env:TEMP -Force -Recurse | Remove-Item -Recurse -Force"
        $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument $Argument
        $Trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 62 -At 9am
        $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
        $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $Description = $Localization.TempTaskDescription
        $Parameters = @{
            "TaskName"		= "Temp"
            "TaskPath"		= "Temp Cleanup Script"
            "Principal"		= $Principal
            "Action"		= $Action
            "Description"	= $Description
            "Settings"		= $Settings
            "Trigger"		= $Trigger
        }

        Register-ScheduledTask @Parameters -Force
    }

    # Cleanup misc installation / driver files
    Function CreateCleanUpTask {
        Write-Host "[$(timeStamp)] Creating scheduled task to clean up leftover driver + installation files" -ForegroundColor Cyan
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
          New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$VolumeCache" -Name StateFlags1337 -PropertyType DWord -Value 2 -Force
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
        <text>$($Localization.CleanUpTaskToast)</text>
      </binding>
    </visual>
  </toast>
  "@

  $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
  $ToastXml.LoadXml($ToastTemplate.OuterXml)

  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show($ToastXml)

  Start-Sleep -Seconds 60

  # Process startup info
  # Параметры запуска процесса
  $ProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
  $ProcessInfo.FileName = "$env:SystemRoot\system32\cleanmgr.exe"
  $ProcessInfo.Arguments = "/sagerun:1337"
  $ProcessInfo.UseShellExecute = $true
  $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized

  # Process object using the startup info
  # Объект процесса, используя заданные параметры
  $Process = New-Object -TypeName System.Diagnostics.Process
  $Process.StartInfo = $ProcessInfo

  # Start the process
  # Запуск процесса
  $Process.Start() | Out-Null

  Start-Sleep -Seconds 3
  $SourceMainWindowHandle = (Get-Process -Name cleanmgr).MainWindowHandle

  function MinimizeWindow
  {
    [CmdletBinding()]
    param
    (
      [Parameter(Mandatory = $true)]
      $Process
    )

    $ShowWindowAsync = @{
    Namespace = "WinAPI"
    Name = "Win32ShowWindowAsync"
    Language = "CSharp"
    MemberDefinition = @"
  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  "@
    }
    if (-not ("WinAPI.Win32ShowWindowAsync" -as [type]))
    {
      Add-Type @ShowWindowAsync
    }

    $MainWindowHandle = (Get-Process -Name $Process).MainWindowHandle
    [WinAPI.Win32ShowWindowAsync]::ShowWindowAsync($MainWindowHandle, 2)
  }

  while ($true)
  {
    $CurrentMainWindowHandle = (Get-Process -Name cleanmgr).MainWindowHandle
    if ([int]$SourceMainWindowHandle -ne [int]$CurrentMainWindowHandle)
    {
      MinimizeWindow -Process cleanmgr
      break
    }
    Start-Sleep -Milliseconds 5
  }

  $ProcessInfo = New-Object -TypeName System.Diagnostics.ProcessStartInfo
  # Cleaning up unused updates
  # Очистка неиспользованных обновлений
  $ProcessInfo.FileName = "$env:SystemRoot\system32\dism.exe"
  $ProcessInfo.Arguments = "/Online /English /Cleanup-Image /StartComponentCleanup /NoRestart"
  $ProcessInfo.UseShellExecute = $true
  $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized

  # Process object using the startup info
  # Объект процесса, используя заданные параметры
  $Process = New-Object -TypeName System.Diagnostics.Process
  $Process.StartInfo = $ProcessInfo

  # Start the process
  # Запуск процесса
  $Process.Start() | Out-Null
  '
        # Encode $PS1Script variable to be able to pipeline it as an argument
        $EncodedScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes( $PS1Script ))

        $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-WindowStyle Hidden -EncodedCommand $EncodedScript"
        $Trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 90 -At 9am
        $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
        $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
        $Description = $Localization.CleanUpTaskDescription
        $Parameters = @{
            "TaskName"		= "Windows Cleanup"
            "TaskPath"		= "Sophia Script"
            "Principal"		= $Principal
            "Action"		= $Action
            "Description"	= $Description
            "Settings"		= $Settings
            "Trigger"		= $Trigger
        }

        Register-ScheduledTask @Parameters -Force
    } # End CreateCleanUpTask Function

    # Software Distribution cleanup
    Function CreateSoftwareDistributionTask {
        Write-Host "[$(timeStamp)] Creating scheduled task to cleanup Software Distribution folder" -ForegroundColor Cyan

        $Argument = "
          (Get-Service -Name wuauserv).WaitForStatus('Stopped', '01:00:00')
          Get-ChildItem -Path $env:SystemRoot\SoftwareDistribution\Download -Recurse -Force | Remove-Item -Recurse -Force
        "
        $Action = New-ScheduledTaskAction -Execute powershell.exe -Argument $Argument
        $Trigger = New-JobTrigger -Weekly -WeeksInterval 4 -DaysOfWeek Thursday -At 9am
        $Settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
        $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
        $Description = $Localization.SoftwareDistributionTaskDescription
        $Parameters = @{
            "TaskName"		= "SoftwareDistribution"
            "TaskPath"		= "Sophia Script"
            "Principal"		= $Principal
            "Action"		= $Action
            "Description"	= $Description
            "Settings"		= $Settings
            "Trigger"		= $Trigger
        }

        Register-ScheduledTask @Parameters -Force
    } # End CreateSoftwareDistributionTask Function

    # Disable smart screen through defender
    Function AppsSmartScreen {
        Param (
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Disable")]
        [switch]$Disable,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Enable")]
        [switch]$Enable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Disable" {
                Write-Host "[$(timeStamp)] Disabling Windows Defender Smart Screen" -ForegroundColor Cyan
                New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name SmartScreenEnabled -PropertyType String -Value Off -Force
            }
            "Enable" {
                Write-Host "[$(timeStamp)] Enabling Windows Defender Smart Screen" -ForegroundColor Cyan
                New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name SmartScreenEnabled -PropertyType String -Value Warn -Force
            }
        } # End Switch
    } # End AppsSmartScreen Function

    # Turn off App Suggestions
    Function AppSuggestions {
        Param	(
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Hide" {
                Write-Host "[$(timeStamp)] Hiding App Suggestions" -ForegroundColor Cyan
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338388Enabled -PropertyType DWord -Value 0 -Force
            }
            "Show" {
                Write-Host "[$(timeStamp)] Showing App Suggestions" -ForegroundColor Cyan
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338388Enabled -PropertyType DWord -Value 1 -Force
            }
        } # End Switch
    } # End AppSuggestions Function

    # Turn on Num Lock at startup
    Function NumLock {
        Param	(
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Enable" {
                Write-Host "[$(timeStamp)] Enabling Num Lock at startup from turning on by default" -ForegroundColor Cyan
                New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483650 -Force
            }
            "Disable" {
                Write-Host "[$(timeStamp)] Disabling Num Lock at startup from turning on by default" -ForegroundColor Cyan
                New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483648 -Force
            }
        } # End Switch
    } # End NumLock Function

    # Launch explorer processes in a separate process
    Function FoldersLaunchSeparateProcess {
        Param	(
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Enable" {
                Write-Host "[$(timeStamp)] Enabling option to launch explorer process in a separate process" -ForegroundColor Cyan
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 1 -Force
            }
            "Disable" {
                Write-Host "[$(timeStamp)] Disabling option to launch explorer process in a separate process" -ForegroundColor Cyan
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 0 -Force
            }
        } # End Switch
    } # End FoldersLaunchSeparateProcess

    # Prevent windows from turning off network adapter to save power
    Function PCTurnOffDevice {
        Param (
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Disable")]
        [switch]$Disable,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Enable")]
        [switch]$Enable
        )

        $Adapters = Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Where-Object -FilterScript {$_.AllowComputerToTurnOffDevice -ne "Unsupported"}

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Disable" {
              Write-Host "[$(timeStamp)] Disabling Windows from turning off network adapter to save power" -ForegroundColor Cyan

              If (( Get-CimInstance -ClassName Win32_ComputerSystem).PCSystemType -ne 2 )	{
                  ForEach ( $Adapter in $Adapters )	{
                      $Adapter.AllowComputerToTurnOffDevice = "Disabled"
                      $Adapter | Set-NetAdapterPowerManagement
                  }
              }
            }
            "Enable" {
                Write-Host "[$(timeStamp)] Enabling Windows from turning off network adapter to save power" -ForegroundColor Cyan

                If (( Get-CimInstance -ClassName Win32_ComputerSystem).PCSystemType -ne 2 )	{
                    ForEach ( $Adapter in $Adapters )	{
                        $Adapter.AllowComputerToTurnOffDevice = "Enabled"
                        $Adapter | Set-NetAdapterPowerManagement
                    }
                }
            }
        } # End Switch
    } # End PCTurnOffDevice Function

    # Disable windows from managing default printers
    Function WindowsManageDefaultPrinter {
        Param	(
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName )	{
            "Disable" {
                Write-Host "[$(timeStamp)] Disabling Windows from managing default printers" -ForegroundColor Cyan
                New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 1 -Force
            }
            "Enable" {
                Write-Host "[$(timeStamp)] Enabling Windows to manage default printers" -ForegroundColor Cyan
                New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 0 -Force
            }
        } # End Switch
    } # End WindowsManageDefaultPrinter Function

    # Set default control panel view
    Function ControlPanelView {
        Param (
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "LargeIcons")]
        [switch]$LargeIcons,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Category")]
        [switch]
        $Category
        )

        Switch ($PSCmdlet.ParameterSetName) {
            "LargeIcons" {
                Write-Host "[$(timeStamp)] Setting default control panel icons to Large" -ForegroundColor Cyan

                If (!( Test-Path -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel ))	{
                    New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 1 -Force
            }
            "Category" {
              Write-Host "[$(timeStamp)] Setting default control panel icons to Category" -ForegroundColor Cyan

              If (!( Test-Path -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel ))	{
                  New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force
              }
              New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force
              New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 0 -Force
            }
        } # End Switch
    } # End ControlPanelView Function

    # Hide Windows Ink Workspace
    Function WindowsInkWorkspace {
        Param	(
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ($PSCmdlet.ParameterSetName) {
            "Hide" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace -Name PenWorkspaceButtonDesiredVisibility -PropertyType DWord -Value 0 -Force		
                Write-Host "[$(timeStamp)] Hiding Windows Ink Workspace" -ForegroundColor Cyan
            }
            "Show" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace -Name PenWorkspaceButtonDesiredVisibility -PropertyType DWord -Value 1 -Force		
                Write-Host "[$(timeStamp)] Showing Windows Ink Workspace" -ForegroundColor Cyan
            }
        } # End Switch
    } # End WindowsInkWorkspace Function

    # Hide People Taskbar icon
    Function PeopleTaskbar {
        Param	(
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Hide" {
                Write-Host "[$(timeStamp)] Hiding People on the taskbar" -ForegroundColor Cyan
                If (!( Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People )) {
                    New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Force
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWord -Value 0 -Force
            }
            "Show" {
                Write-Host "[$(timeStamp)] Showing People on the taskbar" -ForegroundColor Cyan
                If (!( Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People )) {
                    New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Force
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWord -Value 1 -Force
            }
        } # End Switch
    } # End PeopleTaskbar Function

    # Hide Task View on the taskbar
    Function TaskViewButton {
        Param (
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Hide")]
        [switch]$Hide,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Show")]
        [switch]$Show
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Hide" {
                Write-Host "[$(timeStamp)] Hiding Task View from the taskbar" -ForegroundColor Cyan
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 0 -Force
            }
            "Show" {
                Write-Host "[$(timeStamp)] Showing Task View from the taskbar" -ForegroundColor Cyan
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 1 -Force
            }
        } # End Switch
    } # End TaskViewButton Function

    # Open File Explorer to This PC
    Function OpenFileExplorerTo {
        Param (
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "ThisPC")]
        [switch]$ThisPC,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "QuickAccess")]
        [switch]$QuickAccess
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "ThisPC" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 1 -Force
                Write-Host "[$(timeStamp)] Setting File Explorer to open to This PC" -ForegroundColor Cyan
            }
            "QuickAccess" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 2 -Force
                Write-Host "[$(timeStamp)] Setting File Explorer to open to Quick Access" -ForegroundColor Cyan
            }
        } # End Switch
    } # End OpenFileExplorerTo Function

    # Add This PC to the desktop
    Function ThisPC {
        Param (
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Show")]
        [switch]$Show,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Hide")]
        [switch]$Hide
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Show" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -PropertyType DWord -Value 0 -Force
                Write-Host "[$(timeStamp)] Showing This PC on the desktop" -ForegroundColor Cyan
            }
            "Hide" {
                Remove-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Force -ErrorAction SilentlyContinue
                Write-Host "[$(timeStamp)] Hiding This PC on the desktop" -ForegroundColor Cyan
            }
        } # End Switch
    } # End ThisPC Function

    # Turn off silent installation of Suggested Apps
    Function AppsSilentInstalling {
        Param (
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Enable")]
        [switch]$Enable,
        [Parameter(
        Mandatory = $true,
        ParameterSetName = "Disable")]
        [switch]$Disable
        )

        Switch ( $PSCmdlet.ParameterSetName ) {
            "Enable" {
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 1 -Force
                Write-Host "[$(timeStamp)] Enabling silent installation of Suggested Apps" -ForegroundColor Cyan
            }
            "Disable"{
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 0 -Force
                Write-Host "[$(timeStamp)] Disabling silent installation of Suggested Apps" -ForegroundColor Cyan
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

} # End EnableDevicesInstallDrivers Function

<# =================================================================================================================================
====================================================================================================================================
                                              ***    Main Script Code here!    ***
====================================================================================================================================
================================================================================================================================== #>

    PreRequisites # Install Chocolatey and upgrade powershell as needed
    PnPDevices # Runs functions to get and enable any PnP devices that are not showing up

    Clear-Host

    myWeather # Call function to display weather
    
    EnableDevicesInstallDrivers # Check for devices with errors and install drivers

        AddOEMInfo -Toggle Enable # Checks for OEM Information and enters Omnis info if it is missing
        AppSuggestionAndInstallation -Toggle Disable # disable automatic app suggestions (OEM / subscribe) and installation
        #AutoArrange -enable $false # sets back to default auto arrange off and align on
        AutoArrange -enable $true # sets to auto arrange on and align on to fix the icons quick
        BlockAutoDownload -Toggle Enable # Blocks apps from automatically downloading        
        ChocoSoftware # Install basic software via chocolatey
        #CleanupForSites -enable $true # clears IE stuff
        DisableFastStartup # Disables fast startup
        DisableIPv6Components # Disable IPv6 components without conflicting with the system
        DisableShowSuggestions # Disable Show Suggestions in Start
        EnableRestorePoints -RestorePoints Enable # Enable restore points and set default 10 gb shadow copy storage
        EnableVerboseStatus -VerboseLoginStatus Enable # Enable or Disable verbose status messages
        F8BootMenu -Toggle Enable # enable legacy boot menu via F8
        HighPerformance # Set Power Settings to high performance
        #ImportStartMenu # Import Start Menu to clear bloatware from it
        LaunchSites -enable $false # launches websites and clears IE stuff again
        LoginAnimation -Toggle Disable # Disable the 'Hi!' animation        
        NewsAndInterestsTaskbar -Hide # Hide or Show the News and Interests Taskbar
        RemoveBloatware # Call Function to run remove bloatware minus exclusions
        RemoveMeetNow # Disable Meet Now
        RevertContextMenuW11 -RestoreMenu Enable # restore Win10 context menu on Win11
        setTimeZone -myTimeZone Eastern # Call function to set time zone
        SetWindowsUpdateHours -startTime 20 -endTime 05
        ShowNetworkOnScreen -ShowNetworkOnScreen Show # Show network button on lock screen
        ShowShutdownOnLockScreen -ShowShutdownOnLockScreen Show # Show or hide shutdown buttons on lock screen
        UnpinStartMenu -PinStartMenu Show # Hide start menu tile icons
        UserExperienceReporting -Toggle Disable # Disables user experience reporting
        WindowsPhotoViewer -Restore Enable # Installs old Windows Photo Viewer
        Win11Widgets -Status Disable # Disables windows 11 widgets from the taskbar

        SophiaSnippets # Run misc tweaks from the Sophia script. See function for more info
        WindowUpdatesInstall # Install Windows Update Module and install from Microsoft --- ** Possibly Causes Restart **
           
            Stop-Process -Name Explorer # restart explorer to refresh some of the registry changes
        GetComputerName # Call function to rename computer

 
<# =================================================================================================================================
Passes all the information of the operations made into the log file     #>

    Set-ItemProperty -Path $registryPath -Name "SystemRestorePointCreationFrequency" -Value 1440 -Force
        $regQuery = Get-ItemProperty $registryPath | findstr /i "SystemRestorePointCreationFrequency"
            Write-Host "[$(timeStamp)] This value should be set to 1440 (1 day)`
    Value: $regQuery" -ForegroundColor Cyan

    Write-Host "[$(timeStamp)] Finished log file in $TARGETDIR at Time: $(timestamp)" -BackgroundColor Red -ForegroundColor White

    $StopWatch.Stop() # stop stopwatch timer
        Write-Host "[$(timeStamp)] Time elapsed: " $StopWatch.Elapsed
        Write-Host "[$(timeStamp)] Time elapsed in millisecondds: " $StopWatch.ElapsedMilliseconds

        Stop-Transcript | ForEach-Object { "[$(timeStamp)] $_" }
#$VerbosePreference = "SilentlyContinue"
 
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
