<#===============================================================================================================================
|This is a template for new scripts                                                                                              |
|  Update it as needed - it starts out checking for admin rights and with logging                                                |
=================================================================================================================================
|Version: 1.3.0.0                                                                                                                |
|By Aaron Horan                                                                                                                  |
|Created 04.14.2020                                                                                                              |
|Update 08.03.2021                                                                                                               |
================================================================================================================================#>

# Store all the start up variables so you can clean up when the script finishes.
if ($startupvariables) { try {Remove-Variable -Name startupvariables  -Scope Global -ErrorAction SilentlyContinue } catch { } }
New-Variable -force -name startupVariables -value ( Get-Variable | ForEach-Object { $_.Name } ) 

$myExe = 'New Computer Install.exe'

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "Administrator rights were not detected! Attempting to run as an administrator now.."
        If (Test-Path "${PSScriptRoot}\$myExe") { "I found you: ${PSScriptRoot}\$myExe" ; Start-Process `"${PSScriptRoot}\$myExe`" -Verb RunAs }
        If (Test-Path "$env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\$myExe") { "I found you: $env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\$myExe" ; Start-Process "$env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\$myExe" -Verb RunAs }
        If (!(Test-Path "${PSScriptRoot}\$myExe")) { Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs } 
        If (!(Test-Path "${PSScriptRoot}\$myExe")) { Start-Process "$env:TEMP\Quest Software\PowerGUI\*-*-*-*-*\$myExe" -Verb RunAs } 
    Exit}

$ErrorActionPreference = 'SilentlyContinue'

[console]::WindowWidth=135; [console]::WindowHeight=34; [console]::BufferWidth=[console]::WindowWidth

Function timeStamp{
  #(Get-Date -Format "MM/dd/yyyy HH:mm")
  return "{0:MM/dd/yy} {0:HH:mm:ss}" -f (Get-Date)
 }

    Write-Output "[$(timeStamp)] Running as Administrator!"
  Set-ExecutionPolicy RemoteSigned -force
Push-Location ${PSScriptRoot} -StackName Stack2

<# =================================================================================================================================
 Log Time + Script Variables     #>
    $scriptLogName = "New Computer Install"

    if ($scriptLogName -eq "MyScriptName"){Write-Warning "[$(timeStamp)] Please change the scriptLogName in the script and try again"; Start-Sleep -s 5 ; exit}
    $Date = Get-Date -Format "ddddMM-dd-yyyy_HH.mm.ss"
    $Log = "C:\Windows\Temp\$scriptLogName" + "-" + $Date + ".log"
    $TARGETDIR = "C:\Windows\Temp\$scriptLogName*.log"
    $NumberToKeep = 3
 
  $host.ui.RawUI.WindowTitle = “$scriptLogName by Aaron Horan”

<# =================================================================================================================================
 Remove Existing Log Files     #>
  if(Test-Path -Path $TARGETDIR ){
      Write-Host "[$(timeStamp)] Log file(s) $_ Found. Keeping the last $NumberToKeep and creating a new one for this session." -BackgroundColor Red -ForegroundColor White
      Get-ChildItem $TARGETDIR | Sort-Object Name -Desc | Select-Object -Skip $NumberToKeep | Remove-Item -Force
      Write-Host "[$(timeStamp)] Removed all but the last $NumberToKeep log files from $TARGETDIR" -BackgroundColor Red -ForegroundColor White
  }
 
<# =================================================================================================================================
Creates a log file for this process      #>
#$VerbosePreference = "Continue"
  Start-Transcript -Path $Log  -Force
     Write-Host "[$(timeStamp)] Creating a new log file in $TARGETDIR at Time: $(timeStamp)" -BackgroundColor Red -ForegroundColor White

<# =================================================================================================================================
Install Chocolatey, updates Powershell, and sets Time Zone as needed      #>
Function PreRequisites{
  $TARGETDIR = 'C:\ProgramData\Chocolatey\choco.exe'
  if(!(Test-Path -Path $TARGETDIR )){
      #Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) # old chocolatey download
      Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        If (Test-Path "${PSScriptRoot}$myExe") { & ".\${PSScriptRoot}$myExe"}
        If (!(Test-Path "${PSScriptRoot}$myExe")) {Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs} 
          exit
  }
    Write-Output "[$(timeStamp)] Chocolatey is (now?) installed. Continuing script."

# Check Powershell Version and Update if it is less than 5.0.00000.000
  $MyPowershell = $PSVersionTable.PSVersion
  if ($MyPowershell -lt "5.0.00000.000") {
    Write-Host "[$(timeStamp)] You are on version $MyPowershell. Attempting to upgrade now."
      cmd /c "choco install -y powershell --force"
        If (Test-Path "${PSScriptRoot}$myExe") { & ".\${PSScriptRoot}$myExe"}
        If (!(Test-Path "${PSScriptRoot}$myExe")) {Start-Process powershell.exe "-noProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs} 
      exit
  }
    Write-host "[$(timeStamp)] You are on version $MyPowershell which is greater than 5.0.00000.000 . Congrats!"

# Install Nuget
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force
#Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$false -Force -Verbose

# Install modules for this script
$instModules = "PSWindowsUpdate"
ForEach ($module in $instModules){
  if ($moduleInfo = Get-Module -ListAvailable -Name $module) {
    Write-Host "Module [$module ($($moduleInfo.Version))] is already installed." -ForegroundColor Green
      Try { Write-Host "  Updating to the latest version if needed [$module ($( (Find-Module "$module").Version | ForEach {$_ -join ' '} ))]" -ForegroundColor Gray ; Update-Module -Name $module} catch { $error = $_.Exception.Message ; Write-Warning "Error: [$($error)]" }
  } else {
    Write-Warning "Module [$module] is not installed. Installing now.."
    Install-Module $module -Confirm:$false -Force
  }
}


}

<# =================================================================================================================================
Function to Display the Weather      #>
Function myWeather {
  Write-Host ""
  $Weather = $(Invoke-WebRequest "http://wttr.in/$City" -UserAgent curl -UseBasicParsing).content -split "`n" ; $Weather[0..16]
  Write-Host ""
}

<# =================================================================================================================================
Function to Configure NTP Settings to go through time.nist.gov and set to EST time zone     #>
Function setTimeZone{
  $myTimeZone = "Eastern"
    [timezoneinfo]::ClearCachedData()
  $currentTimeZone = [timezoneinfo]::Local.id

    Write-Host "[$(timeStamp)] Checking the time zone and setting it if needed" -ForegroundColor Green -BackgroundColor Black
    Write-Host "[$(timeStamp)] Time Zone before running command at $Date is set to: $currentTimeZone" -ForegroundColor Green -BackgroundColor Black
      If (!((Get-TimeZone).id -eq "$myTimeZone Standard Time")){
        Write-Host "[$(timeStamp)] Setting Internet Time to go through time.nist.gov" -ForegroundColor Cyan -BackgroundColor Black
          w32tm /config /manualpeerlist:time.nist.gov,0x8 /syncfromflags:manual /reliable:yes /update | Out-Null
        Set-TimeZone -Id "$myTimeZone Standard Time"
    [timezoneinfo]::ClearCachedData()
        $currentTimeZone = [timezoneinfo]::Local.id
      }
      ElseIf ((Get-TimeZone).id -eq "$myTimeZone Standard Time"){ Write-Host "[$(timeStamp)] The Time Zone for PC $env:COMPUTERNAME is already set to $myTimeZone. Moving on." -ForegroundColor Cyan -BackgroundColor Black }
    Write-Host "[$(timeStamp)] Time Zone after running command at $Date is set to: $currentTimeZone" -ForegroundColor Green -BackgroundColor Black
}

<# =================================================================================================================================
Function to remove bloatware apps. Comment out specifics to keep them     #>
Function RemoveBloatware {
  Write-Host "[$(timeStamp)] Removing Bloatware! Who the f wants it anyway?!" -ForegroundColor Cyan   
#Bloatware Removal - add exclusions where needed |.*photos.*|.*OneNote.*| etc etc
# if it messes up this reinstalls all
# Get-AppxPackage –allusers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
# -----------------------------------------------------------------------------
# to get a specific app name --- Get-AppxPackage -name *lenovo*
# E046963F.LenovoSettingsforEnterprise # Commercial Vantage
# E046963F.LenovoCompanion # Lenovo Vantage
# DellInc.DellSupportAssistforPCs # dell support assist for pcs]
# HP Support Assistant # may not include an app - may be standalone exe
# -----------------------------------------------------------------------------
  $excludedApps = '.*photos.*|.*calculator.*|.*OneNote.*|.*Store.*|.*Camera.*|.*DellSupportAssist*.|.*LenovoSettingsforEnterprise*.|.*LenovoCompanion*.|.*HP Support Assistant*.'
  $unwantedApps = Get-AppxPackage -AllUsers -PackageTypeFilter Bundle | Where-Object {$_.Name -notmatch $excludedApps}
    If ($unwantedApps) {
      Write-Host "[$(timeStamp)] Attempting to remove unwanted applications now.." -ForegroundColor Gray
      $unwantedApps | Remove-AppxPackage -ErrorAction SilentlyContinue
    }
}

<# =================================================================================================================================
Function to get computer name and rename it     #>
Function GetComputerName {
  $NewPCName = Read-Host "Please type a new computer name: "
    if ($NewPCName.length -gt 15) {
      Clear-Variable NewPCName
      Write-Warning "[$(timeStamp)] Please keep the computer name to 15 characters or less."
      GetComputerName
    }
    if ($NewPCName.length -lt 1) {
      Write-Warning "[$(timeStamp)] Please enter a value and try again"
      GetComputerName
    }
  Rename-Computer -NewName "$NewPCName" -Force #-Restart
}

<# =================================================================================================================================
Function to disable the show suggestions in start button     #>
Function DisableShowSuggestions {
  REG ADD "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f
  Write-Host "[$(timeStamp)] ADs should be disabled in the start button now but will not take effect until a reboot"
}

<# =================================================================================================================================
Function to disable the IPv6 Components     #>
Function DisableIPv6Components{
  Cmd /C "reg add `"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters`" /v DisabledComponents /t REG_DWORD /d 0xFF /f"
  Write-Host "[$(timeStamp)] IPv6 Components have been disabled"
}

<# =================================================================================================================================
Function to set high performance mode     #>
Function HighPerformance{
  Write-Host "[$(timeStamp)] Attempting to set power settings to high performance." -ForegroundColor Cyan
    powercfg.exe -SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    $myPowerScheme = powercfg.exe -getactivescheme
  Write-Host "[$(timeStamp)] Current $myPowerScheme"
    Powercfg -Change -monitor-timeout-ac 60 # turn display off after 60 min battery plugged in
    Powercfg -Change -monitor-timeout-dc 30 # turn display off after 30 min battery
    Powercfg -Change -standby-timeout-ac 0 # sets sleep to never plugged in
    Powercfg -Change -standby-timeout-dc 0 # sets sleep to never
      Start-Sleep -s 3
}

<# =================================================================================================================================
Function to install basic software via chocolatey     #>

Function ChocoSoftware{
	[CmdletBinding()]
	param (
		[ValidateSet('Adobereader','Foxitreader')][String]$PDFViewer = 'Adobereader'
    ) 

  Write-Host "[$(timeStamp)] Installing / Upgrading basic software.." -ForegroundColor Cyan
    choco upgrade 7zip googlechrome javaruntime microsoft-edge $PDFViewer -y --limit-output
    #choco upgrade foxitreader -y --force # adobereader // foxitreader
  Write-Host "[$(timeStamp)] The following software packages have attempted to install: 7Zip, Google Chrome, Java Runtime, Foxit Reader"
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
Write-Host("[$(timeStamp)] Searching Driver-Updates...") -Fore Green  
$SearchResult = $Searcher.Search($Criteria)          
$Updates = $SearchResult.Updates

#Show available Drivers

$Updates | select Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | fl

#Download the Drivers from Microsoft

$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
$updates | % { $UpdatesToDownload.Add($_) | out-null }
Write-Host("[$(timeStamp)] Downloading Drivers...")  -Fore Green  
$UpdateSession = New-Object -Com Microsoft.Update.Session
$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToDownload
$Downloader.Download()

#Check if the Drivers are all downloaded and trigger the Installation

$UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
$updates | % { if($_.IsDownloaded) { $UpdatesToInstall.Add($_) | out-null } }

Write-Host("[$(timeStamp)] Installing Drivers...")  -Fore Green  
$Installer = $UpdateSession.CreateUpdateInstaller()
$Installer.Updates = $UpdatesToInstall
$InstallationResult = $Installer.Install()
if($InstallationResult.RebootRequired) {  
} else { Write-Host("[$(timeStamp)] Done..") -Fore Green }
}

Function WindowUpdatesInstall{
  Write-Host "[$(timeStamp)] Now checking for Windows Updates.." -ForegroundColor Cyan 
    Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreRebootRequired -Verbose
    DriverUpdates
  Write-Host "[$(timeStamp)] Finished checking for Windows Updates"
}

<# =================================================================================================================================
Function to install old windows photo viewer     #>
Function WindowsPhotoViewer{
  Write-Host "[$(timeStamp)] Now adding the old Windows Photo Viewer.." -ForegroundColor Cyan 
    regedit /s ".\Photo_Viewer.reg"
}

<# =================================================================================================================================
Function to install old windows photo viewer     #>
Function DisableFastStartup{
  Write-Host "[$(timeStamp)] Now disabling Fast Startup" -ForegroundColor Cyan 
    REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d "0" /f
}


<# =================================================================================================================================
Function to import start menu     #>
Function ImportStartMenu{
  Write-Host "[$(timeStamp)] Importing Start Menu.." -ForegroundColor Cyan 

$Extract_ZipFile = ".\Backup.zip"
$Extract_ZipOutput = ".\Backup\"
  Add-Type -AssemblyName System.IO.Compression.FileSystem  
    function Unzip
    {  

      [System.IO.Compression.ZipFile]::ExtractToDirectory($Extract_ZipFile, $Extract_ZipOutput)
    }
      Unzip "$Extract_ZipFile" "$Extract_ZipOutput"

        & ".\Restore.bat"
        Remove-Item "C:\temp\Backup\" -Force

# if it messes up this reinstalls all
# Get-AppxPackage –allusers | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
  Write-Host "[$(timeStamp)] Start menu has been imported"

}

Function UnpinStartMenu {
# Unpin all Start Menu tiles - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
# Note: This function has no counterpart. You have to pin the tiles back manually.
	[CmdletBinding()]
	param (
		[ValidateSet('Hide','Show')][String]$PinStartMenu = 'Show'
    ) 

  If ($PinStartMenu -eq 'Hide'){
	Write-Output "Unpinning all Start Menu tiles..."
	If ([System.Environment]::OSVersion.Version.Build -ge 15063 -And [System.Environment]::OSVersion.Version.Build -le 16299) {
		Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" -Include "*.group" -Recurse | ForEach-Object {
			$data = (Get-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data").Data -Join ","
			$data = $data.Substring(0, $data.IndexOf(",0,202,30") + 9) + ",0,202,80,0,0"
			Set-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data" -Type Binary -Value $data.Split(",")
		}
	} ElseIf ([System.Environment]::OSVersion.Version.Build -ge 17134) {
		$key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*start.tilegrid`$windows.data.curatedtilecollection.tilecollection\Current"
		$data = $key.Data[0..25] + ([byte[]](202,50,0,226,44,1,1,0,0))
		Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $data
		Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
	}
  } else { Write-Output "Skipping the option to hide start menu tiles. If this is a mistake please set the parameter to 'Hide'" }

}

<# =================================================================================================================================
Function to prompt for a reboot     #>
Function RebootNow{
  $rebootNow = Read-Host "Your computer will need to be rebooted to apply the changes made from this script.. Would you like to reboot now? [Y/N]: "
    If ($rebootNow -eq "Y"){
      Write-Warning "[$(timeStamp)] Your computer will automatically reboot in a few seconds.. Thanks for using this script!"
      Start-Sleep -s 4
      CleanupForSites -enable $true # clears IE stuff
        cmd /c "shutdown /r /t 001"
    }
    If ($rebootNow -eq "N"){
      Write-Warning "[$(timeStamp)] Please reboot the computer manually at your convenience. Thanks for using this script!"
      Start-Sleep -s 3
      CleanupForSites -enable $true # clears IE stuff
    }
}

<# =================================================================================================================================
 Enable disabled devices and check for drivers to install     #>
Function EnableDevicesInstallDrivers{
<# =================================================================================================================================
 Core function of script to get errors     #>
Function GetDriverHealth{
$DeviceState = Get-WmiObject -Class Win32_PnpEntity -ComputerName localhost -Namespace Root\CIMV2 | Where-Object {$_.ConfigManagerErrorCode -gt 0}

$DevicesInError = foreach($Device in $DeviceState){
 $Errortext = switch($device.ConfigManagerErrorCode){
        0  {"This device is working properly."}
        1  {"This device is not configured correctly."}
        2  {"Windows cannot load the driver for this device."}
        3  {"The driver for this device might be corrupted, or your system may be running low on memory or other resources."}
        4  {"This device is not working properly. One of its drivers or your registry might be corrupted."}
        5  {"The driver for this device needs a resource that Windows cannot manage."}
        6  {"The boot configuration for this device conflicts with other devices."}
        7  {"Cannot filter."}
        8  {"The driver loader for the device is missing."}
        9  {"This device is not working properly because the controlling firmware is reporting the resources for the device incorrectly."}
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
                }
    [PSCustomObject]@{
        ErrorCode = $device.ConfigManagerErrorCode
        ErrorText = $Errortext
        Device = $device.Caption
        Description = $device.Description
        Present = $device.Present
        Status = $device.Status
        StatusInfo = $device.StatusInfo
    }

} 

}

<# =================================================================================================================================
 Install Missing Drivers     #>
Function InstallMissingDrivers{
  Write-Host "[$(timeStamp)] Checking for missing drivers and downloading available options."
$ErrorActionPreference = "SilentlyContinue"

#search and list all missing Drivers
$Session = New-Object -ComObject Microsoft.Update.Session           
$Searcher = $Session.CreateUpdateSearcher() 

$Searcher.ServiceID = '7971f918-a847-4430-9279-4a52d1efe18d'
$Searcher.SearchScope =  1 # MachineOnly
$Searcher.ServerSelection = 3 # Third Party

$Criteria = "IsInstalled=0 and Type='Driver' and ISHidden=0"
Write-Host('Searching Driver-Updates...') -ForegroundColor Cyan  
$SearchResult = $Searcher.Search($Criteria)          
$Updates = $SearchResult.Updates

#Show available Drivers

$Updates | select Title, DriverModel, DriverVerDate, Driverclass, DriverManufacturer | fl

#Download the Drivers from Microsoft

$UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
$updates | ForEach { $UpdatesToDownload.Add($_) | out-null }
  Write-Host('Downloading Drivers...')  -ForegroundColor Cyan  
$UpdateSession = New-Object -Com Microsoft.Update.Session
$Downloader = $UpdateSession.CreateUpdateDownloader()
$Downloader.Updates = $UpdatesToDownload
$Downloader.Download()

#Check if the Drivers are all downloaded and trigger the Installation

$UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl
$updates | ForEach { if($_.IsDownloaded) { $UpdatesToInstall.Add($_) | out-null } }

  Write-Host('Installing Drivers...')  -ForegroundColor Cyan  
$Installer = $UpdateSession.CreateUpdateInstaller()
$Installer.Updates = $UpdatesToInstall
$InstallationResult = $Installer.Install()
if($InstallationResult.RebootRequired) {  
  Write-Host('Reboot required! please reboot now..') -ForegroundColor Red  
} else { Write-Host('Done..') -ForegroundColor Cyan }

$ErrorActionPreference = "Continue"
  Write-Host "[$(timeStamp)] Done checking for drivers."
}

<# =================================================================================================================================
 Address specific error codes     #>
Function ResolveIssues{
  Write-Host "[$(timeStamp)] Rescanning for devices before running fixes.." -ForegroundColor Cyan
    Start-Process -WindowStyle Hidden -Verb RunAs cmd '/c "echo rescan | diskpart & exit"'

    Start-Sleep -s 5

  Write-Host "" > C:\temp\tempfile.tmp

  If(($DevicesInError).ErrorCode -eq 22) { 
    Write-Host "[$(timeStamp)] Attempting to reenable disabled devices" -ForegroundColor Cyan 
    Start-Sleep -s 1
    Get-PnpDevice | Where-Object {$_.Problem -eq 22} | Enable-PnpDevice -Confirm:$false
    }

  If(($DevicesInError).ErrorCode -eq "2" -or "3" -or "4" -or "8" -or "18" -or "21" -or "23" -or "24" -or "28") { 
    Write-Host "[$(timeStamp)] Attempting to reinstall drivers" -ForegroundColor Cyan 
    Start-Sleep -s 2 
    $(InstallMissingDrivers)
    }

  GetDriverHealth
}

<# =================================================================================================================================
 Remove 'Meet Now' - 1 disable 0 enable     #>
 Function RemoveMeetNow{
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1
}

<# =================================================================================================================================
Function to select active hours for Windows Updates     #>
Function SetWindowsUpdateHours ($startTime,$endTime) {
 REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ActiveHoursStart" /t REG_DWORD /d "$startTime" /f
 REG ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ActiveHoursEnd" /t REG_DWORD /d "$endTime" /f
  #Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "ActiveHoursStart" -Value "$startTime" -Force
  #Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "ActiveHoursEnd" -Value "$endTime" -Force
  Write-Host "[$(timeStamp)] Active Hours for Windows Updates are now set to Start at [$startTime/24] and End at [$endTime/24]"
}

<# =================================================================================================================================
 Set auto arrange icons     #>
 Function AutoArrange ($enable) {
   if ($enable) {
      Write-Host "[$(timeStamp)] Setting Auto Arrange to [ON] and Align icons to grid to [ON]" -ForegroundColor Gray
      REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 1075839525 /F # auto arrange on
      #REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 00000225 /F # auto sort on
    } elseif ($enable -eq "$false") {
      Write-Host "[$(timeStamp)] Setting Auto Arrange to [OFF] and Align icons to grid to [ON]" -ForegroundColor Gray
      REG ADD "HKCU\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop" /V FFLAGS /T REG_DWORD /D 1075839524 /F
    } else {
      Write-Host "[$(timeStamp)] No option was selected. If this is a mistake please set -enable to either '$true' or '$false'" -ForegroundColor Gray
    }

}

Function CleanupForSites($enable){
  if ($enable -eq $true){
    Function KillWindow {
      Get-Process | Where {$_.MainWindowTitle} | Select-Object ProcessName, MainWindowTitle | Where-Object {$_.ProcessName -eq "iexplore"} | Select-Object -Property MainWindowTitle -ExpandProperty MainWindowTitle > C:\temp\WindowTitle.txt
      $myWindowTitle = Type "C:\temp\WindowTitle.txt" 
      taskkill /f /FI "WINDOWTITLE eq $myWindowTitle"
    }

    Function clearCacheCookies {
      RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 8 #TempIEFiles
      RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 2 #Cookies
      #if ($History) { RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 1} 
      #if ($FormData) { RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 16} 
      #if ($Passwords) { RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 32 } 
      #if ($All) { RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 255} 
      #if ($AddOnSettings) { RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 4351 }
      Remove-Item -path "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\Temporary Internet Files\*.*" -Recurse -Force -EA SilentlyContinue -Verbose | Out-Null
      Remove-Item -path "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Windows\INetCache\*.*" -Recurse -Force -EA SilentlyContinue -Verbose | Out-Null
    }

Function Clean-Memory {
      Get-Variable |
      Where-Object { $startupVariables -notcontains $_.Name } |
    ForEach-Object {
      try { Remove-Variable -Name "$($_.Name)" -Force -Scope "global" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
      catch { }
      try { Remove-Variable -Name "$($_.Name)" -Force -Scope "local" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
      catch { }
      try { Remove-Variable -Name "$($_.Name)" -Force -Scope "script" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
      catch { }
     }
    }

    KillWindow
    clearCacheCookies
    Clean-Memory
  }
}

# Removes News And Interests from the taskbar
Function NewsAndInterestsTaskbar {
	param (
		[Parameter(Mandatory = $true,ParameterSetName = "Show")]
		[switch]
		$Show,

		[Parameter(Mandatory = $true,ParameterSetName = "Hide")]
		[switch]
		$Hide
	)

	switch ($PSCmdlet.ParameterSetName)	{
      "Show" {
        Write-Host "[$(timeStamp)] Showing News and Interests in the taskbar" -ForegroundColor Cyan
		Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name "EnableFeeds" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Force -ErrorAction SilentlyContinue
      }
	  "Hide" {
        Write-Host "[$(timeStamp)] Hiding News and Interests in the taskbar" -ForegroundColor Cyan
        if (!(Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds')){ New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows' -Name 'Windows Feeds' -Force }
    	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' -Name "EnableFeeds" -PropertyType DWord -Value 0 -Force
	  }
	}
}

# Runs functions to get and enable any PnP devices that are not showing up
Function PnPDevices {
  $(GetDriverHealth)
    #if(!$DevicesInError){
    if($DevicesInError){
      Write-Host "[$(timeStamp)] Devices are currently in a Healthy state" -ForegroundColor Green
    } else {
      Write-Output $DevicesInError | ft -AutoSize

    # "Resolve Issues Function"
    Get-PnpDevice | Where-Object {$_.Problem -eq 22} | Enable-PnpDevice -Confirm:$false
      if(!(Test-Path -Path C:\temp\tempfile.tmp )){ $(ResolveIssues) }
    }

  # "Cleanup"
  Start-Sleep -s 3
    if(Test-Path -Path C:\temp\tempfile.tmp ){ 
      Write-Host "[$(timeStamp)] Found placeholder for resolution function. Removing now." -ForegroundColor Cyan
      Remove-Item C:\temp\tempfile.tmp -Force 
    }
}

# Enable verbose startup/shutdown status messages - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function EnableVerboseStatus {
	[CmdletBinding()]
	param (
		[ValidateSet('Enable','Disable')][String]$VerboseLoginStatus = 'Enable'
    ) 

# Enable Verbose Login Status Messages
  If ($VerboseLoginStatus -eq 'Enable'){
	Write-Output "Enabling verbose startup/shutdown status messages..."
	If ((Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1) {
		Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
	} Else {
		Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
	}
  }

# Disable Verbose Login status messages
  If ($VerboseLoginStatus -eq 'Disable'){
	Write-Output "Disabling verbose startup/shutdown status messages..."
	If ((Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1) {
		Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
	} Else {
		Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 0
	}
  }

}

# Show shutdown options on lock screen - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function ShowShutdownOnLockScreen {
	[CmdletBinding()]
	param (
		[ValidateSet('Show','Hide')][String]$ShowShutdownOnLockScreen = 'Show'
    ) 

  If ($ShowShutdownOnLockScreen -eq 'Show'){
	Write-Output "Showing shutdown options on Lock Screen..."
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Type DWord -Value 1
  }

  If ($ShowShutdownOnLockScreen -eq 'Show'){
	Write-Output "Hiding shutdown options from Lock Screen..."
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Type DWord -Value 0
  }

}

# Show network icon on lock screen - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function ShowNetworkOnScreen{
	[CmdletBinding()]
	param (
		[ValidateSet('Show','Hide')][String]$ShowNetworkOnScreen = 'Show'
    ) 
  
  If ($ShowNetworkOnScreen -eq 'Show'){
	Write-Output "Showing network options on Lock Screen..."
	Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DontDisplayNetworkSelectionUI" -ErrorAction SilentlyContinue
  }

  If ($ShowNetworkOnScreen -eq 'Hide'){
	Write-Output "Hiding network options from Lock Screen..."
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DontDisplayNetworkSelectionUI" -Type DWord -Value 1
  }

}

# Enable restore points and shadow storage - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function EnableRestorePoints{
	[CmdletBinding()]
	param (
		[ValidateSet('Enable','Disable')][String]$RestorePoints = 'Enable'
    ) 

  # Enable System Restore for system drive - Not applicable to Server
  If ($RestorePoints -eq 'Enable'){
	Write-Output "Enabling System Restore for system drive..."
	Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE"
      vssadmin Resize ShadowStorage /On=$env:SYSTEMDRIVE /For=$env:SYSTEMDRIVE /MaxSize=10GB
  }

  # Note: This does not delete already existing restore points as the deletion of restore points is irreversible. In order to do that, run also following command.
  If ($RestorePoints -eq 'Disable'){
	Write-Output "Disabling System Restore for system drive..."
	Disable-ComputerRestore -Drive "$env:SYSTEMDRIVE"
      vssadmin Delete Shadows /For=$env:SYSTEMDRIVE /Quiet
  }

}

# Enable F8 legacy Boot menu - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function F8BootMenu {
	[CmdletBinding()]
	param (
		[ValidateSet('Enable','Disable')][String]$Toggle = 'Enable'
    ) 

# Enable F8 boot menu options
  If ($Toggle -eq 'Enable'){
	Write-Output "Enabling F8 boot menu options..."
	bcdedit /set `{current`} BootMenuPolicy Legacy | Out-Null
  }

# Disable F8 boot menu options
  If ($Toggle -eq 'Disable'){
	Write-Output "Disabling F8 boot menu options..."
	bcdedit /set `{current`} BootMenuPolicy Standard | Out-Null
  }

}

# Enable or disable app suggestions and automatic installation - https://github.com/Disassembler0/Win10-Initial-Setup-Script/blob/master/Win10.psm1
Function AppSuggestionAndInstallation {
	[CmdletBinding()]
	param (
		[ValidateSet('Enable','Disable')][String]$Toggle = 'Disable'
    ) 

# Disable Application suggestions and automatic installation
  If ($Toggle -eq 'Disable'){
	Write-Output "Disabling Application suggestions..."
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
	If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement")) {
		New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Force | Out-Null
	}
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Type DWord -Value 0
	If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace")) {
		New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Force | Out-Null
	}
	Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Name "AllowSuggestedAppsInWindowsInkWorkspace" -Type DWord -Value 0
	# Empty placeholder tile collection in registry cache and restart Start Menu process to reload the cache
	If ([System.Environment]::OSVersion.Version.Build -ge 17134) {
		$key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*windows.data.placeholdertilecollection\Current"
		Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $key.Data[0..15]
		Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
	}
  }

# Enable Application suggestions and automatic installation
  If ($Toggle -eq 'Enable'){
	Write-Output "Enabling Application suggestions..."
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

}

<# =================================================================================================================================
   =================================================================================================================================
   =================================================================================================================================
   =================================================================================================================================
   =================================================================================================================================
   *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
               Snippets from Sophia Script - https://github.com/farag2/Windows-10-Sophia-Script     
   *~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
   =================================================================================================================================
   =================================================================================================================================
   =================================================================================================================================
   =================================================================================================================================
   =============================================================================================================================== #>
Function SophiaSnippets{
    Write-Host "[$(timeStamp)] Running Misc snippets of code now.." -ForegroundColor Cyan
# Scheduled task to clean up %temp% folder
function CreateTempTask
{
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
function CreateCleanUpTask
{
    Write-Host "[$(timeStamp)] Creating scheduled task to clean up leftover driver + installation files" -ForegroundColor Cyan
	Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches | ForEach-Object -Process {
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
	foreach ($VolumeCache in $VolumeCaches)
	{
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
	$EncodedScript = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($PS1Script))

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
}

# Software Distribution cleanup
function CreateSoftwareDistributionTask
{
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
}

# Disable smart screen through defender
function AppsSmartScreen
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Disable"
		{
          Write-Host "[$(timeStamp)] Disabling Windows Defender Smart Screen" -ForegroundColor Cyan
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name SmartScreenEnabled -PropertyType String -Value Off -Force
		}
		"Enable"
		{
          Write-Host "[$(timeStamp)] Enabling Windows Defender Smart Screen" -ForegroundColor Cyan
			New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name SmartScreenEnabled -PropertyType String -Value Warn -Force
		}
	}
}

# Turn off App Suggestions
function AppSuggestions
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Hide"
		)]
		[switch]
		$Hide,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Show"
		)]
		[switch]
		$Show
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Hide"
		{
          Write-Host "[$(timeStamp)] Hiding App Suggestions" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338388Enabled -PropertyType DWord -Value 0 -Force
		}
		"Show"
		{
          Write-Host "[$(timeStamp)] Showing App Suggestions" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338388Enabled -PropertyType DWord -Value 1 -Force
		}
	}
}

# Turn on Num Lock at startup
function NumLock
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
          Write-Host "[$(timeStamp)] Enabling Num Lock at startup from turning on by default" -ForegroundColor Cyan
			New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483650 -Force
		}
		"Disable"
		{
          Write-Host "[$(timeStamp)] Disabling Num Lock at startup from turning on by default" -ForegroundColor Cyan
			New-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" -Name InitialKeyboardIndicators -PropertyType String -Value 2147483648 -Force
		}
	}
}

# Launch explorer processes in a separate process
function FoldersLaunchSeparateProcess
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
          Write-Host "[$(timeStamp)] Enabling option to launch explorer process in a separate process" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 1 -Force
		}
		"Disable"
		{
          Write-Host "[$(timeStamp)] Disabling option to launch explorer process in a separate process" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name SeparateProcess -PropertyType DWord -Value 0 -Force
		}
	}
}

# Prevent windows from turning off network adapter to save power
function PCTurnOffDevice
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable
	)

	$Adapters = Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Where-Object -FilterScript {$_.AllowComputerToTurnOffDevice -ne "Unsupported"}

	switch ($PSCmdlet.ParameterSetName)
	{
		"Disable"
		{
          Write-Host "[$(timeStamp)] Disabling Windows from turning off network adapter to save power" -ForegroundColor Cyan
			if ((Get-CimInstance -ClassName Win32_ComputerSystem).PCSystemType -ne 2)
			{
				foreach ($Adapter in $Adapters)
				{
					$Adapter.AllowComputerToTurnOffDevice = "Disabled"
					$Adapter | Set-NetAdapterPowerManagement
				}
			}
		}
		"Enable"
		{
          Write-Host "[$(timeStamp)] Enabling Windows from turning off network adapter to save power" -ForegroundColor Cyan
			if ((Get-CimInstance -ClassName Win32_ComputerSystem).PCSystemType -ne 2)
			{
				foreach ($Adapter in $Adapters)
				{
					$Adapter.AllowComputerToTurnOffDevice = "Enabled"
					$Adapter | Set-NetAdapterPowerManagement
				}
			}
		}
	}
}

# Disable windows from managing default printers
function WindowsManageDefaultPrinter
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable
	)
	switch ($PSCmdlet.ParameterSetName)
	{
		"Disable"
		{
          Write-Host "[$(timeStamp)] Disabling Windows from managing default printers" -ForegroundColor Cyan
			New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 1 -Force
		}
		"Enable"
		{
          Write-Host "[$(timeStamp)] Enabling Windows to manage default printers" -ForegroundColor Cyan
			New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" -Name LegacyDefaultPrinterMode -PropertyType DWord -Value 0 -Force
		}
	}
}

# Set default control panel view
function ControlPanelView
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "LargeIcons"
		)]
		[switch]
		$LargeIcons,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Category"
		)]
		[switch]
		$Category
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"LargeIcons"
		{
          Write-Host "[$(timeStamp)] Setting default control panel icons to Large" -ForegroundColor Cyan
			if (-not (Test-Path -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel))
			{
				New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force
			}
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 1 -Force
		}
		"Category"
		{
          Write-Host "[$(timeStamp)] Setting default control panel icons to Category" -ForegroundColor Cyan
			if (-not (Test-Path -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel))
			{
				New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Force
			}
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 0 -Force
		}
	}
}

# Hide Windows Ink Workspace
function WindowsInkWorkspace
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Hide"
		)]
		[switch]
		$Hide,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Show"
		)]
		[switch]
		$Show
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Hide"
		{
          Write-Host "[$(timeStamp)] Hiding Windows Ink Workspace" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace -Name PenWorkspaceButtonDesiredVisibility -PropertyType DWord -Value 0 -Force
		}
		"Show"
		{
          Write-Host "[$(timeStamp)] Showing Windows Ink Workspace" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace -Name PenWorkspaceButtonDesiredVisibility -PropertyType DWord -Value 1 -Force
		}
	}
}

# Hide People Taskbar icon
function PeopleTaskbar
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Hide"
		)]
		[switch]
		$Hide,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Show"
		)]
		[switch]
		$Show
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Hide"
		{
          Write-Host "[$(timeStamp)] Hiding People on the taskbar" -ForegroundColor Cyan
			if (-not (Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People))
			{
				New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Force
			}
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWord -Value 0 -Force
		}
		"Show"
		{
          Write-Host "[$(timeStamp)] Showing People on the taskbar" -ForegroundColor Cyan
			if (-not (Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People))
			{
				New-Item -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Force
			}
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWord -Value 1 -Force
		}
	}
}

# Hide Task View on the taskbar
function TaskViewButton
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Hide"
		)]
		[switch]
		$Hide,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Show"
		)]
		[switch]
		$Show
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Hide"
		{
          Write-Host "[$(timeStamp)] Hiding Task View from the taskbar" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 0 -Force
		}
		"Show"
		{
          Write-Host "[$(timeStamp)] Showing Task View from the taskbar" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowTaskViewButton -PropertyType DWord -Value 1 -Force
		}
	}
}

# Open File Explorer to This PC
function OpenFileExplorerTo
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "ThisPC"
		)]
		[switch]
		$ThisPC,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "QuickAccess"
		)]
		[switch]
		$QuickAccess
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"ThisPC"
		{
          Write-Host "[$(timeStamp)] Setting File Explorer to open to This PC" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 1 -Force
		}
		"QuickAccess"
		{
          Write-Host "[$(timeStamp)] Setting File Explorer to open to Quick Access" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWord -Value 2 -Force
		}
	}
}

# Add This PC to the desktop
function ThisPC
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Show"
		)]
		[switch]
		$Show,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Hide"
		)]
		[switch]
		$Hide
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Show"
		{
          Write-Host "[$(timeStamp)] Showing This PC on the desktop" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -PropertyType DWord -Value 0 -Force
		}
		"Hide"
		{
          Write-Host "[$(timeStamp)] Hiding This PC on the desktop" -ForegroundColor Cyan
			Remove-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Force -ErrorAction SilentlyContinue
		}
	}
}

# Turn off silent installation of Suggested Apps
function AppsSilentInstalling
{
	param
	(
		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Enable"
		)]
		[switch]
		$Enable,

		[Parameter(
			Mandatory = $true,
			ParameterSetName = "Disable"
		)]
		[switch]
		$Disable
	)

	switch ($PSCmdlet.ParameterSetName)
	{
		"Enable"
		{
          Write-Host "[$(timeStamp)] Enabling silent installation of Suggested Apps" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 1 -Force
		}
		"Disable"
		{
          Write-Host "[$(timeStamp)] Disabling silent installation of Suggested Apps" -ForegroundColor Cyan
			New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SilentInstalledAppsEnabled -PropertyType DWord -Value 0 -Force
		}
	}
}

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
}

}

<# =================================================================================================================================
====================================================================================================================================
                                              ***    Main Script Code here!    ***
====================================================================================================================================
================================================================================================================================== #>

  PreRequisites # Install Chocolatey and upgrade powershell as needed
  PnPDevices # Runs functions to get and enable any PnP devices that are not showing up

  cls

  myWeather # Call function to display weather

    AppSuggestionAndInstallation -Toggle Disable # disable automatic app suggestions (OEM / subscribe) and installation
    #AutoArrange -enable $false # sets back to default auto arrange off and align on
    AutoArrange -enable $true # sets to auto arrange on and align on to fix the icons quick
    ChocoSoftware # Install basic software via chocolatey
    #CleanupForSites -enable $true # clears IE stuff
    DisableFastStartup # Disables fast startup
    DisableIPv6Components # Disable IPv6 components without conflicting with the system
    DisableShowSuggestions # Disable Show Suggestions in Start
    EnableDevicesInstallDrivers # Check for devices with errors and install drivers
    EnableRestorePoints -RestorePoints Enable # Enable restore points and set default 10 gb shadow copy storage
    EnableVerboseStatus -VerboseLoginStatus Enable # Enable or Disable verbose status messages
    F8BootMenu -Toggle Enable # enable legacy boot menu via F8
    HighPerformance # Set Power Settings to high performance
	#ImportStartMenu # Import Start Menu to clear bloatware from it
    LaunchSites -enable $false # launches websites and clears IE stuff again
    NewsAndInterestsTaskbar -Hide # Hide or Show the News and Interests Taskbar
    RemoveBloatware # Call Function to run remove bloatware minus exclusions
    RemoveMeetNow # Disable Meet Now
    setTimeZone # Call function to set time zone
    SetWindowsUpdateHours -startTime 20 -endTime 05
    ShowNetworkOnScreen -ShowNetworkOnScreen Show # Show network button on lock screen
    ShowShutdownOnLockScreen -ShowShutdownOnLockScreen Show # Show or hide shutdown buttons on lock screen
    UnpinStartMenu -PinStartMenu Show # Hide start menu tile icons
    WindowsPhotoViewer # Installs old Windows Photo Viewer
    WindowUpdatesInstall # Install Windows Update Module and install from Microsoft

    SophiaSnippets # Run misc tweaks from the Sophia script. See function for more info

      Stop-Process -Name Explorer # restart explorer to refresh some of the registry changes
    GetComputerName # Call function to rename computer

 
<# =================================================================================================================================
Passes all the information of the operations made into the log file     #>

Set-ItemProperty -Path $registryPath -Name "SystemRestorePointCreationFrequency" -Value 1440 -Force
  $regQuery = Get-ItemProperty $registryPath | findstr /i "SystemRestorePointCreationFrequency"
    Write-Host "[$(timeStamp)] This value should be set to 1440 (1 day)`
Value: $regQuery" -ForegroundColor Cyan

    Write-Host "[$(timeStamp)] Finished log file in $TARGETDIR at Time: $(timestamp)" -BackgroundColor Red -ForegroundColor White
  Stop-Transcript
#$VerbosePreference = "SilentlyContinue"
 
 Function Clean-Memory {
  Get-Variable |
    Where-Object { $startupVariables -notcontains $_.Name } |
    ForEach-Object {
      try { Remove-Variable -Name "$($_.Name)" -Force -Scope "global" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
      catch { }
    }
}
  Clean-Memory
    #Invoke-Item $Log
Pop-Location -StackName Stack2
$ErrorActionPreference = 'Continue'

RebootNow
