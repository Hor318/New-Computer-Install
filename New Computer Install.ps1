<#===============================================================================================================================
|Version: 2.0.1                                                                                                                |
|By Aaron Horan                                                                                                                  |
|Created 04.14.2020                                                                                                              |
|Update 11.19.2026                                                                                                               |
================================================================================================================================#>

#Requires -Version 5.0
[CmdletBinding()]
Param (
    [switch]$Gui,
    [string[]]$Actions,
    [ValidateSet('Full','Minimal','Custom')][string]$Preset = 'Full',
    [ValidateSet('Install','Uninstall')][string]$Prerequisites,
    [switch]$BackupOnly,
    [string]$RestoreBackup,
    [string]$SettingsFile,
    [string]$ComputerName,
    [ValidateSet('Dark','Light')][string]$Theme = 'Dark',
    [switch]$NoReboot,
    [switch]$PauseOnExit,
    [switch]$ListActions,
    [switch]$SelfTest,
    [string]$DriverSource
)

$script:AppName = "Aar318's New Computer Install"
$script:AppVersion = '2.0.1'
$script:KoFiUrl = 'https://ko-fi.com/M4M81VBQPJ'
$script:DonateUrl = 'https://streamelements.com/hor318/tip'
$script:BackupRoot = Join-Path $env:TEMP 'New Computer Install\Backups'
$script:RunOptionsRoot = Join-Path $env:TEMP 'New Computer Install\Run Options'
$script:WeatherCachePath = Join-Path $env:TEMP 'New Computer Install\Weather.txt'
$script:ApplicationRoot = If ($PSScriptRoot) { $PSScriptRoot } Else { [IO.Path]::GetDirectoryName([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$script:IconPath = Join-Path $script:ApplicationRoot 'Assets\New-Computer-Install.ico'

Function Get-OemDefaults {
    $current = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation' -ErrorAction SilentlyContinue
    [ordered]@{
        OEMManufacturer = If ($current.Manufacturer) { [string]$current.Manufacturer } Else { 'Omnis Computers' }
        OEMSupportPhone = If ($current.SupportPhone) { [string]$current.SupportPhone } Else { '(518) 372-7829' }
        OEMSupportURL = If ($current.SupportURL) { [string]$current.SupportURL } Else { 'https://www.omniscomputers.com' }
        OEMLogo = If ($current.Logo) { [string]$current.Logo } Else { '' }
    }
}

Function Get-DefaultRunOptions {
    $oem = Get-OemDefaults
    [ordered]@{
        PrerequisiteItems = @('WinGet','Chocolatey','PowerShell','NuGet','PowerShellGet','PSWindowsUpdate')
        SoftwarePackages = @('7zip','googlechrome','temurin','microsoft-edge','adobereader')
        InstallGpuDrivers = $true
        DriverSource = ''
        OEMManufacturer = $oem.OEMManufacturer
        OEMSupportPhone = $oem.OEMSupportPhone
        OEMSupportURL = $oem.OEMSupportURL
        OEMLogo = $oem.OEMLogo
        ComputerName = ''
        PowerPlan = 'HighPerformance'
        TimeZone = 'Eastern'
        SetChromeDefault = $true
        SetAdobePdfDefault = $true
        InstallAdGuardChrome = $true
        InstallAdGuardEdge = $true
        DnsProvider = 'Dynamic'
        ReportOutputPath = 'C:\Omnis'
        UpdateActiveHoursStart = ''
        UpdateActiveHoursEnd = ''
        DisableWindowsAIPolicies = $true
        DisableEdgeAIPolicies = $true
        DisableNotepadAI = $true
        RemoveCopilotPackages = $false
        WeatherCachePath = $script:WeatherCachePath
    }
}

Function Import-RunOptions {
    Param ([string]$Path)
    $options = Get-DefaultRunOptions
    If (!$Path) { Return $options }

    $candidate = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    ForEach ($property in $candidate.PSObject.Properties) {
        If ($options.Contains($property.Name)) { $options[$property.Name] = $property.Value }
    }
    Return $options
}

$script:RunOptions = Import-RunOptions -Path $SettingsFile
If ($PSBoundParameters.ContainsKey('ComputerName')) { $script:RunOptions.ComputerName = $ComputerName }
If ($DriverSource) { $script:RunOptions.DriverSource = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DriverSource) }

$myExe = $script:AppName

Function Start-ElevatedSelf {
    Param ([string[]]$ArgumentList)

    $processPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $isPowerShellHost = [IO.Path]::GetFileNameWithoutExtension($processPath) -match '^(powershell|pwsh)$'
    $quotedArguments = @($ArgumentList | ForEach-Object { '"' + ($_ -replace '"','\"') + '"' })

    If ($isPowerShellHost) {
        If (!(Test-Path -LiteralPath $PSCommandPath)) { Throw 'Unable to locate the running script.' }
        $quotedScript = '"' + $PSCommandPath + '"'
        Return (Start-Process -FilePath $processPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File $quotedScript $($quotedArguments -join ' ')" -Verb RunAs -PassThru -ErrorAction Stop)
    } Else {
        Return (Start-Process -FilePath $processPath -ArgumentList ($quotedArguments -join ' ') -Verb RunAs -PassThru -ErrorAction Stop)
    }
}

Function Test-IsAdministrator {
    Return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

Function Hide-CompiledConsoleWindow {
    $processName = [IO.Path]::GetFileNameWithoutExtension([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    If ($processName -match '^(powershell|pwsh)$') { Return }
    If (!('Aar318.NativeConsole' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Aar318 {
    public static class NativeConsole {
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr handle, int command);
    }
}
'@
    }
    $handle = [Aar318.NativeConsole]::GetConsoleWindow()
    If ($handle -ne [IntPtr]::Zero) { [void][Aar318.NativeConsole]::ShowWindow($handle,0) }
}

Function Get-HighResolutionApplicationIcon {
    Param ([int]$Size = 64)
    $processPath = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    If (!('Aar318.NativeIcon' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Aar318 {
    public static class NativeIcon {
        [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern int SHDefExtractIcon(string file, int index, uint flags, out IntPtr large, out IntPtr small, uint sizes);
        [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr handle);
    }
}
'@
    }
    $large=[IntPtr]::Zero; $small=[IntPtr]::Zero
    $packedSize = ([uint32]32 -shl 16) -bor [uint32]$Size
    $result=[Aar318.NativeIcon]::SHDefExtractIcon($processPath,0,0,[ref]$large,[ref]$small,$packedSize)
    If($result -eq 0 -and $large -ne [IntPtr]::Zero){
        Try { Return ([Drawing.Icon]::FromHandle($large).Clone()) }
        Finally { [void][Aar318.NativeIcon]::DestroyIcon($large); If($small -ne [IntPtr]::Zero){[void][Aar318.NativeIcon]::DestroyIcon($small)} }
    }
    Return [Drawing.Icon]::ExtractAssociatedIcon($processPath)
}

Function timeStamp {
    Return "{0:MM/dd/yy} {0:HH:mm:ss}" -f ( Get-Date )
} # End timeStamp Function

Function Initialize-RegistryKey {
    Param ([string[]]$Path)
    ForEach ($key in $Path) {
        If (!(Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
    }
}

Function Enable-PrerequisiteModuleLoading {
    If ((Get-ExecutionPolicy) -ne 'Restricted') { Return }
    If ((Get-ExecutionPolicy -Scope MachinePolicy) -ne 'Undefined' -or (Get-ExecutionPolicy -Scope UserPolicy) -ne 'Undefined') {
        Throw 'Windows PowerShell Group Policy blocks script modules. PackageManagement and PSWindowsUpdate require a policy that permits their modules to load.'
    }
    $script:OriginalProcessExecutionPolicy = Get-ExecutionPolicy -Scope Process
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
}

Function Import-PrerequisiteModule {
    Param ([ValidateSet('PackageManagement','PowerShellGet')][string]$Name,[version]$Version)

    $moduleBase = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
    If ($moduleBase -notin ($env:PSModulePath -split ';')) { $env:PSModulePath = "$moduleBase;$env:PSModulePath" }
    $module = Get-Module -ListAvailable -Name $Name | Where-Object Version -GE $Version | Sort-Object Version -Descending | Select-Object -First 1
    If (!$module) {
        $moduleRoot = Join-Path $moduleBase "$Name\$Version"
        $downloadRoot = Join-Path $env:TEMP ("New Computer Install\Module Bootstrap\{0}" -f [guid]::NewGuid().ToString('N'))
        $archive = Join-Path $downloadRoot "$Name.zip"
        $expanded = Join-Path $downloadRoot 'Expanded'
        Write-Host "[$(timeStamp)] Installing [$Name $Version] from PowerShell Gallery." -ForegroundColor Cyan
        Try {
            New-Item -ItemType Directory -Path $expanded -Force | Out-Null
            Invoke-WebRequest -Uri "https://www.powershellgallery.com/api/v2/package/$Name/$Version" -OutFile $archive -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
            Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
            New-Item -ItemType Directory -Path $moduleRoot -Force | Out-Null
            Copy-Item -Path (Join-Path $expanded '*') -Destination $moduleRoot -Recurse -Force
        } Finally {
            Remove-Item -LiteralPath $downloadRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $moduleRoot "$Name.psd1") -Global -ErrorAction Stop
    } Else {
        Import-Module $module.Path -Global -ErrorAction Stop
    }
}

Function Initialize-PowerShellGallery {
    If ($script:PowerShellGalleryReady) { Return }
    Enable-PrerequisiteModuleLoading
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Import-PrerequisiteModule -Name PackageManagement -Version '1.4.8.1'
    Import-PrerequisiteModule -Name PowerShellGet -Version '2.2.5'
    If (!(Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | Where-Object Version -GE ([version]'2.8.5.201'))) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -Confirm:$false -ErrorAction Stop | Out-Null
    }
    $script:PowerShellGalleryReady = $true
}

Function Update-GalleryModule {
    Param ([ValidateSet('PowerShellGet','PSWindowsUpdate')][string]$Name,[switch]$Repair)

    $installed = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    Try {
        Initialize-PowerShellGallery
        $latest = Find-Module -Name $Name -Repository PSGallery -ErrorAction Stop
        If ($Repair -or !$installed -or [version]$latest.Version -gt $installed.Version) {
            Write-Host "[$(timeStamp)] Installing [$Name $($latest.Version)] from PowerShell Gallery." -ForegroundColor Cyan
            Install-Module -Name $Name -RequiredVersion $latest.Version -Repository PSGallery -Scope AllUsers -Force -Confirm:$false -AllowClobber -ErrorAction Stop | Out-Null
        }
    } Catch {
        If ($Repair -or !$installed) { Throw }
        Write-Warning "[$(timeStamp)] Could not check or update [$Name]. Trying the installed version [$($installed.Version)]. $($_.Exception.Message.Trim())"
    }
}

Function Initialize-PSWindowsUpdate {
    If ($script:PSWindowsUpdateReady) { Return }
    Enable-PrerequisiteModuleLoading
    For ($attempt = 0; $attempt -lt 2; $attempt++) {
        Update-GalleryModule -Name PSWindowsUpdate -Repair:($attempt -eq 1)
        Try {
            $module = Import-Module PSWindowsUpdate -Global -PassThru -Force:($attempt -eq 1) -ErrorAction Stop
            If (!$module.ExportedCommands.ContainsKey('Get-WindowsUpdate')) { Throw 'PSWindowsUpdate did not export Get-WindowsUpdate.' }
            $script:PSWindowsUpdateReady = $true
            Write-Host "[$(timeStamp)] PSWindowsUpdate $($module.Version) is ready." -ForegroundColor Gray
            Return
        } Catch [System.Management.Automation.PSSecurityException] {
            Throw
        } Catch {
            If ($attempt -eq 1) { Throw }
            Write-Warning "[$(timeStamp)] Repairing PSWindowsUpdate after a load failure. $($_.Exception.Message.Trim())"
        }
    }
}

Function Initialize-Session {
    $script:StopWatch = [Diagnostics.Stopwatch]::StartNew()
    $script:Log = Join-Path $env:WINDIR ("Temp\{0}-{1}.log" -f $script:AppName,(Get-Date -Format 'yyyy-MM-dd_HH.mm.ss'))
    $script:TargetLogs = Join-Path $env:WINDIR "Temp\$($script:AppName)*.log"
    $script:RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'

    Try {
        $host.UI.RawUI.WindowTitle = "$($script:AppName) — v$($script:AppVersion) by Hor318"
        [console]::WindowWidth = [Math]::Min(135,[console]::LargestWindowWidth)
        [console]::WindowHeight = [Math]::Min(34,[console]::LargestWindowHeight)
        [console]::BufferWidth = [console]::WindowWidth
    } Catch { }

    Push-Location $script:ApplicationRoot -StackName Stack2
    Get-ChildItem $script:TargetLogs -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 3 |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Try { Start-Transcript -Path $script:Log -Force -ErrorAction Stop | Out-Null }
    Catch { Write-Warning "[$(timeStamp)] The session log could not be opened: $($_.Exception.Message)" }
    Write-Host ''
    Write-Host "  $($script:AppName)" -ForegroundColor Cyan
    Write-Host "  Ko-fi: $($script:KoFiUrl)  |  Donate: $($script:DonateUrl)  |  " -ForegroundColor Gray -NoNewline
    Write-Host "v$($script:AppVersion) by Hor318" -ForegroundColor Green
    Write-Host ''
    Write-Host "[$(timeStamp)] Running as Administrator." -ForegroundColor Cyan
    Write-Host "[$(timeStamp)] Log: $($script:Log)" -ForegroundColor Gray
}

<# =================================================================================================================================
Install Chocolatey, updates Powershell, and sets Time Zone as needed      #>
Function PreRequisites {
    [CmdletBinding(SupportsShouldProcess)]
    Param ([string[]]$Items = @('WinGet','Chocolatey','PowerShell','NuGet','PowerShellGet','PSWindowsUpdate'))

    $allowed = @('WinGet','Chocolatey','PowerShell','NuGet','PowerShellGet','PSWindowsUpdate')
    $Items = @($Items | Where-Object { $_ -in $allowed } | Select-Object -Unique)

    $failed = [Collections.Generic.List[string]]::new()
    Try {
        If ($Items -contains 'WinGet') {
            If (!(Get-Command winget.exe -ErrorAction SilentlyContinue)) {
                $desktopInstaller = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
                If ($desktopInstaller -and (Test-Path -LiteralPath (Join-Path $desktopInstaller.InstallLocation 'AppxManifest.xml'))) {
                    Write-Host "[$(timeStamp)] Re-registering the installed App Installer package.." -ForegroundColor Cyan
                    Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $desktopInstaller.InstallLocation 'AppxManifest.xml') -ErrorAction Stop
                }
            }
            If (Get-Command winget.exe -ErrorAction SilentlyContinue) {
                Write-Host "[$(timeStamp)] WinGet version: $(& winget.exe --version)" -ForegroundColor Gray
            } Else {
                Write-Warning "[$(timeStamp)] WinGet is unavailable. Software installs will use Chocolatey when possible. Install or update 'App Installer' from Microsoft Store to restore WinGet."
            }
        }
    } Catch {
        $failed.Add('WinGet')
        Write-Warning "[$(timeStamp)] WinGet setup failed: $($_.Exception.Message)"
    }

    Try {
        $TARGETDIR = Join-Path $env:ProgramData 'chocolatey\bin\choco.exe'
        If (($Items -contains 'Chocolatey') -and !(Get-Command choco.exe -ErrorAction SilentlyContinue) -and !(Test-Path -LiteralPath $TARGETDIR)) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            $installerPath = Join-Path $env:TEMP ("Install-Chocolatey-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
            Write-Host "[$(timeStamp)] Downloading the official Chocolatey installer." -ForegroundColor Cyan
            Try {
                Invoke-WebRequest -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
                $installProcess = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installerPath`"" -Wait -PassThru -ErrorAction Stop
                If ($installProcess.ExitCode -ne 0) { Throw "Chocolatey installer returned exit code [$($installProcess.ExitCode)]." }
            } Finally {
                Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
            }

            # Refresh environment variables in the current session so choco is immediately
            # available in PATH — no relaunch needed
            $env:ChocolateyInstall = "$env:ProgramData\chocolatey"
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
        }

        If ($Items -contains 'Chocolatey') {
            If (!(Get-Command choco.exe -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $TARGETDIR)) {
                $env:Path = "$(Split-Path -Parent $TARGETDIR);$env:Path"
            }
            If (!(Get-Command choco.exe -ErrorAction SilentlyContinue)) { Throw 'choco.exe is unavailable after Chocolatey setup.' }
            Write-Host "[$(timeStamp)] Chocolatey is installed. Continuing script." -ForegroundColor Gray
        }
    } Catch {
        $failed.Add('Chocolatey')
        Write-Warning "[$(timeStamp)] Chocolatey setup failed: $($_.Exception.Message)"
    }
    If ($Items -contains 'PowerShell') { Write-Host "[$(timeStamp)] PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray }

    If ('NuGet' -in $Items -or 'PowerShellGet' -in $Items) {
        Try {
            Initialize-PowerShellGallery
            If ('PowerShellGet' -in $Items) {
                Update-GalleryModule -Name PowerShellGet
                Import-PrerequisiteModule -Name PowerShellGet -Version '2.2.5'
            }
            Write-Host "[$(timeStamp)] PowerShellGet and NuGet are ready." -ForegroundColor Gray
        } Catch {
            $failed.Add("PowerShell Gallery: $($_.Exception.Message.Trim())")
        }
    }
    If ('PSWindowsUpdate' -in $Items) {
        Try { Initialize-PSWindowsUpdate }
        Catch { $failed.Add("PSWindowsUpdate: $($_.Exception.Message.Trim())") }
    }

    If ($failed.Count) { Throw "Prerequisite setup failed for: $($failed -join ', ')." }
} # End PreRequisites function

Function Uninstall-Prerequisites {
    Param ([string[]]$Items = @('Chocolatey','PSWindowsUpdate'))

    $chocoRoot = If ($env:ChocolateyInstall) { $env:ChocolateyInstall } Else { Join-Path $env:ProgramData 'chocolatey' }
    $programDataRoot = [IO.Path]::GetFullPath($env:ProgramData).TrimEnd('\') + '\'
    $resolvedChocoRoot = [IO.Path]::GetFullPath($chocoRoot)

    If (($Items -contains 'Chocolatey') -and (Test-Path -LiteralPath $resolvedChocoRoot) -and $resolvedChocoRoot.StartsWith($programDataRoot,[StringComparison]::OrdinalIgnoreCase)) {
        New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
        $archive = Join-Path $script:BackupRoot ("Chocolatey-{0}.zip" -f (Get-Date -Format 'yyyy-MM-dd_HH.mm.ss'))
        Write-Host "[$(timeStamp)] Backing up Chocolatey to [$archive] before uninstall." -ForegroundColor Yellow
        Compress-Archive -Path (Join-Path $resolvedChocoRoot '*') -DestinationPath $archive -CompressionLevel Fastest -ErrorAction Stop

        $machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
        $cleanPath = (($machinePath -split ';') | Where-Object { $_ -and $_ -notlike "$resolvedChocoRoot*" }) -join ';'
        [Environment]::SetEnvironmentVariable('Path',$cleanPath,'Machine')
        'ChocolateyInstall','ChocolateyToolsLocation','ChocolateyLastPathUpdate' | ForEach-Object {
            [Environment]::SetEnvironmentVariable($_,$null,'Machine')
        }
        Remove-Item -LiteralPath $resolvedChocoRoot -Recurse -Force -ErrorAction Stop
        Write-Host "[$(timeStamp)] Chocolatey removed. Installed Windows applications were left in place." -ForegroundColor Cyan
    } ElseIf ($Items -contains 'Chocolatey') {
        Write-Host "[$(timeStamp)] Chocolatey is not installed in ProgramData; nothing removed." -ForegroundColor Gray
    }

    If ($Items -contains 'PSWindowsUpdate') {
        Enable-PrerequisiteModuleLoading
        Get-Module -ListAvailable PSWindowsUpdate | ForEach-Object {
            Try { Uninstall-Module PSWindowsUpdate -RequiredVersion $_.Version -Force -ErrorAction Stop } Catch {
                Write-Warning "[$(timeStamp)] Could not remove PSWindowsUpdate $($_.Version): $($_.Exception.Message)"
            }
        }
    }

    ForEach ($protected in @('WinGet','PowerShell','NuGet','PowerShellGet')) {
        If ($Items -contains $protected) {
            Write-Host "[$(timeStamp)] [$protected] was left installed because Windows may provide or depend on it." -ForegroundColor Yellow
        }
    }
}

<# =================================================================================================================================
Function to Display the Weather      #>
Function Enable-VirtualTerminalOutput {
    Try {
        If (!('Aar318.VirtualTerminal' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Aar318 {
    public static class VirtualTerminal {
        [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr GetStdHandle(int handle);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(IntPtr handle, out uint mode);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleMode(IntPtr handle, uint mode);
    }
}
'@
        }
        $handle = [Aar318.VirtualTerminal]::GetStdHandle(-11)
        [uint32]$mode = 0
        If ($handle -eq [IntPtr]::Zero -or ![Aar318.VirtualTerminal]::GetConsoleMode($handle,[ref]$mode)) { Return $false }
        Return (($mode -band 4) -ne 0 -or [Aar318.VirtualTerminal]::SetConsoleMode($handle,$mode -bor 4))
    } Catch { Return $false }
}

Function Get-CurrentDayWeatherLines {
    Param ([Parameter(Mandatory)][string]$Content)

    $weatherLines = @($Content -split "`n")
    $plainLines = @($weatherLines | ForEach-Object { $_ -replace "`e\[[0-?]*[ -/]*[@-~]",'' })
    $firstDayStart = 0..($plainLines.Count - 1) | Where-Object { $plainLines[$_] -match '^\s*┌─+┐\s*$' } | Select-Object -First 1
    $firstDayEnd = If ($null -ne $firstDayStart) {
        ($firstDayStart + 1)..($plainLines.Count - 1) | Where-Object { $plainLines[$_] -match '^└─+' } | Select-Object -First 1
    }
    If ($null -eq $firstDayStart -or $null -eq $firstDayEnd) { Throw 'The weather service returned an unexpected format.' }

    $weatherLines[$firstDayStart..$firstDayEnd] | ForEach-Object { $_.TrimEnd("`r") }
}

Function myWeather {
    $weatherContent = $null
    $weatherError = $null
    $weatherQuery = If (Enable-VirtualTerminalOutput) { '' } Else { '?T' }
    ForEach ($weatherUri in @("https://wttr.in/$weatherQuery","http://wttr.in/$weatherQuery")) {
        Try {
            $weatherContent = [string](Invoke-WebRequest -Uri $weatherUri -Headers @{'User-Agent'='curl'} -UseBasicParsing -TimeoutSec 15).Content
            If (![string]::IsNullOrWhiteSpace($weatherContent)) { Break }
        } Catch { $weatherError = $_.Exception.Message }
    }

    If ([string]::IsNullOrWhiteSpace($weatherContent)) {
        Write-Host "[$(timeStamp)] Weather lookup failed: $weatherError" -ForegroundColor Yellow
        Return
    }

    Try {
        $currentDay = @(Get-CurrentDayWeatherLines -Content $weatherContent)
        Write-Host ''
        $currentDay | ForEach-Object { Write-Host $_ }
        Write-Host ''
        $cachePath = [string]$script:RunOptions.WeatherCachePath
        If ($cachePath) {
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($cachePath)) -Force | Out-Null
            $ansiPattern = "$([char]27)\[[0-?]*[ -/]*[@-~]"
            @("Updated: $((Get-Date).ToString('G'))",'') + @($currentDay | ForEach-Object { $_ -replace $ansiPattern,'' }) |
                Set-Content -LiteralPath $cachePath -Encoding UTF8
        }
    } Catch {
        Write-Host "[$(timeStamp)] Weather lookup failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} # End myWeather Function

<# =================================================================================================================================
Function to Configure NTP Settings to go through time.nist.gov and set to EST time zone     #>
Function setTimeZone {
    [CmdletBinding()]
    Param (
        [ValidateSet( 'Hawaiian','Alaskan','Pacific','Mountain','Central','Eastern' )][String]$myTimeZone = 'Eastern'
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
    Write-Host "[$(timeStamp)] Removing known consumer bloatware.." -ForegroundColor Cyan
    $unwantedPatterns = @(
        '^Clipchamp\.Clipchamp$',
        '^Microsoft\.BingNews$',
        '^Microsoft\.BingWeather$',
        '^Microsoft\.GetHelp$',
        '^Microsoft\.Getstarted$',
        '^Microsoft\.MicrosoftOfficeHub$',
        '^Microsoft\.MicrosoftSolitaireCollection$',
        '^Microsoft\.People$',
        '^Microsoft\.SkypeApp$',
        '^Microsoft\.WindowsFeedbackHub$',
        '^Microsoft\.ZuneMusic$',
        '^Microsoft\.ZuneVideo$',
        '^Microsoft\.549981C3F5F10$',
        '^MicrosoftCorporationII\.MicrosoftFamily$',
        'CandyCrush|Disney|Facebook|Instagram|TikTok|Twitter|Spotify'
    )
    $unwantedRegex = $unwantedPatterns -join '|'
    $failed = [Collections.Generic.List[string]]::new()
    $installed = @(Get-AppxPackage -AllUsers -ErrorAction Stop | Where-Object { $_.Name -match $unwantedRegex })

    ForEach ($app in $installed) {
        Write-Host "[$(timeStamp)] Removing installed app [$($app.Name)]." -ForegroundColor Gray
        Try { Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop }
        Catch { $failed.Add("$($app.Name): $($_.Exception.Message.Trim())") }
    }
    $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -match $unwantedRegex })
    ForEach ($app in $provisioned) {
        Write-Host "[$(timeStamp)] Removing provisioned app [$($app.DisplayName)]." -ForegroundColor Gray
        Try { Remove-AppxProvisionedPackage -Online -PackageName $app.PackageName -ErrorAction Stop | Out-Null }
        Catch {
            $removeFailure = $_.Exception.Message.Trim()
            Try {
                $remaining = Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object PackageName -EQ $app.PackageName
            } Catch { $remaining = $true }
            If ($remaining) { $failed.Add("$($app.DisplayName) (provisioned): $removeFailure") }
        }
    }
    If (!$installed -and !$provisioned) { Write-Host "[$(timeStamp)] No targeted consumer bloatware was found." -ForegroundColor Gray }
    If ($failed.Count) { Throw ($failed -join ' | ') }
} # End RemoveBloatware Function

<# =================================================================================================================================
Function to get computer name and rename it     #>
Function Test-ComputerName {
    Param ([string]$Name)
    Return $Name -match '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$' -and $Name -notmatch '^\d+$'
}

Function GetComputerName {
    Param ([string]$NewPCName)

    $hasDefaultName = $env:COMPUTERNAME -like 'DESKTOP*' -or $env:COMPUTERNAME -like 'WIN-*'
    If ($NewPCName -or $hasDefaultName) {
        While (!(Test-ComputerName -Name $NewPCName)) {
            If ($NewPCName) { Write-Warning "[$(timeStamp)] Use 1-15 letters, numbers, or hyphens; the name cannot be only numbers." }
            $NewPCName = Read-Host "Please type a new computer name"
        }
        If ($NewPCName -ieq $env:COMPUTERNAME) { Write-Host "[$(timeStamp)] Computer name is already [$env:COMPUTERNAME]. Skipping rename." -ForegroundColor Gray; Return }
        Rename-Computer -NewName $NewPCName -Force
        Write-Host "[$(timeStamp)] Computer rename scheduled: [$NewPCName]." -ForegroundColor Cyan
    } Else {
        Write-Host "[$(timeStamp)] Computer name [$env:COMPUTERNAME] is already customized. Skipping rename." -ForegroundColor Gray
    }
} # End GetComputerName Function

<# =================================================================================================================================
Function to disable the show suggestions in start button     #>
Function DisableShowSuggestions {
    $path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Initialize-RegistryKey $path
    New-ItemProperty -Path $path -Name 'SubscribedContent-338388Enabled' -PropertyType DWord -Value 0 -Force | Out-Null
    Write-Host "[$(timeStamp)] Show Suggestions in Start disabled (takes effect after reboot)" -ForegroundColor Gray
}

<# =================================================================================================================================
Function to prefer IPv4 without disabling Windows IPv6 components     #>
Function PreferIPv4OverIPv6 {
    $path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
    New-ItemProperty -Path $path -Name 'DisabledComponents' -PropertyType DWord -Value 32 -Force | Out-Null
    Write-Host "[$(timeStamp)] IPv4 is preferred over IPv6; IPv6 remains available to Windows." -ForegroundColor Gray
}

<# =================================================================================================================================
Function to set the selected Windows power plan     #>
Function Set-PowerPlan {
    Param ([ValidateSet('Balanced','HighPerformance')][string]$Plan = 'Balanced')

    $scheme = If ($Plan -eq 'HighPerformance') { '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' } Else { '381b4222-f694-41f0-9685-ff5bb260df2e' }
    $displayName = If ($Plan -eq 'HighPerformance') { 'High Performance' } Else { 'Balanced' }
    If ($Plan -eq 'HighPerformance' -and ((& powercfg.exe /list | Out-String) -notmatch $scheme)) {
        Write-Host "[$(timeStamp)] High Performance is not currently exposed; creating it from Windows' built-in template.." -ForegroundColor Cyan
        $created = & powercfg.exe -duplicatescheme SCHEME_MIN | Out-String
        If ($created -match '[0-9a-fA-F-]{36}') { $scheme = $Matches[0] }
    }
    Write-Host "[$(timeStamp)] Setting power plan to [$displayName].." -ForegroundColor Cyan
    & powercfg.exe -SETACTIVE $scheme
    If ($LASTEXITCODE -ne 0) { Throw "Windows could not activate the [$displayName] power plan (exit code $LASTEXITCODE)." }
    Write-Host "[$(timeStamp)] $(& powercfg.exe -GETACTIVESCHEME)" -ForegroundColor Gray
}

<# =================================================================================================================================
Install common software with WinGet first and Chocolatey as a fallback. #>
Function ChocoSoftware {
    [CmdletBinding()]
    Param (
        [string[]]$Packages = @('7zip','googlechrome','temurin','microsoft-edge','adobereader'),
        [bool]$IncludeGpuDrivers = $true
    )

    $packageMap = [ordered]@{
        '7zip' = @{ WinGet='7zip.7zip'; Chocolatey='7zip' }
        'googlechrome' = @{ WinGet='Google.Chrome'; Chocolatey='googlechrome' }
        'temurin' = @{ WinGet='EclipseAdoptium.Temurin.21.JRE'; Chocolatey='temurin' }
        'microsoft-edge' = @{ WinGet='Microsoft.Edge'; Chocolatey='microsoft-edge' }
        'adobereader' = @{ WinGet='Adobe.Acrobat.Reader.64-bit'; Chocolatey='adobereader' }
        'foxitreader' = @{ WinGet='Foxit.FoxitReader'; Chocolatey='foxitreader' }
    }
    $allowedPackages = @($packageMap.Keys)
    $Packages = @($Packages | ForEach-Object { ([string]$_).ToLowerInvariant() } | Where-Object { $_ -in $allowedPackages } | Select-Object -Unique)
    If (!$Packages -and !$IncludeGpuDrivers) { Write-Host "[$(timeStamp)] No software packages selected." -ForegroundColor Gray; Return }
    $hasWinGet = $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue)
    $hasChocolatey = $null -ne (Get-Command choco.exe -ErrorAction SilentlyContinue)
    If (!$hasWinGet -and !$hasChocolatey) { Throw 'Neither WinGet nor Chocolatey is available. Select the package-manager prerequisites first.' }

    $updateGPU = ''
    $failed = [Collections.Generic.List[string]]::new()
    If ($IncludeGpuDrivers) {
        Write-Host "[$(timeStamp)] Detecting GPU for driver selection.." -ForegroundColor Gray
        Try { $getGPU = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Select-Object -ExpandProperty Caption }
        Catch {
            $failed.Add('GPU detection')
            Write-Warning "[$(timeStamp)] GPU detection failed: $($_.Exception.Message)"
        }
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
    } Else {
        Write-Host "[$(timeStamp)] GPU driver packages were not selected." -ForegroundColor Gray
    }

    ForEach ($package in $Packages) {
        $installed = $false
        If ($hasWinGet) {
            $wingetId = $packageMap[$package].WinGet
            Write-Host "[$(timeStamp)] WinGet: installing or updating [$wingetId].." -ForegroundColor Cyan
            $installExitCode = & {
                # Windows PowerShell turns redirected native stderr into PowerShell errors.
                $ErrorActionPreference = 'Continue'
                & winget.exe install --id $wingetId --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 |
                    Where-Object { $_ -match 'Successfully|installed|upgrade|No available|already' } |
                    ForEach-Object { Write-Host "[$(timeStamp)] $_" -ForegroundColor Gray }
                $LASTEXITCODE
            }
            $installed = $installExitCode -eq 0
            If (!$installed) {
                $installed = & {
                    $ErrorActionPreference = 'Continue'
                    & winget.exe list --id $wingetId --exact --accept-source-agreements --disable-interactivity 2>$null | Out-Null
                    $LASTEXITCODE -eq 0
                }
            }
        }
        If (!$installed -and $hasChocolatey) {
            $chocoId = $packageMap[$package].Chocolatey
            Write-Host "[$(timeStamp)] Chocolatey fallback: installing or updating [$chocoId].." -ForegroundColor Yellow
            & choco.exe upgrade $chocoId -y --limit-output --no-progress
            $installed = $LASTEXITCODE -in @(0,1641,3010)
        }
        If (!$installed) { $failed.Add($package) }
    }

    $gpuPackages = @($updateGPU -split ' ' | Where-Object { $_ })
    If ($gpuPackages) {
        If ($hasChocolatey) {
            Write-Host "[$(timeStamp)] Chocolatey: installing detected GPU tools [$($gpuPackages -join ', ')].." -ForegroundColor Cyan
            & choco.exe upgrade @gpuPackages -y --limit-output --no-progress
            If ($LASTEXITCODE -notin @(0,1641,3010)) { $failed.Add("GPU packages (exit $LASTEXITCODE)") }
        } Else {
            $failed.Add('GPU packages (Chocolatey is unavailable)')
        }
    }

    Write-Host "[$(timeStamp)] Packages attempted: $((@($Packages) + $gpuPackages) -join ', ')" -ForegroundColor Cyan
    If ($failed.Count) { Throw "Software setup failed for: $($failed -join ', ')." }
}

Function Remove-McAfeeProducts {
    Write-Host "[$(timeStamp)] Detecting McAfee applications and Store packages.." -ForegroundColor Cyan

    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'McAfee|WebAdvisor' -or $_.PackageFullName -match 'McAfee|WebAdvisor' } |
        ForEach-Object {
            Write-Host "[$(timeStamp)] Removing Store package [$($_.Name)]." -ForegroundColor Gray
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Continue
        }
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match 'McAfee|WebAdvisor' -or $_.PackageName -match 'McAfee|WebAdvisor' } |
        ForEach-Object {
            Write-Host "[$(timeStamp)] Removing provisioned package [$($_.DisplayName)]." -ForegroundColor Gray
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Continue | Out-Null
        }

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $products = @($uninstallRoots | ForEach-Object { Get-ItemProperty $_ -ErrorAction SilentlyContinue } |
        Where-Object { $_.DisplayName -match 'McAfee|WebAdvisor' } |
        Sort-Object DisplayName,PSChildName -Unique)

    If (!$products) { Write-Host "[$(timeStamp)] No registered McAfee desktop products were found." -ForegroundColor Gray; Return }
    ForEach ($product in $products) {
        Write-Host "[$(timeStamp)] Removing [$($product.DisplayName)].." -ForegroundColor Cyan
        $productCode = If ([string]$product.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') { [string]$product.PSChildName } Else { $null }
        If ($productCode) {
            $process = Start-Process msiexec.exe -ArgumentList @('/x',$productCode,'/qn','/norestart') -Wait -PassThru
        } Else {
            $command = If ($product.QuietUninstallString) { [string]$product.QuietUninstallString } Else { [string]$product.UninstallString }
            If (!$command) { Write-Warning "[$(timeStamp)] [$($product.DisplayName)] has no registered uninstall command."; Continue }
            If ($command -match '^\s*"([^"]+)"\s*(.*)$') { $filePath=$Matches[1]; $arguments=$Matches[2] }
            ElseIf ($command -match '^\s*([^\s]+)\s*(.*)$') { $filePath=$Matches[1]; $arguments=$Matches[2] }
            Else { Write-Warning "[$(timeStamp)] Could not parse the registered uninstaller for [$($product.DisplayName)]."; Continue }
            $process = Start-Process -FilePath $filePath -ArgumentList $arguments -Wait -PassThru
        }
        If ($process.ExitCode -notin @(0,1605,1614,1641,3010)) {
            Write-Warning "[$(timeStamp)] [$($product.DisplayName)] uninstaller returned exit code [$($process.ExitCode)]."
        }
    }
    Write-Host "[$(timeStamp)] McAfee removal pass complete. A reboot may be required." -ForegroundColor Cyan
}

Function Get-RegisteredAssociation {
    Param ([ValidateSet('Chrome','Adobe')][string]$Application,[string]$Identifier)

    If ($Application -eq 'Chrome') {
        $capabilityKeys = @(
            'HKLM:\SOFTWARE\Clients\StartMenuInternet\Google Chrome\Capabilities',
            'HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet\Google Chrome\Capabilities'
        )
        ForEach ($key in $capabilityKeys) {
            $leaf = If ($Identifier -in @('http','https')) { 'URLAssociations' } Else { 'FileAssociations' }
            $values = Get-ItemProperty (Join-Path $key $leaf) -ErrorAction SilentlyContinue
            $property = $values.PSObject.Properties[$Identifier]
            If ($property.Value) { Return [string]$property.Value }
        }
        If (Test-Path 'Registry::HKEY_CLASSES_ROOT\ChromeHTML') { Return 'ChromeHTML' }
    }

    If ($Application -eq 'Adobe') {
        ForEach ($root in @('HKLM:\SOFTWARE\RegisteredApplications','HKLM:\SOFTWARE\WOW6432Node\RegisteredApplications')) {
            $registered = Get-ItemProperty $root -ErrorAction SilentlyContinue
            ForEach ($property in @($registered.PSObject.Properties | Where-Object { $_.Name -match 'Adobe|Acrobat' })) {
                $capabilityPath = "Registry::HKEY_LOCAL_MACHINE\$($property.Value)\FileAssociations"
                $values = Get-ItemProperty $capabilityPath -ErrorAction SilentlyContinue
                $association = $values.PSObject.Properties[$Identifier]
                If ($association.Value) { Return [string]$association.Value }
            }
        }
        If (Test-Path 'Registry::HKEY_CLASSES_ROOT\AcroExch.Document.DC') { Return 'AcroExch.Document.DC' }
    }
    Return $null
}

Function Set-DefaultApplicationsForNewProfiles {
    Param ([bool]$Chrome=$true,[bool]$AdobePdf=$true)

    $associations = [ordered]@{}
    If ($Chrome) {
        ForEach ($identifier in @('http','https','.htm','.html')) {
            $progId = Get-RegisteredAssociation -Application Chrome -Identifier $identifier
            If (!$progId) { Throw "Google Chrome is not registered for [$identifier]. Install Chrome before provisioning default apps." }
            $associations[$identifier] = [pscustomobject]@{ ProgId=$progId; Name='Google Chrome' }
        }
    }
    If ($AdobePdf) {
        $progId = Get-RegisteredAssociation -Application Adobe -Identifier '.pdf'
        If (!$progId) { Throw 'Adobe Reader is not registered for PDF files. Install Adobe Reader before provisioning default apps.' }
        $associations['.pdf'] = [pscustomobject]@{ ProgId=$progId; Name='Adobe Acrobat Reader' }
    }
    If (!$associations.Count) { Write-Host "[$(timeStamp)] No default application associations selected." -ForegroundColor Yellow; Return }

    $targetRoot = Join-Path $env:ProgramData "Aar318's New Computer Install"
    New-Item -ItemType Directory -Path $targetRoot -Force | Out-Null
    $xmlPath = Join-Path $targetRoot 'DefaultAppAssociations.xml'
    & dism.exe '/Online' ("/Export-DefaultAppAssociations:$xmlPath") | ForEach-Object { Write-Host "[$(timeStamp)] $_" -ForegroundColor Gray }
    If (!(Test-Path -LiteralPath $xmlPath)) {
        Set-Content -LiteralPath $xmlPath -Value '<?xml version="1.0" encoding="UTF-8"?><DefaultAssociations />' -Encoding UTF8
    }

    [xml]$xml = Get-Content -LiteralPath $xmlPath -Raw
    ForEach ($identifier in $associations.Keys) {
        $details = $associations[$identifier]
        $node = @($xml.DefaultAssociations.Association | Where-Object { $_.Identifier -eq $identifier }) | Select-Object -First 1
        If (!$node) { $node = $xml.CreateElement('Association'); [void]$xml.DefaultAssociations.AppendChild($node) }
        $node.SetAttribute('Identifier',$identifier)
        $node.SetAttribute('ProgId',$details.ProgId)
        $node.SetAttribute('ApplicationName',$details.Name)
    }
    $xml.Save($xmlPath)
    & dism.exe '/Online' ("/Import-DefaultAppAssociations:$xmlPath") | ForEach-Object { Write-Host "[$(timeStamp)] $_" -ForegroundColor Gray }
    If ($LASTEXITCODE -ne 0) { Throw "DISM could not import the default associations (exit code $LASTEXITCODE)." }
    Write-Host "[$(timeStamp)] Chrome and Adobe defaults were provisioned for new Windows profiles." -ForegroundColor Cyan
}

Function Install-AdGuardBrowserPolicies {
    Param ([bool]$Chrome=$true,[bool]$Edge=$true)

    If ($Chrome) {
        $chromePolicy = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist'
        Initialize-RegistryKey $chromePolicy
        New-ItemProperty -Path $chromePolicy -Name '318' -PropertyType String -Value 'bgnkhhnnamicmpeenaelnjfhikgbkllg;https://clients2.google.com/service/update2/crx' -Force | Out-Null
        Write-Host "[$(timeStamp)] AdGuard policy configured for every Chrome profile." -ForegroundColor Gray
    }
    If ($Edge) {
        $edgePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'
        Initialize-RegistryKey $edgePolicy
        New-ItemProperty -Path $edgePolicy -Name '318' -PropertyType String -Value 'pdffkfellgipmhklpdmokmckkkfcopbh;https://edge.microsoft.com/extensionwebstorebase/v1/crx' -Force | Out-Null
        Write-Host "[$(timeStamp)] AdGuard policy configured for every Edge profile." -ForegroundColor Gray
    }
}

<# =================================================================================================================================
Function to install Drivers and Windows Updates     #>
Function WindowUpdatesInstall {
    Write-Host "[$(timeStamp)] Checking for Windows Updates.." -ForegroundColor Cyan
    $failed = @(
        Try {
            Initialize-PSWindowsUpdate
            PSWindowsUpdate\Get-WindowsUpdate -MicrosoftUpdate -Install -AcceptAll -IgnoreReboot -ErrorAction Stop | Out-Host
        } Catch { "Windows Update: $($_.Exception.Message.Trim())" }
        Try { $null = InstallMissingDrivers }
        Catch { "Driver updates: $($_.Exception.Message.Trim())" }
    )
    If ($failed) { Throw ($failed -join ' | ') }
    Write-Host "[$(timeStamp)] Windows Update installation pass complete." -ForegroundColor Gray
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
            Initialize-RegistryKey 'Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\command'
        }
        If (!( Test-Path -Path Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget )) {
            Initialize-RegistryKey 'Registry::HKEY_CLASSES_ROOT\Applications\photoviewer.dll\shell\open\DropTarget'
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
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -PropertyType DWord -Value 0 -Force | Out-Null
    Write-Host "[$(timeStamp)] Fast Startup disabled." -ForegroundColor Gray
}

Function EnableLongPaths {
    New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -PropertyType DWord -Value 1 -Force | Out-Null
    Write-Host "[$(timeStamp)] Win32 long-path support enabled for compatible applications." -ForegroundColor Gray
}

Function ShowFileExtensions {
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -PropertyType DWord -Value 0 -Force | Out-Null
    Write-Host "[$(timeStamp)] File name extensions are now shown in File Explorer." -ForegroundColor Gray
}

<# =================================================================================================================================
Function to prompt for a reboot     #>
Function RebootNow {
    $rebootNow = Read-Host "Your computer will need to be rebooted to apply all changes. Would you like to reboot now? [Y/N]: "

    If ( $rebootNow -eq "Y" ) {
        Write-Warning "[$(timeStamp)] Rebooting in a few seconds.. Thanks for using this script!"
        Start-Sleep -Seconds 4
            cmd /c "shutdown /r /t 001"
    }
    If ( $rebootNow -eq "N" ) {
        Write-Warning "[$(timeStamp)] Please reboot manually at your convenience. Thanks for using this script!"
        Start-Sleep -Seconds 3
    }
} # End RebootNow Function

<# =================================================================================================================================
 Get driver health state     #>
Function GetDriverHealth {
    $DeviceState = Get-CimInstance -ClassName Win32_PnpEntity -Namespace Root\CIMV2 -ErrorAction Stop |
        Where-Object { $_.Present -ne $false -and $_.ConfigManagerErrorCode -gt 0 }

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
            43  {"A driver reported that the device failed."}
            Default {"Windows reports a device problem."}
        } # End $Errortext switch

        [PSCustomObject] @{
            ErrorCode   = $device.ConfigManagerErrorCode
            ErrorText   = $Errortext
            Device      = If ($device.Caption) { $device.Caption } Else { $device.DeviceID }
            InstanceId  = $device.DeviceID
            HardwareIds = @($device.HardwareID)
            CompatibleIds = @($device.CompatibleID)
        }

    }

} # End GetDriverHealth Function

<# =================================================================================================================================
 Install Missing Drivers     #>
Function Select-DriverUpdates {
    Param ([object[]]$Updates,[object[]]$Devices)

    $offers = @{}
    $rankedUpdates = $Updates | Sort-Object @{Expression={[bool]$_.BrowseOnly}},@{Expression={$_.DriverVerDate};Descending=$true}
    ForEach ($update in $rankedUpdates) {
        $ids = @($update.DriverHardwareID) + @($update.WindowsDriverUpdateEntries | ForEach-Object { $_.DriverHardwareID })
        ForEach ($id in $ids) {
            If ($id -and !$offers.ContainsKey($id)) { $offers[$id] = $update }
        }
    }

    $selected = @{}
    ForEach ($device in $Devices) {
        $matchId = @($device.HardwareIds) + @($device.CompatibleIds) |
            Where-Object { $_ -and $offers.ContainsKey($_) } | Select-Object -First 1
        If (!$matchId) {
            Write-Host "[$(timeStamp)] No matching Windows Update driver offered for [$($device.Device)]." -ForegroundColor Yellow
            Continue
        }
        $update = $offers[$matchId]
        $id = $update.Identity.UpdateID
        Write-Host "[$(timeStamp)] [$($device.Device)] matched [$($update.Title)] via [$matchId]." -ForegroundColor Gray
        If (!$selected.ContainsKey($id)) {
            $selected[$id] = $true
            $update
        }
    }
}

Function InstallMissingDrivers {
    Param ([object[]]$Devices)

    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $criteria = "IsInstalled=0 and Type='Driver' and IsHidden=0"
    If ($Devices) {
        Write-Host "[$(timeStamp)] Searching the configured Windows Update source for regular and optional drivers matching problem devices." -ForegroundColor Gray
        $criteria = "($criteria and BrowseOnly=0) or ($criteria and BrowseOnly=1)"
    } Else {
        Write-Host "[$(timeStamp)] Searching the configured Windows Update source for available drivers." -ForegroundColor Gray
    }
    $searchResult = $searcher.Search($criteria)
    If ($searchResult.ResultCode -notin @(2,3)) { Throw "Windows Update driver search returned result $($searchResult.ResultCode)." }
    If ($searchResult.ResultCode -eq 3) { Write-Warning "[$(timeStamp)] Windows Update returned partial driver search results." }
    $updates = @($searchResult.Updates | ForEach-Object { $_ })
    If ($Devices) { $updates = @(Select-DriverUpdates -Updates $updates -Devices $Devices) }
    If (!$updates.Count) {
        Write-Host "[$(timeStamp)] No applicable driver packages were selected from Windows Update." -ForegroundColor Gray
        Return $false
    }

    $failed = [Collections.Generic.List[string]]::new()
    $toDownload = New-Object -ComObject Microsoft.Update.UpdateColl
    ForEach ($update in $updates) {
        Try {
            If (!$update.EulaAccepted) { $null = $update.AcceptEula() }
            $null = $toDownload.Add($update)
        } Catch { $failed.Add("prepare [$($update.Title)]: $($_.Exception.Message.Trim())") }
    }
    If (!$toDownload.Count) { Throw ($failed -join ' | ') }
    Write-Host "[$(timeStamp)] Downloading $($toDownload.Count) driver package(s)." -ForegroundColor Gray
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $toDownload
    $downloadResult = $downloader.Download()

    $toInstall = New-Object -ComObject Microsoft.Update.UpdateColl
    For ($i = 0; $i -lt $toDownload.Count; $i++) {
        $update = $toDownload.Item($i)
        If ($update.IsDownloaded) {
            $null = $toInstall.Add($update)
        } Else {
            $status = $downloadResult.GetUpdateResult($i)
            $failed.Add(("download [{0}]: result {1}, HRESULT 0x{2:X8}" -f $update.Title,$status.ResultCode,$status.HResult))
        }
    }
    If (!$toInstall.Count) { Throw ($failed -join ' | ') }
    Write-Host "[$(timeStamp)] Installing $($toInstall.Count) driver package(s)." -ForegroundColor Cyan
    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $toInstall
    $installationResult = $installer.Install()
    For ($i = 0; $i -lt $toInstall.Count; $i++) {
        $title = $toInstall.Item($i).Title
        $status = $installationResult.GetUpdateResult($i)
        If ($status.ResultCode -eq 2) {
            Write-Host "[$(timeStamp)] Installed driver [$title]." -ForegroundColor Gray
        } Else {
            $failed.Add(("install [{0}]: result {1}, HRESULT 0x{2:X8}" -f $title,$status.ResultCode,$status.HResult))
        }
    }
    If ($installationResult.RebootRequired) {
        $script:DriverRebootPending = $true
        Write-Warning "[$(timeStamp)] A reboot is required to finish driver installation."
    }
    If ($failed.Count) { Throw ($failed -join ' | ') }
    Return [bool]$installationResult.RebootRequired
} # End InstallMissingDrivers Function

Function Test-DriverCatalogAccess {
    $policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $groupPolicy = $null
    ForEach ($path in @($policyPath,'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update')) {
        If (!(Test-Path -LiteralPath $path -ErrorAction Stop)) { Continue }
        $policy = Get-ItemProperty -LiteralPath $path -ErrorAction Stop
        If ($path -eq $policyPath) { $groupPolicy = $policy }
        If ($policy.DoNotConnectToWindowsUpdateInternetLocations -eq 1 -or $policy.DisableWindowsUpdateAccess -eq 1 -or
            $policy.ExcludeWUDriversInQualityUpdate -eq 1 -or $policy.ExcludeWUDriversFromQualityUpdates -eq 1 -or
            $policy.SetPolicyDrivenUpdateSourceForDriverUpdates -eq 1 -or
            ($policy.UpdateServiceUrl -and $policy.SetPolicyDrivenUpdateSourceForDriverUpdates -ne 0)) { Return $false }
    }
    $auPath = "$policyPath\AU"
    If (!(Test-Path -LiteralPath $auPath -ErrorAction Stop)) { Return $true }
    $au = Get-ItemProperty -LiteralPath $auPath -ErrorAction Stop
    Return ($au.UseWUServer -ne 1 -or ($au.UseUpdateClassPolicySource -eq 1 -and $groupPolicy.SetPolicyDrivenUpdateSourceForDriverUpdates -eq 0))
}

Function Test-DriverCatalogProduct {
    Param ([string]$Products,[string]$Family,[string]$Release)

    ForEach ($product in ($Products -split '(?i)(?=Windows\s+(?:10|11|Server|- Client))')) {
        If ($product -notlike "$Family*" -and
            !($Family -ne 'Windows Server' -and ($product -like 'Windows - Client*' -or
                ($Family -eq 'Windows 11' -and $product -like 'Windows 10*and later*')))) { Continue }
        If ($Release -match '^\d{2}H[12]$' -and $product -match '\bversion\s+(\d{2}H[12])\b') {
            $minimum = $Matches[1]
            If ($minimum -gt $Release -or ($minimum -ne $Release -and $product -notlike '*and later*')) { Continue }
        }
        Return $true
    }
    Return $false
}

Function Get-DriverCatalogRows {
    Param ([string]$Html)

    # shortcut: the Catalog exposes an HTML search page; use its first page until an official driver search API is available.
    $rowPattern = '(?is)<tr\b[^>]*\bid=["''](?<id>[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})_R\d+["''][^>]*>(?<body>.*?)</tr>'
    ForEach ($row in [regex]::Matches($Html,$rowPattern)) {
        $cells = @([regex]::Matches($row.Groups['body'].Value,'(?is)<td\b[^>]*>(.*?)</td>') | ForEach-Object {
            [Net.WebUtility]::HtmlDecode(($_.Groups[1].Value -replace '<[^>]*>','')).Trim()
        })
        If ($cells.Count -lt 6 -or $cells[3] -notmatch '^Drivers\b' -or "$($cells[1]) $($cells[3])" -match '\b(?:Firmware|BIOS|UEFI)\b') { Continue }
        $version = [version]'0.0'
        If (![version]::TryParse($cells[5],[ref]$version)) { $version = [version]'0.0' }
        [pscustomobject]@{ Id=$row.Groups['id'].Value; Title=$cells[1]; Products=$cells[2]; Version=$version }
    }
}

Function Get-DriverCatalogDownloads {
    Param ([string]$Html,[guid]$UpdateId)

    If ($Html -notmatch "(?im)^\s*downloadInformation\[0\]\.updateID\s*=\s*'$UpdateId'\s*;") { Return }
    $files = [ordered]@{}
    $fieldPattern = '(?m)^\s*downloadInformation\[0\]\.files\[(?<index>\d+)\]\.(?<key>url|sha256)\s*=\s*''(?<value>[^''\r\n]+)''\s*;'
    ForEach ($field in [regex]::Matches($Html,$fieldPattern)) {
        $index = $field.Groups['index'].Value
        If (!$files.Contains($index)) { $files[$index] = @{} }
        $files[$index][$field.Groups['key'].Value] = $field.Groups['value'].Value
    }
    ForEach ($file in $files.Values) {
        $uri = $null
        If (![uri]::TryCreate($file.url,[UriKind]::Absolute,[ref]$uri) -or
            $uri.Scheme -notin @('https','http') -or !$uri.IsDefaultPort -or $uri.UserInfo -or
            $uri.Host -notmatch '^(?:[a-z0-9-]+\.)*download\.windowsupdate\.com$' -or
            $uri.AbsolutePath -notmatch '\.cab$' -or $file.sha256 -notmatch '^[A-Za-z0-9+/]{43}=$') { Continue }
        $https = [UriBuilder]::new($uri)
        $https.Scheme = 'https'
        $https.Port = -1
        [pscustomobject]@{
            Uri = $https.Uri
            Hash = [BitConverter]::ToString([Convert]::FromBase64String($file.sha256)).Replace('-','')
        }
    }
}

Function Install-DriverCatalogDownload {
    Param ([object]$Download,[string[]]$HardwareIds)

    $folder = Join-Path ([IO.Path]::GetTempPath()) ("NCI-DriverPackage-" + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $folder -ErrorAction Stop
    Try {
        $archive = Join-Path $folder 'driver.cab'
        $expanded = Join-Path $folder 'Expanded'
        Invoke-WebRequest -Uri $Download.Uri -OutFile $archive -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 120 -ErrorAction Stop
        If ((Get-FileHash -LiteralPath $archive -Algorithm SHA256 -ErrorAction Stop).Hash -ne $Download.Hash) { Throw 'Microsoft Update Catalog SHA-256 mismatch.' }
        $null = New-Item -ItemType Directory -Path $expanded -ErrorAction Stop
        & expand.exe $archive '-F:*' $expanded | Out-Null
        If ($LASTEXITCODE -ne 0) { Throw "CAB extraction exited with code $LASTEXITCODE." }

        ForEach ($inf in Get-ChildItem -LiteralPath $expanded -Filter '*.inf' -File -Recurse -ErrorAction Stop) {
            $content = Get-Content -LiteralPath $inf.FullName -Raw -ErrorAction Stop
            If ($content -match '(?im)^\s*Class\s*=\s*"?Firmware\b') { Continue }
            $matchingIds = @([regex]::Matches($content,'(?m)^[ \t]*[^;\r\n=]+=[^,;\r\n]+,(?<ids>[^;\r\n]+)') | ForEach-Object {
                $_.Groups['ids'].Value -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ -in $HardwareIds }
            })
            If (!$matchingIds.Count) { Continue }
            $signed = $false
            ForEach ($ref in [regex]::Matches($content,'(?im)^[ \t]*CatalogFile(?:\.[a-z0-9.]+)?\s*=\s*"?(?<name>[a-z0-9_.-]+\.cat)\b')) {
                $catalogFile = Join-Path $inf.DirectoryName $ref.Groups['name'].Value
                If (!(Test-Path -LiteralPath $catalogFile -PathType Leaf)) { Continue }
                $signature = Get-AuthenticodeSignature -LiteralPath $catalogFile
                If ($signature.Status -eq 'Valid' -and $signature.SignerCertificate.Subject -match '^CN=Microsoft Windows\b') { $signed = $true; Break }
            }
            If (!$signed) { Write-Warning "[$(timeStamp)] Skipping [$($inf.Name)]: a valid Microsoft driver catalog signature was unavailable."; Continue }
            & pnputil.exe /add-driver $inf.FullName /install | Out-Host
            If ($LASTEXITCODE -eq 3010) { Return $true }
            If ($LASTEXITCODE -notin @(0,259)) { Write-Warning "[$(timeStamp)] PnPUtil returned exit code $LASTEXITCODE for [$($inf.Name)]." }
        }
        Return $false
    } Finally {
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Function Invoke-DriverCatalogRepair {
    Param ([object[]]$Devices)

    If (!$Devices.Count) { Return $false }
    If (!(Test-DriverCatalogAccess)) {
        Write-Host "[$(timeStamp)] Managed Windows Update settings restrict the public driver Catalog pass." -ForegroundColor Gray
        Return $false
    }
    $os = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $family = If ($os.InstallationType -like 'Server*') { 'Windows Server' }
        ElseIf ([int]$os.CurrentBuild -ge 22000) { 'Windows 11' } Else { 'Windows 10' }
    $architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    If ($architecture -eq 'X64') { $architecture = 'AMD64' }
    $base = 'https://www.catalog.update.microsoft.com'
    $headers = @{'Accept-Language'='en-US'}
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $remaining = $Devices
    ForEach ($device in $Devices) {
        If ($device.InstanceId -notin $remaining.InstanceId) { Continue }
        $ids = @($device.HardwareIds | Where-Object { $_ -match '^[a-z0-9]{2,16}\\[a-z0-9_.&{}#:+\-]{2,145}$' } | Select-Object -Unique)
        If (!$ids.Count) { Continue }
        Write-Host "[$(timeStamp)] Searching Microsoft Update Catalog for [$($device.Device)]." -ForegroundColor Gray
        $checked = @{}
        $testedDownloads = @{}
        $downloads = 0
        $queries = @(@($ids[0],$ids[-1]) + $ids | Select-Object -Unique -First 4)
        :deviceSearch ForEach ($id in $queries) {
            $query = [uri]::EscapeDataString($id)
            $page = Invoke-WebRequest -Uri "$base/Search.aspx?q=$query" -Headers $headers -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 15 -ErrorAction Stop
            $rows = Get-DriverCatalogRows -Html $page.Content | Where-Object {
                Test-DriverCatalogProduct $_.Products $family $os.DisplayVersion
            } | Sort-Object Version -Descending
            ForEach ($row in $rows) {
                If ($checked.ContainsKey($row.Id)) { Continue }
                $checked[$row.Id] = $true
                Try {
                    $detail = Invoke-WebRequest -Uri "$base/ScopedViewInline.aspx?updateid=$($row.Id)" -Headers $headers -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 15 -ErrorAction Stop
                    $arch = [regex]::Match($detail.Content,'(?is)\bid="archDiv"[^>]*>.*?</span>\s*([a-z0-9]+)\s*</div>').Groups[1].Value
                    If ($arch -ne $architecture -or $detail.Content -match '(?is)\bid="ScopedViewHandler_driverClass"[^>]*>\s*Firmware\s*</span>') { Continue }
                    $hardware = [regex]::Match($detail.Content,'(?is)\bid="driverhwIDs"[^>]*>(.*?)\bid="driverupdateIDs"').Groups[1].Value
                    $catalogIds = @([regex]::Matches($hardware,'(?is)<div\b[^>]*>\s*([^<>]+?)\s*</div>') | ForEach-Object {
                        [Net.WebUtility]::HtmlDecode($_.Groups[1].Value).Trim()
                    })
                    If (!($ids | Where-Object { $_ -in $catalogIds })) { Continue }
                    $body = '[{"size":0,"updateID":"' + $row.Id + '","uidInfo":"' + $row.Id + '"}]'
                    $dialog = Invoke-WebRequest -Uri "$base/DownloadDialog.aspx" -Method Post -Body @{updateIDs=$body} -Headers $headers -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 15 -ErrorAction Stop
                    ForEach ($download in Get-DriverCatalogDownloads -Html $dialog.Content -UpdateId $row.Id) {
                        If ($testedDownloads.ContainsKey($download.Hash)) { Continue }
                        $testedDownloads[$download.Hash] = $true
                        $downloads++
                        Write-Host "[$(timeStamp)] Downloading Catalog driver [$($row.Title)] for [$($device.Device)]." -ForegroundColor Cyan
                        If (Install-DriverCatalogDownload -Download $download -HardwareIds $ids) { Return $true }
                        $remaining = @(GetDriverHealth)
                        If ($device.InstanceId -notin $remaining.InstanceId -or $downloads -ge 3) { Break deviceSearch }
                    }
                } Catch {
                    Write-Warning "[$(timeStamp)] Catalog candidate [$($row.Id)] failed: $($_.Exception.Message.Trim())"
                    If ($downloads -ge 3) { Break deviceSearch }
                }
            }
        }
    }
    Return $false
}

<# =================================================================================================================================
 Remove 'Meet Now'     #>
Function RemoveMeetNow {
    Initialize-RegistryKey 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1
    Write-Host "[$(timeStamp)] Meet Now disabled." -ForegroundColor Gray
} # End RemoveMeetNow Function

<# =================================================================================================================================
Function to select active hours for Windows Updates     #>
Function SetWindowsUpdateHours ( $startTime,$endTime ) {
    $path = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    Initialize-RegistryKey $path
    New-ItemProperty -Path $path -Name 'ActiveHoursStart' -PropertyType DWord -Value $startTime -Force | Out-Null
    New-ItemProperty -Path $path -Name 'ActiveHoursEnd' -PropertyType DWord -Value $endTime -Force | Out-Null
    Write-Host ("[{0}] Windows Update active hours: Start [{1:00}:00] End [{2:00}:00]" -f (timeStamp),$startTime,$endTime) -ForegroundColor Gray
} # End SetWindowsUpdateHours

Function Resolve-UpdateActiveHour {
    Param ([object]$Value,[int]$Default)
    If ([string]::IsNullOrWhiteSpace([string]$Value)) { Return $Default }
    $hour = 0
    If (![int]::TryParse([string]$Value,[ref]$hour) -or $hour -lt 0 -or $hour -gt 23) {
        Throw 'Update active hours must use whole hours from 0 through 23, or be left blank for the 20:00-05:00 default.'
    }
    Return $hour
}

<# =================================================================================================================================
 Set auto arrange icons     #>
Function AutoArrange ( $enable ) {
    $path = 'HKCU:\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop'
    Initialize-RegistryKey $path
    If ( $enable ) {
        Write-Host "[$(timeStamp)] Auto Arrange: [ON] — Align to grid: [ON]" -ForegroundColor Gray
        New-ItemProperty -Path $path -Name 'FFLAGS' -PropertyType DWord -Value 1075839525 -Force | Out-Null
    } ElseIf ( $enable -eq $false ) {
        Write-Host "[$(timeStamp)] Auto Arrange: [OFF] — Align to grid: [ON]" -ForegroundColor Gray
        New-ItemProperty -Path $path -Name 'FFLAGS' -PropertyType DWord -Value 1075839524 -Force | Out-Null
    } Else {
        Write-Host "[$(timeStamp)] AutoArrange: no option selected. Pass -enable `$true or `$false." -ForegroundColor Yellow
    }
} # End AutoArrange Function

Function Test-NewsAndInterestsPolicy {
    $os = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $build = [int]$os.CurrentBuild
    Return ($os.InstallationType -eq 'Client' -and $build -ge 19041 -and $build -lt 22000 -and $os.EditionID -notlike 'Core*')
}

Function NewsAndInterestsTaskbar {
    Param (
        [Parameter(Mandatory = $true,ParameterSetName = "Show")]
        [switch]$Show,
        [Parameter(Mandatory = $true,ParameterSetName = "Hide")]
        [switch]$Hide
    )

    If (!(Test-NewsAndInterestsPolicy)) {
        Write-Host "[$(timeStamp)] Skipping the legacy News and Interests policy on this Windows edition or version." -ForegroundColor Gray
        Return
    }
    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
    If ($Hide) {
        Initialize-RegistryKey $path
        New-ItemProperty -LiteralPath $path -Name EnableFeeds -PropertyType DWord -Value 0 -Force -ErrorAction Stop | Out-Null
        Write-Host "[$(timeStamp)] News and Interests: hidden." -ForegroundColor Gray
    } Else {
        $policy = Get-ItemProperty -LiteralPath $path -Name EnableFeeds -ErrorAction SilentlyContinue
        If ($policy) { Remove-ItemProperty -LiteralPath $path -Name EnableFeeds -Force -ErrorAction Stop }
        Write-Host "[$(timeStamp)] News and Interests policy cleared." -ForegroundColor Gray
    }
} # End NewsAndInterestsTaskbar Function

# Runs functions to get and enable any PnP devices that are not showing up
Function PnPDevices {
    $devices = @(GetDriverHealth)
    If (!$devices.Count) {
        Write-Host "[$(timeStamp)] All devices are in a healthy state." -ForegroundColor Gray
        Return
    }
    Write-Host "[$(timeStamp)] Device errors detected:" -ForegroundColor Yellow
    $devices | Format-Table ErrorCode,Device,ErrorText -AutoSize | Out-Host

    Write-Host "[$(timeStamp)] Rescanning devices before running fixes." -ForegroundColor Gray
    & pnputil.exe /scan-devices | Out-Host
    If ($LASTEXITCODE -ne 0) { Write-Warning "[$(timeStamp)] Device scan exited with code $LASTEXITCODE." }
    $devices = @(GetDriverHealth)

    $rebootRequired = $false
    ForEach ($device in $devices) {
        Try {
            Switch ($device.ErrorCode) {
                22 { Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop }
                43 {
                    Write-Host "[$(timeStamp)] Restarting device [$($device.Device)] after Code 43." -ForegroundColor Gray
                    & pnputil.exe /restart-device $device.InstanceId | Out-Host
                    If ($LASTEXITCODE -eq 3010) { $rebootRequired = $true }
                    ElseIf ($LASTEXITCODE -ne 0) { Throw "PnPUtil returned exit code $LASTEXITCODE." }
                }
            }
        } Catch { Write-Warning "[$(timeStamp)] Could not reset [$($device.Device)]: $($_.Exception.Message.Trim())" }
    }
    $driverFailures = [Collections.Generic.List[string]]::new()
    $driverProblemCodes = @(1,2,3,4,8,10,18,21,23,24,28,31,43)
    $targets = @(GetDriverHealth | Where-Object ErrorCode -In $driverProblemCodes)
    $source = [string]$script:RunOptions.DriverSource
    If ($source -and $targets.Count -and !$rebootRequired) {
        Try {
            $folder = Get-Item -LiteralPath $source -ErrorAction Stop
            If ($folder -isnot [IO.DirectoryInfo]) { Throw "Driver source [$source] must be a folder of extracted INF packages." }
            If (!(Get-ChildItem -LiteralPath $folder.FullName -File -Filter '*.inf' -Recurse -ErrorAction Stop | Select-Object -First 1)) {
                Throw "No INF driver packages were found under [$($folder.FullName)]."
            }
            Write-Host "[$(timeStamp)] Checking driver packages in [$($folder.FullName)]." -ForegroundColor Gray
            & pnputil.exe /add-driver (Join-Path $folder.FullName '*.inf') /subdirs /install | Out-Host
            If ($LASTEXITCODE -eq 3010) { $rebootRequired = $true }
            ElseIf ($LASTEXITCODE -notin @(0,259)) { Throw "PnPUtil returned exit code $LASTEXITCODE." }
        } Catch { $driverFailures.Add("Local driver source: $($_.Exception.Message.Trim())") }
        $targets = @(GetDriverHealth | Where-Object ErrorCode -In $driverProblemCodes)
    }
    If ($targets.Count -and !$rebootRequired) {
        Try { $rebootRequired = InstallMissingDrivers -Devices $targets }
        Catch { $driverFailures.Add("Windows Update: $($_.Exception.Message.Trim())") }
    }

    $remaining = @(GetDriverHealth)
    $rebootRequired = $rebootRequired -or $script:DriverRebootPending
    $unresolved = @($remaining | Where-Object ErrorCode -In $driverProblemCodes)
    If ($unresolved.Count -and !$rebootRequired -and 14 -notin $remaining.ErrorCode) {
        Try { $rebootRequired = Invoke-DriverCatalogRepair -Devices $unresolved }
        Catch { $driverFailures.Add("Microsoft Update Catalog: $($_.Exception.Message.Trim())") }
        $remaining = @(GetDriverHealth)
    }
    ForEach ($device in $remaining) {
        Write-Warning "[$(timeStamp)] [$($device.Device)] still reports Code $($device.ErrorCode). Instance ID: $($device.InstanceId)"
        Write-Host "  Hardware IDs: $($device.HardwareIds -join ', ')" -ForegroundColor Gray
        Write-Host "  Compatible IDs: $($device.CompatibleIds -join ', ')" -ForegroundColor Gray
    }
    If ($rebootRequired -or 14 -in $remaining.ErrorCode) {
        Write-Warning "[$(timeStamp)] A reboot is pending. Recheck device status after restarting."
    }
    If (@($remaining | Where-Object ErrorCode -NE 14).Count) {
        $driverFailures.Add('Device problems remain. See hardware IDs and error codes above.')
        Throw ($driverFailures -join ' | ')
    }
    If ($driverFailures.Count) { Write-Warning "[$(timeStamp)] $($driverFailures -join ' | ')" }
    If (!$remaining.Count) {
        Write-Host "[$(timeStamp)] No present devices report a problem after repair." -ForegroundColor Green
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
            If (( Get-CimInstance -ClassName 'Win32_OperatingSystem' ).ProductType -eq 1 ) {
                Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -Type DWord -Value 1
            } Else {
                Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "VerboseStatus" -ErrorAction SilentlyContinue
            }
    }

    If ( $VerboseLoginStatus -eq 'Disable' ) {
        Write-Host "[$(timeStamp)] Verbose login status: disabled" -ForegroundColor Gray
            If (( Get-CimInstance -ClassName 'Win32_OperatingSystem').ProductType -eq 1 ) {
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
            Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE\"
            vssadmin Resize ShadowStorage /On=$env:SYSTEMDRIVE /For=$env:SYSTEMDRIVE /MaxSize=10GB
            If ($LASTEXITCODE -ne 0) { Throw "Could not resize shadow storage (exit code $LASTEXITCODE)." }
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
         If ($LASTEXITCODE -ne 0) { Throw "Could not enable the legacy boot menu (exit code $LASTEXITCODE)." }
            Write-Host "[$(timeStamp)] F8 legacy boot menu: enabled" -ForegroundColor Gray
    }

    If ( $Toggle -eq 'Disable' ) {
        bcdedit /set `{current`} BootMenuPolicy Standard | Out-Null
        If ($LASTEXITCODE -ne 0) { Throw "Could not restore the standard boot menu (exit code $LASTEXITCODE)." }
            Write-Host "[$(timeStamp)] F8 legacy boot menu: disabled" -ForegroundColor Gray
    }

} # End F8BootMenu Function

Function AppSuggestionAndInstallation {
    [CmdletBinding()]
    Param (
    [ValidateSet( 'Enable','Disable' )][String]$Toggle = 'Disable'
    )

    Initialize-RegistryKey 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
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
                  Initialize-RegistryKey "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
                }
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Type DWord -Value 0
                If (!( Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" )) {
                  Initialize-RegistryKey "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace"
                }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -Name "AllowSuggestedAppsInWindowsInkWorkspace" -Type DWord -Value 0

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
        [ValidateSet( 'Enable','Disable' )][String]$Toggle = 'Enable',
        [string]$Manufacturer = 'Omnis Computers',
        [string]$SupportPhone = '(518) 372-7829',
        [string]$SupportURL = 'https://www.omniscomputers.com',
        [string]$Logo = ''
    )

    If ( $Toggle -eq 'Enable' ) {
        $regKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
        Initialize-RegistryKey $regKey
        $regStrings = [ordered]@{ Logo=$Logo; Manufacturer=$Manufacturer; SupportPhone=$SupportPhone; SupportURL=$SupportURL }
        ForEach ($entry in $regStrings.GetEnumerator()) {
            If ([string]::IsNullOrWhiteSpace([string]$entry.Value)) {
                Remove-ItemProperty -Path $regKey -Name $entry.Key -ErrorAction SilentlyContinue
                Write-Host "[$(timeStamp)] OEM $($entry.Key): cleared." -ForegroundColor Gray
            } Else {
                New-ItemProperty -Path $regKey -Name $entry.Key -PropertyType String -Value ([string]$entry.Value) -Force | Out-Null
                Write-Host "[$(timeStamp)] OEM $($entry.Key): set to [$($entry.Value)]." -ForegroundColor Gray
            }
        }
        Write-Host "[$(timeStamp)] OEM information update complete." -ForegroundColor Cyan

    } # End If Toggle Enabled

    If ( $Toggle -eq 'Disable' ) { Write-Host "[$(timeStamp)] OEM info check: skipped." -ForegroundColor Gray }

} # End AddOEMInfo Function

Function BlockAutoDownload {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Enable'
    )

    If ( $Toggle -eq 'Enable' ) {
        Write-Host "[$(timeStamp)] Auto-download of apps from Store: blocked" -ForegroundColor Gray
        Initialize-RegistryKey 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore','HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -PropertyType DWord -Value 2 -Force | Out-Null
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -PropertyType DWord -Value 1 -Force | Out-Null
    }

    If ( $Toggle -eq 'Disable' ) {
        Write-Host "[$(timeStamp)] Auto-download block: skipped" -ForegroundColor Gray
    }
}

Function UserExperienceReporting {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Disable'
    )

    $path = 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'
    Initialize-RegistryKey $path
    If ( $Toggle -eq 'Enable' ) {
        Write-Host "[$(timeStamp)] User Experience Reporting (CEIP): enabled" -ForegroundColor Gray
        New-ItemProperty -Path $path -Name 'CEIPEnable' -PropertyType DWord -Value 1 -Force | Out-Null
    }

    If ( $Toggle -eq 'Disable' ) {
        Write-Host "[$(timeStamp)] User Experience Reporting (CEIP): disabled" -ForegroundColor Gray
        New-ItemProperty -Path $path -Name 'CEIPEnable' -PropertyType DWord -Value 0 -Force | Out-Null
    }
}

Function LoginAnimation {
    Param (
    [ValidateSet('Enable','Disable')]$Toggle = 'Disable'
    )

    $path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Initialize-RegistryKey $path
    If ( $Toggle -eq 'Enable' ) {
        Write-Host "[$(timeStamp)] First logon animation: enabled" -ForegroundColor Gray
        New-ItemProperty -Path $path -Name 'EnableFirstLogonAnimation' -PropertyType DWord -Value 1 -Force | Out-Null
    }

    If ( $Toggle -eq 'Disable' ) {
        Write-Host "[$(timeStamp)] First logon animation: disabled" -ForegroundColor Gray
        New-ItemProperty -Path $path -Name 'EnableFirstLogonAnimation' -PropertyType DWord -Value 0 -Force | Out-Null
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

        $cmdExplorer = { taskkill /f /im explorer.exe ; Start-Process explorer.exe }

            Switch ($converted_build) {
                "Win11" {
                    Write-Host "[$(timeStamp)] Win11 context menu reverted to classic. Build: [$current_build]" -ForegroundColor Cyan
                    $contextPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
                    Initialize-RegistryKey $contextPath
                    Set-Item -LiteralPath $contextPath -Value ''
                    & $cmdExplorer
                }
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
Function Invoke-WindowsInterfaceTweak {
    Param ([string[]]$Options = @('All'))
    Write-Host "[$(timeStamp)] Applying Windows interface and maintenance setting(s): $($Options -join ', ')." -ForegroundColor Cyan

    Function EnableStorageSense {
        $path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'
        Initialize-RegistryKey $path
        New-ItemProperty -Path $path -Name 'AllowStorageSenseGlobal' -PropertyType DWord -Value 1 -Force | Out-Null
        New-ItemProperty -Path $path -Name 'AllowStorageSenseTemporaryFilesCleanup' -PropertyType DWord -Value 1 -Force | Out-Null
        New-ItemProperty -Path $path -Name 'ConfigStorageSenseGlobalCadence' -PropertyType DWord -Value 30 -Force | Out-Null
        Write-Host "[$(timeStamp)] Storage Sense enabled with monthly cadence and temporary-file cleanup." -ForegroundColor Gray
    }

    Function StartComponentCleanup {
        $task = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Servicing\' -TaskName 'StartComponentCleanup' -ErrorAction Stop
        If ($task.State -eq 'Disabled') { Enable-ScheduledTask -InputObject $task | Out-Null }
        Start-ScheduledTask -InputObject $task
        Write-Host "[$(timeStamp)] Windows built-in component cleanup task started." -ForegroundColor Gray
    }

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

        If ((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).PCSystemType -eq 2) {
            Write-Host "[$(timeStamp)] Skipping the desktop network power setting on a laptop." -ForegroundColor Gray
            Return
        }
        $physicalNames = @(Get-NetAdapter -Physical -ErrorAction Stop | ForEach-Object Name)
        Write-Host "[$(timeStamp)] Querying supported network adapter power settings." -ForegroundColor Gray
        $adapterJob = Get-NetAdapterPowerManagement -Name '*' -AsJob -ErrorAction Stop
        Try {
            If (!(Wait-Job -Job $adapterJob -Timeout 15)) {
                Write-Warning "[$(timeStamp)] Network adapter power settings query timed out."
                Return
            }
            $adapters = @(Receive-Job -Job $adapterJob -ErrorAction Stop | Where-Object {
                $_.Name -in $physicalNames -and [string]$_.AllowComputerToTurnOffDevice -in @('Enabled','Disabled')
            })
        } Finally {
            Remove-Job -Job $adapterJob -Force -ErrorAction SilentlyContinue
        }
        If (!$adapters.Count) {
            Write-Host "[$(timeStamp)] No physical network adapters expose the power-off setting." -ForegroundColor Gray
            Return
        }
        $desired = If ($Disable) { 'Disabled' } Else { 'Enabled' }
        $failed = [Collections.Generic.List[string]]::new()
        ForEach ($adapter in $adapters) {
            Try {
                If ([string]$adapter.AllowComputerToTurnOffDevice -ne $desired) {
                    $adapter.AllowComputerToTurnOffDevice = $desired
                    Set-NetAdapterPowerManagement -InputObject $adapter -ErrorAction Stop
                }
                Write-Host "[$(timeStamp)] Adapter [$($adapter.Name)] automatic power-off: $desired." -ForegroundColor Gray
            } Catch { $failed.Add("[$($adapter.Name)]: $($_.Exception.Message.Trim())") }
        }
        If ($failed.Count) { Throw ($failed -join ' | ') }
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
                    Initialize-RegistryKey HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -PropertyType DWord -Value 0 -Force | Out-Null
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -PropertyType DWord -Value 1 -Force | Out-Null
            }
            "Category" {
              Write-Host "[$(timeStamp)] Control Panel view: Category" -ForegroundColor Gray
              If (!( Test-Path -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel )) {
                  Initialize-RegistryKey HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel
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
                    Initialize-RegistryKey HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People
                }
                New-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWord -Value 0 -Force | Out-Null
            }
            "Show" {
                Write-Host "[$(timeStamp)] People on taskbar: shown" -ForegroundColor Gray
                If (!( Test-Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People )) {
                    Initialize-RegistryKey HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People
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

    # Run all defaults for console mode, or one option at a time from the GUI.
    If ($Options -contains 'All' -or $Options -contains 'AppsSilentInstalling') { AppsSilentInstalling -Disable }
    If ($Options -contains 'All' -or $Options -contains 'AppsSmartScreen') { AppsSmartScreen -Enable }
    If ($Options -contains 'All' -or $Options -contains 'ControlPanelView') { ControlPanelView -LargeIcons }
    If ($Options -contains 'All' -or $Options -contains 'StorageSense') { EnableStorageSense }
    If ($Options -contains 'All' -or $Options -contains 'ComponentCleanup') { StartComponentCleanup }
    If ($Options -contains 'All' -or $Options -contains 'FoldersLaunchSeparateProcess') { FoldersLaunchSeparateProcess -Enable }
    If ($Options -contains 'All' -or $Options -contains 'NumLock') { NumLock -Enable }
    If ($Options -contains 'All' -or $Options -contains 'OpenFileExplorerTo') { OpenFileExplorerTo -ThisPC }
    If ($Options -contains 'All' -or $Options -contains 'PCTurnOffDevice') { PCTurnOffDevice -Disable }
    If ($Options -contains 'All' -or $Options -contains 'PeopleTaskbar') { PeopleTaskbar -Hide }
    If ($Options -contains 'All' -or $Options -contains 'TaskViewButton') { TaskViewButton -Hide }
    If ($Options -contains 'All' -or $Options -contains 'ThisPC') { ThisPC -Show }
    If ($Options -contains 'All' -or $Options -contains 'WindowsInkWorkspace') { WindowsInkWorkspace -Hide }
    If ($Options -contains 'All' -or $Options -contains 'WindowsManageDefaultPrinter') { WindowsManageDefaultPrinter -Disable }

} # End Invoke-WindowsInterfaceTweak Function

Function New-DailyRestorePoint {
    $markerPath = 'HKLM:\SOFTWARE\Aar318\New Computer Install'
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $lastDate = (Get-ItemProperty -LiteralPath $markerPath -Name LastRestorePointDate -ErrorAction SilentlyContinue).LastRestorePointDate
    If ($lastDate -eq $today) {
        Write-Host "[$(timeStamp)] A pre-change restore point was already attempted today; skipping." -ForegroundColor Gray
        Return
    }
    Try {
        Initialize-RegistryKey $markerPath
        New-ItemProperty -Path $markerPath -Name LastRestorePointDate -PropertyType String -Value $today -Force -ErrorAction Stop | Out-Null
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        $restoreWarnings = @()
        Checkpoint-Computer -Description "$($script:AppName) pre-change $today" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningVariable restoreWarnings
        If (!$restoreWarnings) { Write-Host "[$(timeStamp)] Created today's pre-change System Restore point." -ForegroundColor Cyan }
    } Catch {
        Write-Warning "[$(timeStamp)] Windows did not create a restore point: $($_.Exception.Message)"
    }
}

Function Set-PrivacySetting {
    Param ([ValidateSet('AdvertisingId','ActivityHistory','TailoredExperiences','DeliveryOptimization','Location')][string]$Setting)
    Switch ($Setting) {
        'AdvertisingId' {
            Initialize-RegistryKey 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
            New-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name Enabled -PropertyType DWord -Value 0 -Force | Out-Null
        }
        'ActivityHistory' {
            Initialize-RegistryKey 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
            New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name PublishUserActivities -PropertyType DWord -Value 0 -Force | Out-Null
            New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name UploadUserActivities -PropertyType DWord -Value 0 -Force | Out-Null
        }
        'TailoredExperiences' {
            Initialize-RegistryKey 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'
            New-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' -Name TailoredExperiencesWithDiagnosticDataEnabled -PropertyType DWord -Value 0 -Force | Out-Null
        }
        'DeliveryOptimization' {
            Initialize-RegistryKey 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
            New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' -Name DODownloadMode -PropertyType DWord -Value 0 -Force | Out-Null
        }
        'Location' {
            Initialize-RegistryKey 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
            New-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' -Name Value -PropertyType String -Value Deny -Force | Out-Null
        }
    }
    Write-Host "[$(timeStamp)] Privacy setting [$Setting] is disabled." -ForegroundColor Gray
}

Function Disable-WindowsAIFeatures {
    Param (
        [bool]$WindowsPolicies = $true,
        [bool]$EdgePolicies = $true,
        [bool]$NotepadPolicy = $true,
        [bool]$RemoveCopilotPackages = $false
    )

    $policies = [Collections.Generic.List[object]]::new()
    If ($WindowsPolicies) {
        $windowsAI='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
        ForEach ($name in @('DisableAIDataAnalysis','DisableClickToDo','TurnOffSavingSnapshots','DisableSettingsAgent','DisableAgentConnectors','DisableAgentWorkspaces','DisableRemoteAgentConnectors')) {
            $policies.Add(@($windowsAI,$name,1))
        }
        $policies.Add(@($windowsAI,'AllowRecallEnablement',0))
        $policies.Add(@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot','TurnOffWindowsCopilot',1))
        $policies.Add(@('HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot','TurnOffWindowsCopilot',1))
        $policies.Add(@('HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer','DisableSearchBoxSuggestions',1))
    }
    If ($EdgePolicies) {
        $edge='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        ForEach ($name in @('CopilotPageContext','EdgeEntraCopilotPageContext','Microsoft365CopilotChatIconEnabled','EdgeHistoryAISearchEnabled','ComposeInlineEnabled','BuiltInAIAPIsEnabled','AIGenThemesEnabled','ShareBrowsingHistoryWithCopilotSearchAllowed','AllowBrowsingWithCopilot','CopilotNewTabPageEnabled','M365LinksAutoOpenCopilotEnabled','CopilotAddressBarSuggestionsEnabled','CopilotCoworkToolActionsEnabled')) {
            $policies.Add(@($edge,$name,0))
        }
        $policies.Add(@($edge,'GenAILocalFoundationalModelSettings',1))
        $policies.Add(@($edge,'DevToolsGenAiSettings',2))
    }
    If ($NotepadPolicy) { $policies.Add(@('HKLM:\SOFTWARE\Policies\WindowsNotepad','DisableAIFeatures',1)) }

    ForEach ($policy in $policies) {
        Initialize-RegistryKey $policy[0]
        New-ItemProperty -Path $policy[0] -Name $policy[1] -PropertyType DWord -Value $policy[2] -Force | Out-Null
    }
    Write-Host "[$(timeStamp)] Applied [$($policies.Count)] machine/current-user Windows AI policies." -ForegroundColor Gray

    If ($RemoveCopilotPackages) {
        $packageNames=@('Microsoft.Copilot','MicrosoftWindows.Client.CoPilot','Microsoft.Windows.Ai.Copilot.Provider')
        $installed=@(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object Name -In $packageNames)
        ForEach ($package in $installed) {
            Write-Host "[$(timeStamp)] Removing Copilot package [$($package.Name)].." -ForegroundColor Gray
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction Continue
        }
        $provisioned=@(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -In $packageNames)
        ForEach ($package in $provisioned) {
            Write-Host "[$(timeStamp)] Removing provisioned Copilot package [$($package.DisplayName)].." -ForegroundColor Gray
            Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -AllUsers -ErrorAction Continue | Out-Null
        }
        Write-Host "[$(timeStamp)] Copilot Appx removal finished. CoreAI, CBS, Defender, files, and scheduled tasks were intentionally preserved." -ForegroundColor Cyan
    }
}

Function Set-DnsProvider {
    Param ([ValidateSet('Dynamic','Cloudflare','Quad9','Google','AdGuard')][string]$Provider = 'Dynamic')
    $servers = @{
        Cloudflare = @('1.1.1.1','1.0.0.1')
        Quad9 = @('9.9.9.9','149.112.112.112')
        Google = @('8.8.8.8','8.8.4.4')
        AdGuard = @('94.140.14.14','94.140.15.15')
    }
    $adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object Status -EQ Up)
    If (!$adapters) { Throw 'No active network adapters were found.' }
    ForEach ($adapter in $adapters) {
        If ($Provider -eq 'Dynamic') {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses -ErrorAction Stop
        } Else {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $servers[$Provider] -ErrorAction Stop
        }
        Write-Host "[$(timeStamp)] DNS [$Provider] applied to [$($adapter.Name)]." -ForegroundColor Gray
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

Function Repair-SystemFiles {
    Write-Host "[$(timeStamp)] Repairing the Windows component store with DISM.." -ForegroundColor Cyan
    & dism.exe /Online /Cleanup-Image /RestoreHealth
    If ($LASTEXITCODE -ne 0) { Throw "DISM returned exit code [$LASTEXITCODE]." }
    Write-Host "[$(timeStamp)] Verifying protected system files with SFC.." -ForegroundColor Cyan
    & sfc.exe /scannow
    If ($LASTEXITCODE -notin @(0,1,2)) { Throw "SFC returned exit code [$LASTEXITCODE]." }
}

Function Repair-WindowsUpdate {
    $services = @('bits','wuauserv','cryptsvc','msiserver')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Write-Host "[$(timeStamp)] Resetting Windows Update caches; existing data is retained as timestamped backups." -ForegroundColor Cyan
    Try {
        ForEach ($service in $services) { Stop-Service -Name $service -Force -ErrorAction SilentlyContinue }
        ForEach ($path in @((Join-Path $env:WINDIR 'SoftwareDistribution'),(Join-Path $env:WINDIR 'System32\catroot2'))) {
            If (Test-Path -LiteralPath $path) { Rename-Item -LiteralPath $path -NewName ((Split-Path $path -Leaf) + ".bak-$stamp") -ErrorAction Stop }
        }
    } Finally {
        ForEach ($service in $services) { Start-Service -Name $service -ErrorAction SilentlyContinue }
    }
    $uso = Join-Path $env:WINDIR 'System32\UsoClient.exe'
    If (Test-Path -LiteralPath $uso) { Start-Process -FilePath $uso -ArgumentList StartScan -WindowStyle Hidden }
}

Function Repair-NetworkStack {
    $failed = @(
        & ipconfig.exe /flushdns | Out-Host
        If ($LASTEXITCODE -ne 0) { 'DNS flush' }
        & netsh.exe winsock reset | Out-Host
        If ($LASTEXITCODE -ne 0) { 'Winsock reset' }
        & netsh.exe int ip reset | Out-Host
        If ($LASTEXITCODE -ne 0) { 'TCP/IP reset' }
    )
    If ($failed.Count) { Throw "Windows network repair failed for: $($failed -join ', ')." }
    Write-Host "[$(timeStamp)] Network stack reset completed; restart Windows before troubleshooting further." -ForegroundColor Yellow
}

Function Repair-WinGet {
    $package = Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    If (!$package) { Throw "Microsoft App Installer is not installed. Install it from Microsoft Store, then run this repair again." }
    $manifest = Join-Path $package.InstallLocation 'AppxManifest.xml'
    Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
    If (!(Get-Command winget.exe -ErrorAction SilentlyContinue)) { Throw 'App Installer was registered but WinGet is still unavailable. Sign out and back in, then retry.' }
    & winget.exe source reset --force
    $resetExitCode = $LASTEXITCODE
    & winget.exe source update
    If ($resetExitCode -ne 0 -or $LASTEXITCODE -ne 0) { Throw "WinGet source repair returned exit codes $resetExitCode (reset) and $LASTEXITCODE (update)." }
}

Function Get-DiagnosticSnapshot {
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $processors = @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed)
    $memory = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Select-Object Manufacturer,PartNumber,@{n='CapacityGB';e={[Math]::Round($_.Capacity/1GB,2)}},Speed)
    $volumes = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | Select-Object DeviceID,VolumeName,@{n='SizeGB';e={[Math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[Math]::Round($_.FreeSpace/1GB,2)}})
    $physicalDisks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object Model,InterfaceType,MediaType,@{n='SizeGB';e={[Math]::Round($_.Size/1GB,2)}})
    $network = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction SilentlyContinue | Select-Object Description,MACAddress,@{n='IPAddresses';e={$_.IPAddress -join ', '}},@{n='DnsServers';e={$_.DNSServerSearchOrder -join ', '}})
    $stoppedAuto = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto'" -ErrorAction SilentlyContinue | Where-Object State -NE Running | Select-Object Name,DisplayName,State)
    $pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    $lastBoot = $os.LastBootUpTime
    $uptime = If ($lastBoot) { (New-TimeSpan -Start $lastBoot -End (Get-Date)).ToString() } Else { 'Unavailable' }
    [pscustomobject]@{
        Generated = (Get-Date).ToString('o')
        Computer = [pscustomobject]@{ Name=$env:COMPUTERNAME; Manufacturer=$computer.Manufacturer; Model=$computer.Model; Domain=$computer.Domain; TotalMemoryGB=[Math]::Round($computer.TotalPhysicalMemory/1GB,2) }
        OperatingSystem = [pscustomobject]@{ Caption=$os.Caption; Version=$os.Version; Build=$os.BuildNumber; Architecture=$os.OSArchitecture; LastBoot=$lastBoot; Uptime=$uptime; PendingReboot=$pendingReboot }
        BIOS = [pscustomobject]@{ Manufacturer=$bios.Manufacturer; Version=($bios.SMBIOSBIOSVersion -join ', '); SerialNumber=$bios.SerialNumber; ReleaseDate=$bios.ReleaseDate }
        Processors = $processors
        MemoryModules = $memory
        Volumes = $volumes
        PhysicalDisks = $physicalDisks
        Network = $network
        StoppedAutomaticServices = $stoppedAuto
        Tools = [pscustomobject]@{ PowerShell=$PSVersionTable.PSVersion.ToString(); WinGet=$(If(Get-Command winget.exe -ErrorAction SilentlyContinue){& winget.exe --version}else{'Not installed'}); Chocolatey=$(If(Get-Command choco.exe -ErrorAction SilentlyContinue){& choco.exe --version}else{'Not installed'}) }
    }
}

Function Get-DiagnosticSummaryText {
    Param ([object]$Snapshot)
    $snapshot = If ($Snapshot) { $Snapshot } Else { Get-DiagnosticSnapshot }
    $volumeText = @($snapshot.Volumes | ForEach-Object { '{0} {1}/{2} GB free' -f $_.DeviceID,$_.FreeGB,$_.SizeGB }) -join '; '
    @(
        "$($snapshot.Computer.Manufacturer) $($snapshot.Computer.Model)"
        "Computer: $($snapshot.Computer.Name)   RAM: $($snapshot.Computer.TotalMemoryGB) GB"
        "OS: $($snapshot.OperatingSystem.Caption) build $($snapshot.OperatingSystem.Build)"
        "Uptime: $($snapshot.OperatingSystem.Uptime)   Pending reboot: $($snapshot.OperatingSystem.PendingReboot)"
        "CPU: $((@($snapshot.Processors.Name) -join '; '))"
        "Volumes: $volumeText"
        "Stopped automatic services: $(@($snapshot.StoppedAutomaticServices).Count)"
    ) -join [Environment]::NewLine
}

Function Export-DiagnosticReport {
    Param ([string]$OutputPath = 'C:\Omnis')
    If ([string]::IsNullOrWhiteSpace($OutputPath)) { Throw 'Choose an output folder for the diagnostics report.' }
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    $snapshot = Get-DiagnosticSnapshot
    $stamp = Get-Date -Format 'yyyy-MM-dd'
    $baseName = "Aar318s-System-Report-$($env:COMPUTERNAME)-$stamp"
    $jsonPath = Join-Path $OutputPath "$baseName.json"
    $htmlPath = Join-Path $OutputPath "$baseName.html"
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    $sections = [Collections.Generic.List[string]]::new()
    ForEach ($property in $snapshot.PSObject.Properties) {
        If ($property.Name -eq 'Generated') { Continue }
        $rows = @($property.Value)
        $fragment = $rows | ConvertTo-Html -Fragment -PreContent "<h2>$([Net.WebUtility]::HtmlEncode($property.Name))</h2>"
        $sections.Add("<section class='report-card'>$($fragment -join [Environment]::NewLine)</section>")
    }
    $style = @'
*{box-sizing:border-box}html{background:#0b1120}body{font-family:"Segoe UI",Arial,sans-serif;background:#0b1120;color:#e5e7eb;margin:0;line-height:1.45}.page{max-width:1500px;margin:0 auto;padding:28px}.hero{background:linear-gradient(135deg,#111827 0%,#172554 55%,#0f766e 140%);border:1px solid #334155;border-radius:18px;padding:28px 30px;box-shadow:0 18px 50px rgba(0,0,0,.25);margin-bottom:22px}.eyebrow{color:#22d3ee;font-size:13px;font-weight:700;letter-spacing:.12em;text-transform:uppercase}.brand-row{display:flex;align-items:flex-end;justify-content:space-between;gap:20px;flex-wrap:wrap}h1{font-size:32px;line-height:1.15;margin:7px 0 5px;color:#f8fafc}.version{color:#4ade80;font-size:14px;font-weight:700}.muted{color:#94a3b8}.support{display:flex;gap:10px;margin-top:12px}.button{display:inline-block;text-decoration:none;border-radius:9px;padding:9px 16px;font-weight:700;color:#fff}.kofi{background:#2f7dd1}.donate{background:#facc15;color:#111827}.report-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(440px,1fr));gap:16px;align-items:start}.report-card{min-width:0;background:#111827;border:1px solid #263449;border-radius:14px;padding:18px;box-shadow:0 8px 24px rgba(0,0,0,.18);overflow:auto}.report-card h2{margin:0 0 13px;color:#86efac;font-size:20px}table{border-collapse:separate;border-spacing:0;width:100%;min-width:420px;background:#172033;border:1px solid #334155;border-radius:9px;overflow:hidden}th,td{padding:9px 11px;border-right:1px solid #334155;border-bottom:1px solid #334155;text-align:left;vertical-align:top;overflow-wrap:anywhere}th{background:#263449;color:#f8fafc;font-weight:700}tr:last-child td{border-bottom:0}th:last-child,td:last-child{border-right:0}tr:nth-child(even) td{background:#141e30}@media(max-width:700px){.page{padding:14px}.hero{padding:21px}.report-grid{grid-template-columns:1fr}h1{font-size:26px}}
'@
    $generated = [Net.WebUtility]::HtmlEncode((Get-Date).ToString('F',[Globalization.CultureInfo]::CurrentCulture))
    $appName = [Net.WebUtility]::HtmlEncode($script:AppName)
    $html = "<!doctype html><html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><meta name='viewport' content='width=device-width,initial-scale=1'><title>$appName report</title><style>$style</style></head><body><main class='page'><header class='hero'><div class='eyebrow'>Hardware &amp; health report</div><div class='brand-row'><div><h1>$appName</h1><div class='version'>v$($script:AppVersion) by Hor318</div><div class='muted'>Generated $generated</div></div><nav class='support'><a class='button kofi' href='$($script:KoFiUrl)'>Ko-fi</a><a class='button donate' href='$($script:DonateUrl)'>Donate</a></nav></div></header><div class='report-grid'>$($sections -join [Environment]::NewLine)</div></main></body></html>"
    Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8
    $olderReports = @(Get-ChildItem -LiteralPath $OutputPath -Filter "Aar318s-System-Report-$($env:COMPUTERNAME)-*.html" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip 3)
    ForEach ($oldReport in $olderReports) {
        Remove-Item -LiteralPath $oldReport.FullName -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath ([IO.Path]::ChangeExtension($oldReport.FullName,'.json')) -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[$(timeStamp)] Diagnostics report: [$htmlPath]" -ForegroundColor Cyan
    Write-Host "[$(timeStamp)] Machine-readable report: [$jsonPath]" -ForegroundColor Gray
    Return $htmlPath
}

Function Get-LatestDiagnosticReport {
    Param ([string]$OutputPath)
    If ([string]::IsNullOrWhiteSpace($OutputPath) -or !(Test-Path -LiteralPath $OutputPath -PathType Container)) { Return $null }
    Return Get-ChildItem -LiteralPath $OutputPath -Filter 'Aar318s-System-Report-*.html' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

Function Get-CachedDiagnosticSnapshot {
    Param ([string]$OutputPath)
    $htmlPath = Get-LatestDiagnosticReport -OutputPath $OutputPath
    If (!$htmlPath) { Return $null }
    $jsonPath = [IO.Path]::ChangeExtension($htmlPath,'.json')
    If (!(Test-Path -LiteralPath $jsonPath -PathType Leaf)) { Return $null }
    Return Get-Content -LiteralPath $jsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

Function Get-RegistryValueState {
    Param ([string]$Path,[string]$Name,[object]$Expected)
    $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    If ($null -eq $item) { Return 'Not applied' }
    If ([string]$item.$Name -eq [string]$Expected) { Return 'Applied' }
    Return 'Different'
}

Function Get-ActionState {
    Param ([string]$ActionId)
    Try {
        If ($ActionId -eq 'NewsTaskbar' -and !(Test-NewsAndInterestsPolicy)) { Return 'Unavailable (Windows 10 policy)' }
        $states = @{
            IPv6=@('HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters','DisabledComponents',32)
            FastStartup=@('HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power','HiberbootEnabled',0)
            LongPaths=@('HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem','LongPathsEnabled',1)
            FileExtensions=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced','HideFileExt',0)
            CEIP=@('HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows','CEIPEnable',0)
            PrivacyAdvertisingId=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo','Enabled',0)
            PrivacyActivityHistory=@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\System','PublishUserActivities',0)
            PrivacyTailoredExperiences=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy','TailoredExperiencesWithDiagnosticDataEnabled',0)
            PrivacyDeliveryOptimization=@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization','DODownloadMode',0)
            PrivacyLocation=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location','Value','Deny')
            AppSuggestions=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager','ContentDeliveryAllowed',0)
            StartSuggestions=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager','SubscribedContent-338388Enabled',0)
            StoreAutoDownload=@('HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore','AutoDownload',2)
            AutoArrange=@('HKCU:\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop','FFLAGS',1075839525)
            VerboseStatus=@('HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System','VerboseStatus',1)
            LoginAnimation=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System','EnableFirstLogonAnimation',0)
            NewsTaskbar=@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds','EnableFeeds',0)
            MeetNow=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer','HideSCAMeetNow',1)
            LockShutdown=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System','ShutdownWithoutLogon',1)
            AppsSmartScreen=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer','SmartScreenEnabled','Warn')
            ControlPanelView=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel','StartupPage',1)
            SeparateExplorer=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced','SeparateProcess',1)
            NumLock=@('Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard','InitialKeyboardIndicators','2147483650')
            ExplorerThisPC=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced','LaunchTo',1)
            PeopleTaskbar=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People','PeopleBand',0)
            TaskView=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced','ShowTaskViewButton',0)
            ThisPCDesktop=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel','{20D04FE0-3AEA-1069-A2D8-08002B30309D}',0)
            InkWorkspace=@('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace','PenWorkspaceButtonDesiredVisibility',0)
            DefaultPrinter=@('HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows','LegacyDefaultPrinterMode',1)
            SilentApps=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager','SilentInstalledAppsEnabled',0)
            StorageSense=@('HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense','AllowStorageSenseGlobal',1)
        }
        If ($states.ContainsKey($ActionId)) {
            $state = $states[$ActionId]
            Return (Get-RegistryValueState -Path $state[0] -Name $state[1] -Expected $state[2])
        }
        Switch ($ActionId) {
            'PowerPlan' { $active=& powercfg.exe /getactivescheme | Out-String; $pattern=If($script:RunOptions.PowerPlan -eq 'HighPerformance'){'High performance|8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'}Else{'Balanced|381b4222-f694-41f0-9685-ff5bb260df2e'}; Return $(If($active -match $pattern){'Applied'}Else{'Different'}) }
            'TimeZone' { Return $(If((Get-TimeZone).Id -eq "$($script:RunOptions.TimeZone) Standard Time"){'Applied'}Else{'Different'}) }
            'UpdateHours' {
                $settings=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' -ErrorAction SilentlyContinue
                $expectedStart=Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursStart -Default 20
                $expectedEnd=Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursEnd -Default 5
                Return $(If([int]$settings.ActiveHoursStart -eq $expectedStart -and [int]$settings.ActiveHoursEnd -eq $expectedEnd){'Applied'}Else{'Different'})
            }
            'RenameComputer' { If(!$script:RunOptions.ComputerName){Return 'Needs input'}; Return $(If($env:COMPUTERNAME -ieq $script:RunOptions.ComputerName){'Applied'}Else{'Different'}) }
            'Prerequisites' {
                $checks=@()
                If($script:RunOptions.PrerequisiteItems -contains 'WinGet'){$checks += [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)}
                If($script:RunOptions.PrerequisiteItems -contains 'Chocolatey'){$checks += [bool](Get-Command choco.exe -ErrorAction SilentlyContinue)}
                If(@($checks).Count -eq 0){Return 'Check on run'}
                $ready=@($checks|Where-Object {$_}).Count
                If($ready -eq $checks.Count){Return 'Ready'}
                If($ready -gt 0){Return "Partial ($ready/$($checks.Count) managers ready)"}
                Return 'Not applied'
            }
            'AdGuard' {
                $checks=@()
                If($script:RunOptions.InstallAdGuardChrome){$checks += ((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist' -Name 318 -ErrorAction SilentlyContinue).'318' -like 'bgnkhhnnamicmpeenaelnjfhikgbkllg;*')}
                If($script:RunOptions.InstallAdGuardEdge){$checks += ((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist' -Name 318 -ErrorAction SilentlyContinue).'318' -like 'pdffkfellgipmhklpdmokmckkkfcopbh;*')}
                If(@($checks).Count -eq 0){Return 'Check on run'}
                $applied=@($checks|Where-Object {$_}).Count
                If($applied -eq $checks.Count){Return 'Applied'}
                If($applied -gt 0){Return "Partial ($applied/$($checks.Count) browsers)"}
                Return 'Not applied'
            }
            'DNS' {
                If($script:RunOptions.DnsProvider -eq 'Dynamic'){
                    $static=@(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -EQ Up | ForEach-Object { (Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($_.InterfaceGuid)" -Name NameServer -ErrorAction SilentlyContinue).NameServer } | Where-Object {$_})
                    Return $(If($static){'Different'}Else{'Applied (Dynamic)'})
                }
                $expected=@{Cloudflare='1.1.1.1';Quad9='9.9.9.9';Google='8.8.8.8';AdGuard='94.140.14.14'}[$script:RunOptions.DnsProvider]
                $addresses=@(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.ServerAddresses} | ForEach-Object ServerAddresses)
                Return $(If($addresses -contains $expected){'Applied'}Else{'Different'})
            }
            'WindowsAI' {
                $checks=@()
                If($script:RunOptions.DisableWindowsAIPolicies){
                    $windowsAI=Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -ErrorAction SilentlyContinue
                    $checks += ($windowsAI.DisableAIDataAnalysis -eq 1 -and $windowsAI.AllowRecallEnablement -eq 0 -and $windowsAI.TurnOffSavingSnapshots -eq 1)
                }
                If($script:RunOptions.DisableEdgeAIPolicies){$checks += ((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' -ErrorAction SilentlyContinue).CopilotPageContext -eq 0)}
                If($script:RunOptions.DisableNotepadAI){$checks += ((Get-ItemProperty 'HKLM:\SOFTWARE\Policies\WindowsNotepad' -ErrorAction SilentlyContinue).DisableAIFeatures -eq 1)}
                If($script:RunOptions.RemoveCopilotPackages){$checks += (@(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object Name -In @('Microsoft.Copilot','MicrosoftWindows.Client.CoPilot','Microsoft.Windows.Ai.Copilot.Provider')).Count -eq 0)}
                If(!$checks.Count){Return 'Needs input'}
                $applied=@($checks|Where-Object {$_}).Count
                If($applied -eq $checks.Count){Return 'Applied'}
                If($applied -gt 0){Return "Partial ($applied/$($checks.Count) settings)"}
                Return 'Not applied'
            }
            'RemoveMcAfee' { $found=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object DisplayName -Match 'McAfee|WebAdvisor' | Select-Object -First 1; Return $(If($found){'Detected'}Else{'Clean'}) }
            Default { Return 'Check on run' }
        }
    } Catch { Return 'Unavailable' }
}

Function New-InstallerAction {
    Param (
        [string]$Category,
        [string]$Id,
        [string]$Name,
        [string]$Description,
        [bool]$Reversible,
        [scriptblock]$Command
    )
    [pscustomobject]@{ Category=$Category; Id=$Id; Name=$Name; Description=$Description; Reversible=$Reversible; Command=$Command }
}

Function Get-ActionCatalog {
    @(
        New-InstallerAction 'Setup' 'Prerequisites' 'Install / update prerequisites' 'Prepares the package managers and PowerShell modules this tool needs. WinGet is preferred; Chocolatey remains available as a fallback.' $false { PreRequisites -Items @($script:RunOptions.PrerequisiteItems) }
        New-InstallerAction 'Setup' 'Weather' 'Show local weather' 'Displays wttr.in''s detailed current-day forecast in the console and caches it in the GUI, including morning, noon, evening, and night conditions.' $false { myWeather }
        New-InstallerAction 'Diagnostics' 'DiagnosticsReport' 'Create hardware and health report' 'Collects hardware, Windows, disk, network, service, and restart information using CIM, then exports readable HTML and machine-readable JSON reports.' $false { Export-DiagnosticReport -OutputPath ([string]$script:RunOptions.ReportOutputPath) }
        New-InstallerAction 'Hardware' 'DeviceHealth' 'Repair devices and missing drivers' 'Checks Plug and Play problems, matches available drivers to the current hardware, and reports unresolved devices.' $false { PnPDevices }
        New-InstallerAction 'Hardware' 'OEMInfo' 'Set OEM support information' 'Prefills detected values and lets you edit the manufacturer, support details, and logo.' $true { AddOEMInfo -Toggle Enable -Manufacturer $script:RunOptions.OEMManufacturer -SupportPhone $script:RunOptions.OEMSupportPhone -SupportURL $script:RunOptions.OEMSupportURL -Logo $script:RunOptions.OEMLogo }
        New-InstallerAction 'Software' 'BaseSoftware' 'Install / update common software' 'Installs common applications through WinGet first, with Chocolatey fallback. Java uses Eclipse Temurin, a free OpenJDK Java runtime.' $false { ChocoSoftware -Packages @($script:RunOptions.SoftwarePackages) -IncludeGpuDrivers ([bool]$script:RunOptions.InstallGpuDrivers) }
        New-InstallerAction 'Software' 'DefaultApps' 'Provision Chrome and Adobe defaults' 'Sets Chrome for web links and Adobe Reader for PDF files for every new Windows profile.' $true { Set-DefaultApplicationsForNewProfiles -Chrome ([bool]$script:RunOptions.SetChromeDefault) -AdobePdf ([bool]$script:RunOptions.SetAdobePdfDefault) }
        New-InstallerAction 'Software' 'AdGuard' 'Install AdGuard for Chrome and Edge' 'Uses machine browser policies so AdGuard installs for current and future browser profiles.' $true { Install-AdGuardBrowserPolicies -Chrome ([bool]$script:RunOptions.InstallAdGuardChrome) -Edge ([bool]$script:RunOptions.InstallAdGuardEdge) }
        New-InstallerAction 'Software' 'WindowsUpdates' 'Install Windows and driver updates' 'Runs PSWindowsUpdate and checks the configured Windows Update source for drivers.' $false { WindowUpdatesInstall }
        New-InstallerAction 'Software' 'PhotoViewer' 'Restore classic Windows Photo Viewer' 'Registers classic Photo Viewer and common image associations.' $false { WindowsPhotoViewer -Restore Enable }
        New-InstallerAction 'Software' 'RemoveBloatware' 'Remove bundled bloatware' 'Safely targets known consumer and promotional Store apps instead of removing unknown Windows components.' $false { RemoveBloatware }
        New-InstallerAction 'Software' 'RemoveMcAfee' 'Remove McAfee products' 'Runs registered McAfee and WebAdvisor uninstallers and removes provisioned McAfee Store packages.' $false { Remove-McAfeeProducts }
        New-InstallerAction 'Software' 'RemoveWidgets' 'Remove Windows 11 Widgets' 'Uninstalls Windows Web Experience Pack on Windows 11.' $false { Win11Widgets -Status Disable }
        New-InstallerAction 'System' 'TimeZone' 'Set time zone and NIST time source' 'Sets the selected US time zone and uses time.nist.gov to keep the Windows clock synchronized.' $true { setTimeZone -myTimeZone ([string]$script:RunOptions.TimeZone) }
        New-InstallerAction 'System' 'PowerPlan' 'Set Windows power plan' 'Uses High Performance by default; Balanced remains available for laptops and Modern Standby systems.' $true { Set-PowerPlan -Plan ([string]$script:RunOptions.PowerPlan) }
        New-InstallerAction 'System' 'IPv6' 'Prefer IPv4 while keeping IPv6 enabled' 'Uses Microsoft''s recommended prefix preference instead of disabling required Windows IPv6 components.' $true { PreferIPv4OverIPv6 }
        New-InstallerAction 'System' 'DNS' 'Configure DNS provider' 'Defaults to Dynamic/DHCP for business networks; Cloudflare, Quad9, Google, and AdGuard DNS are optional.' $true { Set-DnsProvider -Provider ([string]$script:RunOptions.DnsProvider) }
        New-InstallerAction 'System' 'FastStartup' 'Disable Fast Startup' 'Turns off the hybrid shutdown cache that saves part of the Windows session. This gives each shutdown a clean boot and can prevent driver, update, dual-boot, and encrypted-disk problems.' $true { DisableFastStartup }
        New-InstallerAction 'System' 'LongPaths' 'Enable Win32 long paths' 'Removes the legacy MAX_PATH limit for compatible applications; some processes may require a restart.' $true { EnableLongPaths }
        New-InstallerAction 'System' 'RestorePoints' 'Enable System Restore' 'Allows Windows to roll system files and settings back after a bad driver, update, or configuration change; reserves up to 10 GB for restore data.' $false { EnableRestorePoints -RestorePoints Enable; Set-ItemProperty -Path $script:RegistryPath -Name SystemRestorePointCreationFrequency -Value 1440 -Force }
        New-InstallerAction 'System' 'F8BootMenu' 'Enable legacy F8 boot menu' 'Restores the older F8 startup shortcut for Safe Mode and advanced recovery options; it may slightly lengthen startup.' $false { F8BootMenu -Toggle Enable }
        New-InstallerAction 'System' 'RenameComputer' 'Rename this computer' 'Uses the entered name, or prompts in console mode when Windows still has a DESKTOP or WIN- name.' $true { GetComputerName -NewPCName ([string]$script:RunOptions.ComputerName) }
        New-InstallerAction 'Windows' 'AppSuggestions' 'Disable app suggestions and auto-install' 'Disables OEM, subscription, silent, and suggested app delivery.' $true { AppSuggestionAndInstallation -Toggle Disable }
        New-InstallerAction 'Windows' 'StartSuggestions' 'Disable Start menu suggestions' 'Disables suggested content in Start.' $true { DisableShowSuggestions }
        New-InstallerAction 'Windows' 'StoreAutoDownload' 'Block automatic Store app downloads' 'Stops Windows from automatically downloading promoted consumer apps while leaving manual Microsoft Store installs available.' $true { BlockAutoDownload -Toggle Enable }
        New-InstallerAction 'Windows' 'AutoArrange' 'Auto-arrange desktop icons' 'Enables auto-arrange and align-to-grid.' $true { AutoArrange -enable $true }
        New-InstallerAction 'Windows' 'VerboseStatus' 'Enable verbose sign-in status' 'Shows detailed startup, sign-in, and shutdown status messages.' $true { EnableVerboseStatus -VerboseLoginStatus Enable }
        New-InstallerAction 'Windows' 'LoginAnimation' 'Disable first sign-in animation' 'Disables the first-logon welcome animation.' $true { LoginAnimation -Toggle Disable }
        New-InstallerAction 'Windows' 'NewsTaskbar' 'Hide News and Interests' 'Disables the legacy News and Interests taskbar feed on supported Windows 10 editions.' $true { NewsAndInterestsTaskbar -Hide }
        New-InstallerAction 'Windows' 'MeetNow' 'Hide Meet Now' 'Hides Meet Now through Explorer policy.' $true { RemoveMeetNow }
        New-InstallerAction 'Windows' 'ClassicContextMenu' 'Use classic Windows 10 context menu' 'Restores the full Windows 10-style context menu on Windows 11.' $true { RevertContextMenuW11 -RestoreMenu Enable }
        New-InstallerAction 'Windows' 'UpdateHours' 'Set Windows Update active hours' 'Sets the hours when Windows should avoid automatic restarts. Leave both fields blank to retain this tool''s 8 PM through 5 AM default.' $true { SetWindowsUpdateHours -startTime (Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursStart -Default 20) -endTime (Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursEnd -Default 5) }
        New-InstallerAction 'Windows' 'LockNetwork' 'Show network control on lock screen' 'Allows network selection on the lock screen.' $true { ShowNetworkOnScreen -ShowNetworkOnScreen Show }
        New-InstallerAction 'Windows' 'LockShutdown' 'Show shutdown control on lock screen' 'Allows shutdown from the lock screen.' $true { ShowShutdownOnLockScreen -ShowShutdownOnLockScreen Show }
        New-InstallerAction 'Windows' 'CEIP' 'Disable experience reporting' 'Disables Windows Customer Experience Improvement reporting.' $true { UserExperienceReporting -Toggle Disable }
        New-InstallerAction 'Privacy' 'PrivacyAdvertisingId' 'Disable advertising ID' 'Turns off the per-user Windows advertising identifier.' $true { Set-PrivacySetting AdvertisingId }
        New-InstallerAction 'Privacy' 'PrivacyActivityHistory' 'Disable activity-history publishing' 'Stops Windows from publishing and uploading user activity history while leaving clipboard features available.' $true { Set-PrivacySetting ActivityHistory }
        New-InstallerAction 'Privacy' 'PrivacyTailoredExperiences' 'Disable tailored experiences' 'Stops Windows from using diagnostic data for personalized tips and recommendations.' $true { Set-PrivacySetting TailoredExperiences }
        New-InstallerAction 'Privacy' 'PrivacyDeliveryOptimization' 'Disable peer-to-peer update sharing' 'Downloads updates directly instead of sharing Windows Update content with other PCs.' $true { Set-PrivacySetting DeliveryOptimization }
        New-InstallerAction 'Privacy' 'PrivacyLocation' 'Disable Windows location access' 'Denies Windows location capability by default; omit this option when business workflows require location services.' $true { Set-PrivacySetting Location }
        New-InstallerAction 'Optional' 'WindowsAI' 'Disable/remove Windows AI features' 'Opt-in, business-safe subset inspired by RemoveWindowsAI: applies Copilot, Recall, Edge, and Notepad policies, with optional Copilot Appx removal. It does not delete CBS packages, Defender components, system files, or scheduled tasks.' $false { Disable-WindowsAIFeatures -WindowsPolicies ([bool]$script:RunOptions.DisableWindowsAIPolicies) -EdgePolicies ([bool]$script:RunOptions.DisableEdgeAIPolicies) -NotepadPolicy ([bool]$script:RunOptions.DisableNotepadAI) -RemoveCopilotPackages ([bool]$script:RunOptions.RemoveCopilotPackages) }
        New-InstallerAction 'Interface' 'AppsSmartScreen' 'Keep Microsoft Defender SmartScreen enabled' 'Warns about unrecognized downloaded applications instead of removing this security layer.' $true { Invoke-WindowsInterfaceTweak -Options AppsSmartScreen }
        New-InstallerAction 'Interface' 'ControlPanelView' 'Use large icons in Control Panel' 'Opens Control Panel to all items with large icons.' $true { Invoke-WindowsInterfaceTweak -Options ControlPanelView }
        New-InstallerAction 'Interface' 'SeparateExplorer' 'Launch folders in separate processes' 'Improves Explorer isolation at the cost of a little memory.' $true { Invoke-WindowsInterfaceTweak -Options FoldersLaunchSeparateProcess }
        New-InstallerAction 'Interface' 'NumLock' 'Enable Num Lock at startup' 'Enables Num Lock for the default sign-in profile.' $true { Invoke-WindowsInterfaceTweak -Options NumLock }
        New-InstallerAction 'Interface' 'ExplorerThisPC' 'Open File Explorer to This PC' 'Changes the default Explorer landing page.' $true { Invoke-WindowsInterfaceTweak -Options OpenFileExplorerTo }
        New-InstallerAction 'Interface' 'FileExtensions' 'Show file name extensions' 'Shows known file extensions in File Explorer for clearer file identification.' $true { ShowFileExtensions }
        New-InstallerAction 'Interface' 'NetworkPower' 'Keep network adapters powered' 'Prevents Windows from powering off supported network adapters to save energy, which can help with dropped connections and wake-from-sleep issues.' $false { Invoke-WindowsInterfaceTweak -Options PCTurnOffDevice }
        New-InstallerAction 'Interface' 'PeopleTaskbar' 'Hide People on the taskbar' 'Hides the legacy People taskbar button.' $true { Invoke-WindowsInterfaceTweak -Options PeopleTaskbar }
        New-InstallerAction 'Interface' 'TaskView' 'Hide Task View button' 'Hides Task View from the taskbar.' $true { Invoke-WindowsInterfaceTweak -Options TaskViewButton }
        New-InstallerAction 'Interface' 'ThisPCDesktop' 'Show This PC on the desktop' 'Shows the This PC desktop icon.' $true { Invoke-WindowsInterfaceTweak -Options ThisPC }
        New-InstallerAction 'Interface' 'InkWorkspace' 'Hide Windows Ink Workspace' 'Hides the Windows Ink Workspace button.' $true { Invoke-WindowsInterfaceTweak -Options WindowsInkWorkspace }
        New-InstallerAction 'Interface' 'DefaultPrinter' 'Stop Windows managing the default printer' 'Keeps the user-selected default printer.' $true { Invoke-WindowsInterfaceTweak -Options WindowsManageDefaultPrinter }
        New-InstallerAction 'Interface' 'SilentApps' 'Disable silent suggested-app installs' 'Disables silent installation of suggested apps.' $true { Invoke-WindowsInterfaceTweak -Options AppsSilentInstalling }
        New-InstallerAction 'Maintenance' 'StorageSense' 'Enable monthly Storage Sense cleanup' 'Uses the supported Windows policy to clean temporary files monthly.' $true { Invoke-WindowsInterfaceTweak -Options StorageSense }
        New-InstallerAction 'Maintenance' 'ComponentCleanup' 'Start Windows component cleanup' 'Runs Windows built-in servicing cleanup to remove superseded update components and reclaim disk space; it can take several minutes.' $false { Invoke-WindowsInterfaceTweak -Options ComponentCleanup }
        New-InstallerAction 'Maintenance' 'RefreshExplorer' 'Restart Windows Explorer' 'Refreshes settings that require Explorer to restart.' $false { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Process explorer.exe }
        New-InstallerAction 'Repair' 'RepairSystemFiles' 'Repair Windows system files' 'Runs DISM component-store repair followed by System File Checker.' $false { Repair-SystemFiles }
        New-InstallerAction 'Repair' 'RepairWindowsUpdate' 'Reset Windows Update components' 'Stops update services, preserves the existing caches as timestamped backups, restarts services, and starts a new scan.' $false { Repair-WindowsUpdate }
        New-InstallerAction 'Repair' 'RepairNetwork' 'Reset the Windows network stack' 'Flushes DNS and resets Winsock and TCP/IP; a restart is recommended afterward.' $false { Repair-NetworkStack }
        New-InstallerAction 'Repair' 'RepairWinGet' 'Repair WinGet / App Installer' 'Re-registers Microsoft App Installer and refreshes WinGet sources.' $false { Repair-WinGet }
    )
}

Function Get-PresetActionIds {
    Param ([object[]]$Catalog,[ValidateSet('Full','Minimal','Custom')][string]$Name = 'Full')
    If ($Name -eq 'Custom') { Return @() }
    If ($Name -eq 'Full') { Return @($Catalog | Where-Object { $_.Category -notin @('Repair','Diagnostics','Optional') } | ForEach-Object Id) }
    $minimal = @(
        'Prerequisites','DeviceHealth','OEMInfo','BaseSoftware','DefaultApps','AdGuard','WindowsUpdates','PhotoViewer','RemoveBloatware','RemoveMcAfee',
        'TimeZone','PowerPlan','DNS','FastStartup','LongPaths','RestorePoints','RenameComputer','AppSuggestions','StartSuggestions','StoreAutoDownload',
        'LoginAnimation','NewsTaskbar','MeetNow','ClassicContextMenu','CEIP','PrivacyAdvertisingId','PrivacyActivityHistory','PrivacyTailoredExperiences',
        'PrivacyDeliveryOptimization','PrivacyLocation','AppsSmartScreen','NumLock','ExplorerThisPC','FileExtensions','DefaultPrinter','SilentApps','StorageSense','ComponentCleanup','RefreshExplorer'
    )
    Return @($Catalog | Where-Object Id -In $minimal | ForEach-Object Id)
}

Function New-RegistrySpec {
    Param ([string]$Path,[string[]]$Names)
    [pscustomobject]@{ Path=$Path; Names=$Names }
}

Function Get-RegistryBackupSpecs {
    $contentDelivery = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    @{
        OEMInfo = @(New-RegistrySpec 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation' @('Logo','Manufacturer','SupportPhone','SupportURL'))
        AdGuard = @(
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist' @('318')
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist' @('318')
        )
        TimeZone = @(New-RegistrySpec 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters' @('NtpServer','Type'))
        IPv6 = @(New-RegistrySpec 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' @('DisabledComponents'))
        FastStartup = @(New-RegistrySpec 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' @('HiberbootEnabled'))
        LongPaths = @(New-RegistrySpec 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' @('LongPathsEnabled'))
        AppSuggestions = @(
            New-RegistrySpec $contentDelivery @('ContentDeliveryAllowed','OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','PreInstalledAppsEverEnabled','SilentInstalledAppsEnabled','SubscribedContent-310093Enabled','SubscribedContent-314559Enabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled','SubscribedContent-338393Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled','SubscribedContent-353698Enabled','SystemPaneSuggestionsEnabled')
            New-RegistrySpec 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' @('ScoobeSystemSettingEnabled')
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' @('AllowSuggestedAppsInWindowsInkWorkspace')
        )
        StartSuggestions = @(New-RegistrySpec $contentDelivery @('SubscribedContent-338388Enabled'))
        StoreAutoDownload = @(
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' @('AutoDownload')
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' @('DisableWindowsConsumerFeatures')
        )
        AutoArrange = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\Shell\Bags\1\Desktop' @('FFLAGS'))
        VerboseStatus = @(New-RegistrySpec 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' @('VerboseStatus'))
        LoginAnimation = @(New-RegistrySpec 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' @('EnableFirstLogonAnimation'))
        NewsTaskbar = @(New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' @('EnableFeeds'))
        MeetNow = @(New-RegistrySpec 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' @('HideSCAMeetNow'))
        UpdateHours = @(New-RegistrySpec 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' @('ActiveHoursStart','ActiveHoursEnd'))
        LockNetwork = @(New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' @('DontDisplayNetworkSelectionUI'))
        LockShutdown = @(New-RegistrySpec 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' @('ShutdownWithoutLogon'))
        CEIP = @(New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' @('CEIPEnable'))
        PrivacyAdvertisingId = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' @('Enabled'))
        PrivacyActivityHistory = @(New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' @('PublishUserActivities','UploadUserActivities'))
        PrivacyTailoredExperiences = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' @('TailoredExperiencesWithDiagnosticDataEnabled'))
        PrivacyDeliveryOptimization = @(New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' @('DODownloadMode'))
        PrivacyLocation = @(New-RegistrySpec 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' @('Value'))
        WindowsAI = @(
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' @('DisableAIDataAnalysis','AllowRecallEnablement','DisableClickToDo','TurnOffSavingSnapshots','DisableSettingsAgent','DisableAgentConnectors','DisableAgentWorkspaces','DisableRemoteAgentConnectors')
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' @('TurnOffWindowsCopilot')
            New-RegistrySpec 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' @('TurnOffWindowsCopilot')
            New-RegistrySpec 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' @('DisableSearchBoxSuggestions')
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' @('CopilotPageContext','EdgeEntraCopilotPageContext','Microsoft365CopilotChatIconEnabled','EdgeHistoryAISearchEnabled','ComposeInlineEnabled','GenAILocalFoundationalModelSettings','BuiltInAIAPIsEnabled','AIGenThemesEnabled','DevToolsGenAiSettings','ShareBrowsingHistoryWithCopilotSearchAllowed','AllowBrowsingWithCopilot','CopilotNewTabPageEnabled','M365LinksAutoOpenCopilotEnabled','CopilotAddressBarSuggestionsEnabled','CopilotCoworkToolActionsEnabled')
            New-RegistrySpec 'HKLM:\SOFTWARE\Policies\WindowsNotepad' @('DisableAIFeatures')
        )
        AppsSmartScreen = @(New-RegistrySpec 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' @('SmartScreenEnabled'))
        ControlPanelView = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel' @('AllItemsIconView','StartupPage'))
        SeparateExplorer = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' @('SeparateProcess'))
        NumLock = @(New-RegistrySpec 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' @('InitialKeyboardIndicators'))
        ExplorerThisPC = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' @('LaunchTo'))
        FileExtensions = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' @('HideFileExt'))
        PeopleTaskbar = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People' @('PeopleBand'))
        TaskView = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' @('ShowTaskViewButton'))
        ThisPCDesktop = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' @('{20D04FE0-3AEA-1069-A2D8-08002B30309D}'))
        InkWorkspace = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PenWorkspace' @('PenWorkspaceButtonDesiredVisibility'))
        DefaultPrinter = @(New-RegistrySpec 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' @('LegacyDefaultPrinterMode'))
        StorageSense = @(New-RegistrySpec 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense' @('AllowStorageSenseGlobal','AllowStorageSenseTemporaryFilesCleanup','ConfigStorageSenseGlobalCadence'))
        SilentApps = @(New-RegistrySpec $contentDelivery @('SilentInstalledAppsEnabled'))
    }
}

Function New-SettingsBackup {
    Param ([string[]]$ActionIds,[switch]$AllowPartial)
    $ErrorActionPreference = 'Stop'

    New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
    $specs = Get-RegistryBackupSpecs
    $registryEntries = [Collections.Generic.List[object]]::new()

    ForEach ($actionId in $ActionIds) {
        If (!$specs.ContainsKey($actionId)) { Continue }
        If ($actionId -eq 'NewsTaskbar' -and !(Test-NewsAndInterestsPolicy)) { Continue }
        ForEach ($spec in $specs[$actionId]) {
            $item = Get-Item -LiteralPath $spec.Path -ErrorAction SilentlyContinue
            ForEach ($name in $spec.Names) {
                $exists = $null -ne $item -and $item.GetValueNames() -contains $name
                $value = If ($exists) { $item.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } Else { $null }
                $kind = If ($exists) { $item.GetValueKind($name).ToString() } Else { $null }
                If ($value -is [byte[]]) { $value = [Convert]::ToBase64String($value); $kind = 'Binary' }
                $registryEntries.Add([pscustomobject]@{ ActionId=$actionId; Path=$spec.Path; Name=$name; Exists=$exists; Kind=$kind; Value=$value })
            }
        }
    }

    $specialEntries = [Collections.Generic.List[object]]::new()
    If ($ActionIds -contains 'TimeZone') {
        $specialEntries.Add([pscustomobject]@{ ActionId='TimeZone'; Type='TimeZone'; Value=(Get-TimeZone).Id })
    }
    If ($ActionIds -contains 'PowerPlan') {
        $activeScheme = (powercfg /getactivescheme | Out-String)
        If ($activeScheme -match '[0-9a-fA-F-]{36}') { $specialEntries.Add([pscustomobject]@{ ActionId='PowerPlan'; Type='PowerScheme'; Value=$Matches[0] }) }
    }
    If ($ActionIds -contains 'RenameComputer') {
        $specialEntries.Add([pscustomobject]@{ ActionId='RenameComputer'; Type='ComputerName'; Value=$env:COMPUTERNAME })
    }
    If ($ActionIds -contains 'DNS') {
        ForEach ($adapter in @(Get-DnsClientServerAddress -ErrorAction Stop)) {
            $specialEntries.Add([pscustomobject]@{ ActionId='DNS'; Type='DnsServers'; InterfaceIndex=$adapter.InterfaceIndex; AddressFamily=[string]$adapter.AddressFamily; Value=@($adapter.ServerAddresses) })
        }
    }
    If ($ActionIds -contains 'ClassicContextMenu') {
        $contextPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        $contextKey = Get-Item -LiteralPath $contextPath -ErrorAction SilentlyContinue
        $specialEntries.Add([pscustomobject]@{ ActionId='ClassicContextMenu'; Type='ContextMenu'; Exists=($null -ne $contextKey); Value=$(If($contextKey){$contextKey.GetValue('')}Else{$null}) })
    }
    If ($ActionIds -contains 'DefaultApps') {
        $associationBackup = Join-Path $script:BackupRoot ("DefaultAssociations-{0}.xml" -f [guid]::NewGuid().ToString('N'))
        Try {
            & dism.exe '/Online' ("/Export-DefaultAppAssociations:$associationBackup") | Out-Null
            If ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $associationBackup)) { Throw 'DISM could not export the current default application associations.' }
            $encodedAssociations = [Convert]::ToBase64String([IO.File]::ReadAllBytes($associationBackup))
            $specialEntries.Add([pscustomobject]@{ ActionId='DefaultApps'; Type='DefaultAssociations'; Value=$encodedAssociations })
        } Catch {
            If (!$AllowPartial) { Throw }
            Write-Warning "[$(timeStamp)] Default Apps backup failed: $($_.Exception.Message)"
            $ActionIds = @($ActionIds | Where-Object { $_ -ne 'DefaultApps' })
        } Finally {
            Remove-Item -LiteralPath $associationBackup -Force -ErrorAction SilentlyContinue
        }
    }

    $backup = [ordered]@{
        SchemaVersion = 1
        AppVersion = $script:AppVersion
        Created = (Get-Date).ToString('o')
        Computer = $env:COMPUTERNAME
        User = [Environment]::UserName
        Actions = @($ActionIds)
        Registry = $registryEntries.ToArray()
        Special = $specialEntries.ToArray()
    }
    $path = Join-Path $script:BackupRoot ("Settings-{0}-{1}.json" -f (Get-Date -Format 'yyyy-MM-dd_HH.mm.ss'),[guid]::NewGuid().ToString('N').Substring(0,8))
    $backup | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Host "[$(timeStamp)] Backup: [%TEMP%\New Computer Install\Backups\$([IO.Path]::GetFileName($path))]" -ForegroundColor Cyan
    Return $backup
}

Function Get-LatestBackup {
    Get-ChildItem -LiteralPath $script:BackupRoot -Filter 'Settings-*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

Function Restore-SettingsBackup {
    Param ([string]$Path,[string[]]$ActionIds)

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $backup = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    If ($backup.SchemaVersion -ne 1) { Throw "Unsupported backup schema [$($backup.SchemaVersion)]." }
    If (!$ActionIds -or $ActionIds.Count -eq 0) { $ActionIds = @($backup.Actions) }

    $specs = Get-RegistryBackupSpecs
    $allowed = @{}
    ForEach ($actionId in $ActionIds) {
        If (!$specs.ContainsKey($actionId)) { Continue }
        If ($actionId -eq 'NewsTaskbar' -and !(Test-NewsAndInterestsPolicy)) { Continue }
        ForEach ($spec in $specs[$actionId]) {
            ForEach ($name in $spec.Names) { $allowed["$actionId|$($spec.Path)|$name"] = $true }
        }
    }

    ForEach ($entry in $backup.Registry) {
        If ($ActionIds -notcontains $entry.ActionId -or !$allowed.ContainsKey("$($entry.ActionId)|$($entry.Path)|$($entry.Name)")) { Continue }
        If ($entry.Exists) {
            If ($entry.Kind -notin @('String','ExpandString','Binary','DWord','MultiString','QWord')) { Throw "Unsafe registry type [$($entry.Kind)] in backup." }
            Initialize-RegistryKey $entry.Path
            $value = If ($entry.Kind -eq 'Binary') { [Convert]::FromBase64String([string]$entry.Value) } Else { $entry.Value }
            New-ItemProperty -Path $entry.Path -Name $entry.Name -PropertyType $entry.Kind -Value $value -Force | Out-Null
        } ElseIf (Test-Path -LiteralPath $entry.Path) {
            Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[$(timeStamp)] Restored [$($entry.ActionId)] $($entry.Name)." -ForegroundColor Gray
    }

    ForEach ($entry in $backup.Special) {
        If ($ActionIds -notcontains $entry.ActionId) { Continue }
        Switch ($entry.Type) {
            'TimeZone' { Set-TimeZone -Id ([string]$entry.Value) }
            'PowerScheme' { If ([string]$entry.Value -match '^[0-9a-fA-F-]{36}$') { powercfg /setactive $entry.Value | Out-Null } }
            'ComputerName' { If ((Test-ComputerName -Name ([string]$entry.Value)) -and [string]$entry.Value -ine $env:COMPUTERNAME) { Rename-Computer -NewName $entry.Value -Force } }
            'DnsServers' {
                $adapter = Get-DnsClientServerAddress -InterfaceIndex ([int]$entry.InterfaceIndex) |
                    Where-Object { [string]$_.AddressFamily -eq [string]$entry.AddressFamily }
                If (!$adapter) { Write-Warning "DNS interface [$($entry.InterfaceIndex)] and address family [$($entry.AddressFamily)] are unavailable."; Continue }
                $servers = @($entry.Value | Where-Object { $_ })
                If ($servers) { Set-DnsClientServerAddress -InputObject $adapter -ServerAddresses $servers -ErrorAction Stop }
                Else { Set-DnsClientServerAddress -InputObject $adapter -ResetServerAddresses -ErrorAction Stop }
            }
            'ContextMenu' {
                $contextPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
                If ($entry.Exists) { Initialize-RegistryKey $contextPath }
                If ($entry.Exists -and $null -ne $entry.Value) {
                    Set-Item -LiteralPath $contextPath -Value $entry.Value
                } ElseIf (Test-Path -LiteralPath $contextPath) {
                    Remove-ItemProperty -LiteralPath $contextPath -Name '(default)' -ErrorAction SilentlyContinue
                    $key = Get-Item -LiteralPath $contextPath
                    If (!$entry.Exists -and $key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0) { Remove-Item -LiteralPath $contextPath }
                }
            }
            'DefaultAssociations' {
                $restorePath = Join-Path $script:BackupRoot ("Restore-DefaultAssociations-{0}.xml" -f [guid]::NewGuid().ToString('N'))
                Try {
                    [IO.File]::WriteAllBytes($restorePath,[Convert]::FromBase64String([string]$entry.Value))
                    & dism.exe '/Online' ("/Import-DefaultAppAssociations:$restorePath") | ForEach-Object { Write-Host "[$(timeStamp)] $_" -ForegroundColor Gray }
                    If ($LASTEXITCODE -ne 0) { Throw "DISM could not restore default associations (exit code $LASTEXITCODE)." }
                } Finally {
                    Remove-Item -LiteralPath $restorePath -Force -ErrorAction SilentlyContinue
                }
            }
        }
        Write-Host "[$(timeStamp)] Restored [$($entry.ActionId)]." -ForegroundColor Gray
    }
}

Function Resolve-ActionSelection {
    Param ([object[]]$Catalog,[string[]]$Requested,[ValidateSet('Full','Minimal','Custom')][string]$PresetName = 'Full')
    If (!$Requested -or $Requested.Count -eq 0) {
        $presetIds = @(Get-PresetActionIds -Catalog $Catalog -Name $PresetName)
        If (!$presetIds) { Throw 'The Custom preset requires one or more action IDs through -Actions.' }
        Return @($Catalog | Where-Object Id -In $presetIds)
    }
    $requestedIds = @($Requested | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $unknown = @($requestedIds | Where-Object { $_ -notin $Catalog.Id })
    If ($unknown) { Throw "Unknown action(s): $($unknown -join ', ')" }
    Return @($Catalog | Where-Object Id -In $requestedIds)
}

Function Invoke-InstallerActions {
    Param ([object[]]$SelectedActions)
    $ids = @($SelectedActions.Id)
    $backup = $null
    Try { $backup = New-SettingsBackup -ActionIds $ids -AllowPartial }
    Catch { Write-Warning "[$(timeStamp)] Settings backup failed: $($_.Exception.Message)" }
    If (@($SelectedActions | Where-Object Category -NE 'Diagnostics').Count) { New-DailyRestorePoint }
    $completed = 0
    $failed = [Collections.Generic.List[string]]::new()
    ForEach ($action in $SelectedActions) {
        Write-Host "`n[$(timeStamp)] === $($action.Name) ===" -ForegroundColor Cyan
        $previousErrorAction = $ErrorActionPreference
        Try {
            $ErrorActionPreference = 'Stop'
            If ($action.Reversible -and $action.Id -notin $backup.Actions) { Throw 'Required settings backup is unavailable. No changes were applied for this action.' }
            & $action.Command | Out-Host
            $completed++
        } Catch {
            $failed.Add([string]$action.Name)
            Write-Host "[$(timeStamp)] $($action.Name) failed: $($_.Exception.Message.Trim())" -ForegroundColor Red
        } Finally {
            $ErrorActionPreference = $previousErrorAction
        }
    }
    Write-Host "`n[$(timeStamp)] Action summary: $completed completed, $($failed.Count) failed." -ForegroundColor $(If($failed.Count){'Yellow'}Else{'Green'})
    If ($failed.Count) { Write-Warning "[$(timeStamp)] Failed actions: $($failed -join ', ')" }
    Return $failed.Count
}

Function Complete-Session {
    If ($null -ne $script:OriginalProcessExecutionPolicy) {
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy $script:OriginalProcessExecutionPolicy -Force -ErrorAction SilentlyContinue
    }
    If ($script:StopWatch) {
        $script:StopWatch.Stop()
        Write-Host "[$(timeStamp)] Finished in $($script:StopWatch.Elapsed). Log: $($script:Log)" -ForegroundColor Cyan
    }
    Try { Stop-Transcript | Out-Null } Catch { }
    Try { Pop-Location -StackName Stack2 } Catch { }
}

Function New-RunOptionsFile {
    New-Item -ItemType Directory -Path $script:RunOptionsRoot -Force | Out-Null
    $path = Join-Path $script:RunOptionsRoot ("RunOptions-{0}-{1}.json" -f (Get-Date -Format 'yyyy-MM-dd_HH.mm.ss'),[guid]::NewGuid().ToString('N'))
    $script:RunOptions | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $path -Encoding UTF8
    Return $path
}

Function Show-InstallerGui {
    Param (
        [object[]]$Catalog,
        [ValidateSet('Dark','Light')][string]$InitialTheme = 'Dark',
        [ValidateSet('Full','Minimal','Custom')][string]$InitialPreset = 'Full'
    )

    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()

    $form = [Windows.Forms.Form]@{
        Text = "$($script:AppName) $($script:AppVersion)"
        StartPosition = 'CenterScreen'
        MinimumSize = [Drawing.Size]::new(1080,700)
        Size = [Drawing.Size]::new(1280,800)
        Font = [Drawing.Font]::new('Segoe UI',10)
        BackColor = [Drawing.Color]::FromArgb(17,24,39)
        ForeColor = [Drawing.Color]::White
    }
    $appIcon = If (Test-Path -LiteralPath $script:IconPath) { [Drawing.Icon]::new($script:IconPath,[Drawing.Size]::new(64,64)) } Else { Get-HighResolutionApplicationIcon -Size 64 }
    If ($appIcon) { $form.Icon = $appIcon }
    $logoPath = Join-Path $script:ApplicationRoot 'Assets\New-Computer-Install.png'
    $logoImage = If (Test-Path -LiteralPath $logoPath) { [Drawing.Image]::FromFile($logoPath) } Else { $null }

    $header = [Windows.Forms.Panel]@{ Dock='Top'; Height=104; Padding=[Windows.Forms.Padding]::new(22,14,18,8) }
    $logo = [Windows.Forms.Panel]@{ Size=[Drawing.Size]::new(72,72); Location=[Drawing.Point]::new(16,15) }
    $logo.Add_Paint({
        Param($sender,$eventArgs)
        $eventArgs.Graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $eventArgs.Graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        If ($logoImage) { $eventArgs.Graphics.DrawImage($logoImage,[Drawing.Rectangle]::new(0,0,$sender.Width,$sender.Height)) }
        ElseIf ($appIcon) { $eventArgs.Graphics.DrawIcon($appIcon,[Drawing.Rectangle]::new(4,4,$sender.Width-8,$sender.Height-8)) }
    })
    $title = [Windows.Forms.Label]@{ Text=$script:AppName; AutoSize=$true; Font=[Drawing.Font]::new('Segoe UI Semibold',22); Location=[Drawing.Point]::new(98,17) }
    $versionLabel = [Windows.Forms.Label]@{ Text="v$($script:AppVersion) by Hor318"; AutoSize=$true; Font=[Drawing.Font]::new('Segoe UI Semibold',9); Location=[Drawing.Point]::new(101,63) }
    $subtitle = [Windows.Forms.Label]@{ Text='|  Select an option to customize it'; AutoSize=$true; Location=[Drawing.Point]::new(230,63) }
    $header.Controls.AddRange(@($logo,$title,$versionLabel,$subtitle))

    $support = [Windows.Forms.FlowLayoutPanel]@{ Dock='Right'; Width=310; FlowDirection='LeftToRight'; Padding=[Windows.Forms.Padding]::new(0,16,0,0) }
    $header.Controls.Add($support)

    $grid = [Windows.Forms.DataGridView]@{
        Dock='Fill'; BorderStyle='None'; BackgroundColor=[Drawing.Color]::FromArgb(17,24,39); RowHeadersVisible=$false
        AllowUserToAddRows=$false; AllowUserToDeleteRows=$false; AllowUserToResizeRows=$false; AutoGenerateColumns=$false
        SelectionMode='FullRowSelect'; MultiSelect=$false; EditMode='EditOnEnter'; AutoSizeRowsMode='None'
    }
    $grid.RowTemplate.Height = 23
    $doubleBuffered = $grid.GetType().GetProperty('DoubleBuffered',[Reflection.BindingFlags]'Instance,NonPublic')
    If ($doubleBuffered) { $doubleBuffered.SetValue($grid,$true,$null) }
    $grid.ColumnHeadersHeight = 38
    $grid.Columns.Add([Windows.Forms.DataGridViewCheckBoxColumn]@{ Name='Selected'; HeaderText='Run'; Width=48; TrueValue=$true; FalseValue=$false }) | Out-Null
    $grid.Columns.Add([Windows.Forms.DataGridViewTextBoxColumn]@{ Name='Category'; HeaderText='Category'; Width=110; ReadOnly=$true }) | Out-Null
    $grid.Columns.Add([Windows.Forms.DataGridViewTextBoxColumn]@{ Name='Option'; HeaderText='Option'; Width=250; ReadOnly=$true }) | Out-Null
    $grid.Columns.Add([Windows.Forms.DataGridViewTextBoxColumn]@{ Name='Description'; HeaderText='What it does'; AutoSizeMode='Fill'; ReadOnly=$true }) | Out-Null
    $grid.Columns.Add([Windows.Forms.DataGridViewTextBoxColumn]@{ Name='State'; HeaderText='Live state'; Width=145; ReadOnly=$true; ToolTipText='Green = applied, red = not applied, orange = partial, needs input, or checked only when run.' }) | Out-Null
    $grid.Columns.Add([Windows.Forms.DataGridViewTextBoxColumn]@{ Name='Restorable'; HeaderText='Backup'; Width=72; ReadOnly=$true }) | Out-Null
    $grid.Columns.Add([Windows.Forms.DataGridViewTextBoxColumn]@{ Name='Id'; Visible=$false }) | Out-Null
    $initialIds = @(Get-PresetActionIds -Catalog $Catalog -Name $InitialPreset)
    $mainCatalog = @($Catalog | Where-Object Category -NE 'Repair')
    ForEach ($action in $mainCatalog) {
        $grid.Rows.Add(($action.Id -in $initialIds),$action.Category,$action.Name,$action.Description,'',$(If($action.Reversible){'Yes'}Else{'No'}),$action.Id) | Out-Null
    }
    $grid.Add_CurrentCellDirtyStateChanged({ If ($grid.IsCurrentCellDirty) { $grid.CommitEdit([Windows.Forms.DataGridViewDataErrorContexts]::Commit) } })

    # Set size-dependent splitter properties after WinForms has laid out the control.
    $split = [Windows.Forms.SplitContainer]@{ Dock='Fill'; FixedPanel='Panel2' }
    $details = [Windows.Forms.GroupBox]@{ Dock='Fill'; Text='Option details'; Padding=[Windows.Forms.Padding]::new(14); Font=[Drawing.Font]::new('Segoe UI Semibold',11) }
    $detailsTitle = [Windows.Forms.Label]@{ Dock='Top'; Height=52; AutoEllipsis=$false; Font=[Drawing.Font]::new('Segoe UI Semibold',13); Padding=[Windows.Forms.Padding]::new(4,5,4,2) }
    $detailsDescription = [Windows.Forms.Label]@{ Dock='Top'; Height=88; AutoEllipsis=$false; Font=[Drawing.Font]::new('Segoe UI',9.5); Padding=[Windows.Forms.Padding]::new(4,2,4,5) }
    $detailsFlow = [Windows.Forms.FlowLayoutPanel]@{ Dock='Fill'; FlowDirection='TopDown'; WrapContents=$false; AutoScroll=$true; Padding=[Windows.Forms.Padding]::new(4,8,4,4) }
    $details.Controls.Add($detailsFlow); $details.Controls.Add($detailsDescription); $details.Controls.Add($detailsTitle)
    $split.Panel1.Controls.Add($grid); $split.Panel2.Controls.Add($details)

    $repairActions = @($Catalog | Where-Object Category -EQ 'Repair')
    $repairView = [Windows.Forms.Panel]@{ Dock='Fill'; Visible=$false; Padding=[Windows.Forms.Padding]::new(24,18,24,18); AutoScroll=$true }
    $repairTop = [Windows.Forms.Panel]@{ Dock='Top'; Height=90 }
    $repairHeading = [Windows.Forms.Label]@{ Text='Repairs'; AutoSize=$true; Font=[Drawing.Font]::new('Segoe UI Semibold',24); Location=[Drawing.Point]::new(0,0) }
    $repairIntro = [Windows.Forms.Label]@{ Text='Run one targeted repair, or run all repairs in sequence. These tools are kept separate from normal setup options.'; AutoSize=$true; MaximumSize=[Drawing.Size]::new(900,0); Location=[Drawing.Point]::new(4,48) }
    $repairTop.Controls.AddRange(@($repairHeading,$repairIntro))
    $repairCards = [Windows.Forms.FlowLayoutPanel]@{ Dock='Fill'; FlowDirection='TopDown'; WrapContents=$false; AutoScroll=$true; Padding=[Windows.Forms.Padding]::new(0,2,12,2) }
    $repairRunButtons = [Collections.Generic.List[object]]::new()
    ForEach ($repairAction in $repairActions) {
        $card = [Windows.Forms.Panel]@{ Width=1040; Height=88; Margin=[Windows.Forms.Padding]::new(0,0,0,10); BorderStyle='FixedSingle'; Tag=$repairAction.Id }
        $cardName = [Windows.Forms.Label]@{ Text=$repairAction.Name; AutoSize=$true; Font=[Drawing.Font]::new('Segoe UI Semibold',12); Location=[Drawing.Point]::new(16,12) }
        $cardDescription = [Windows.Forms.Label]@{ Text=$repairAction.Description; AutoSize=$false; Size=[Drawing.Size]::new(790,42); Location=[Drawing.Point]::new(16,40); AutoEllipsis=$true }
        $cardRun = [Windows.Forms.Button]@{ Text='Run repair'; Width=122; Height=36; Location=[Drawing.Point]::new(890,25); Anchor='Top,Right'; FlatStyle='Flat'; Cursor='Hand'; Tag=$repairAction.Id }
        $cardRun.Add_Click({ Param($sender,$eventArgs) & $runRepairById ([string]$sender.Tag) })
        $card.Controls.AddRange(@($cardName,$cardDescription,$cardRun)); $repairCards.Controls.Add($card); $repairRunButtons.Add($cardRun)
    }
    $repairCards.Add_SizeChanged({
        $cardWidth=[Math]::Max(640,$repairCards.ClientSize.Width-30)
        ForEach($card in $repairCards.Controls){
            $card.Width=$cardWidth
            $runControl=$card.Controls | Where-Object {$_ -is [Windows.Forms.Button]} | Select-Object -First 1
            $descriptionControl=$card.Controls | Where-Object {$_ -is [Windows.Forms.Label] -and !$_.Font.Bold} | Select-Object -First 1
            If($runControl){$runControl.Left=$card.Width-$runControl.Width-18}
            If($descriptionControl -and $runControl){$descriptionControl.Width=[Math]::Max(300,$runControl.Left-34)}
        }
    })
    $repairBackButton = [Windows.Forms.Button]@{ Text='Back to setup'; Width=130; Height=38; FlatStyle='Flat'; Cursor='Hand'; Margin=[Windows.Forms.Padding]::new(0,6,10,6) }
    $repairAllButton = [Windows.Forms.Button]@{ Text='Run all repairs'; Width=145; Height=38; FlatStyle='Flat'; Cursor='Hand'; Margin=[Windows.Forms.Padding]::new(0,6,10,6) }
    $repairStatus = [Windows.Forms.Label]@{ Text='Repairs run in an elevated PowerShell window.'; AutoSize=$false; Width=650; Height=38; TextAlign='MiddleLeft'; Margin=[Windows.Forms.Padding]::new(8,6,0,6); AutoEllipsis=$true }
    $repairBottom = [Windows.Forms.FlowLayoutPanel]@{ Dock='Bottom'; Height=54; FlowDirection='LeftToRight'; WrapContents=$false }
    $repairBottom.Controls.AddRange(@($repairBackButton,$repairAllButton,$repairStatus))
    $repairView.Controls.Add($repairCards); $repairView.Controls.Add($repairBottom); $repairView.Controls.Add($repairTop)

    $reportView = [Windows.Forms.Panel]@{ Dock='Fill'; Visible=$false; Padding=[Windows.Forms.Padding]::new(18,12,18,18) }
    $reportToolbar = [Windows.Forms.Panel]@{ Dock='Top'; Height=54; Padding=[Windows.Forms.Padding]::new(0,5,0,8) }
    $reportBackButton = [Windows.Forms.Button]@{ Text='Back to setup'; Width=130; Height=38; Dock='Left'; FlatStyle='Flat'; Cursor='Hand' }
    $reportViewTitle = [Windows.Forms.Label]@{ Text='Full hardware and health report'; Dock='Fill'; TextAlign='MiddleLeft'; AutoEllipsis=$true; Padding=[Windows.Forms.Padding]::new(16,0,0,0); Font=[Drawing.Font]::new('Segoe UI Semibold',13) }
    $reportToolbar.Controls.Add($reportViewTitle); $reportToolbar.Controls.Add($reportBackButton)
    $reportBrowser = [Windows.Forms.WebBrowser]@{ Dock='Fill'; ScriptErrorsSuppressed=$true; IsWebBrowserContextMenuEnabled=$false; WebBrowserShortcutsEnabled=$true; AllowWebBrowserDrop=$false }
    $reportBrowser.Add_Navigating({
        Param($sender,$eventArgs)
        If ($eventArgs.Url -and $eventArgs.Url.Scheme -in @('http','https')) {
            $eventArgs.Cancel=$true
            Start-Process $eventArgs.Url.AbsoluteUri | Out-Null
        }
    })
    $reportView.Controls.Add($reportBrowser); $reportView.Controls.Add($reportToolbar)

    $footer = [Windows.Forms.Panel]@{ Dock='Bottom'; Height=126; Padding=[Windows.Forms.Padding]::new(18,8,18,10) }
    $status = [Windows.Forms.Label]@{ Dock='Top'; Height=28; AutoEllipsis=$true; Text='Live states refresh every 3 seconds; a temporary settings backup is created before selected changes run.' }
    $status.Add_TextChanged({ $repairStatus.Text=$status.Text })
    $buttons = [Windows.Forms.FlowLayoutPanel]@{ Dock='Fill'; FlowDirection='LeftToRight'; WrapContents=$true; Padding=[Windows.Forms.Padding]::new(0,5,0,0) }
    $footer.Controls.Add($buttons); $footer.Controls.Add($status)

    Function Add-GuiButton {
        Param ([string]$Text,[int]$Width=112)
        $button = [Windows.Forms.Button]@{ Text=$Text; Width=$Width; Height=34; FlatStyle='Flat'; Cursor='Hand'; Margin=[Windows.Forms.Padding]::new(0,0,8,6) }
        $button.FlatAppearance.BorderSize = 1
        $buttons.Controls.Add($button)
        Return $button
    }

    $selectAllButton = Add-GuiButton 'Select all' 92
    $selectNoneButton = Add-GuiButton 'Select none' 96
    $repairsButton = Add-GuiButton 'Repairs' 92
    $backupButton = Add-GuiButton 'Back up selected' 138
    $exportButton = Add-GuiButton 'Export backup' 122
    $importButton = Add-GuiButton 'Import backup' 122
    $restoreButton = Add-GuiButton 'Restore selected' 132
    $installPrereqButton = Add-GuiButton 'Install prerequisites' 154
    $uninstallPrereqButton = Add-GuiButton 'Uninstall prerequisites' 164
    $themeButton = [Windows.Forms.Button]@{ Text='Light mode'; Width=100; Height=34; FlatStyle='Flat'; Cursor='Hand'; Margin=[Windows.Forms.Padding]::new(0,0,8,0) }
    $koFiButton = [Windows.Forms.Button]@{ Text='Ko-fi'; Width=76; Height=34; FlatStyle='Flat'; Cursor='Hand'; Margin=[Windows.Forms.Padding]::new(0,0,8,0) }
    $donateButton = [Windows.Forms.Button]@{ Text='Donate'; Width=82; Height=34; FlatStyle='Flat'; Cursor='Hand'; Margin=[Windows.Forms.Padding]::new(0,0,8,0) }
    $support.Controls.AddRange(@($koFiButton,$donateButton,$themeButton))

    $promptReboot = [Windows.Forms.CheckBox]@{ Text='Offer to reboot when finished'; AutoSize=$true; Checked=$true; Margin=[Windows.Forms.Padding]::new(2,8,16,0) }
    $runButton = Add-GuiButton 'Run selected' 132
    $buttons.Controls.Add($promptReboot)
    $buttons.Controls.SetChildIndex($runButton,$buttons.Controls.Count-1)

    $presetLabel = [Windows.Forms.Label]@{ Text='Preset:'; AutoSize=$true; Margin=[Windows.Forms.Padding]::new(2,8,5,0) }
    $presetCombo = [Windows.Forms.ComboBox]@{ Width=106; DropDownStyle='DropDownList'; Margin=[Windows.Forms.Padding]::new(0,4,10,0) }
    [void]$presetCombo.Items.AddRange([object[]]@('Full','Minimal','Custom'))
    $presetCombo.SelectedItem = $InitialPreset
    $buttons.Controls.Add($presetLabel); $buttons.Controls.Add($presetCombo)
    $buttons.Controls.SetChildIndex($presetLabel,0); $buttons.Controls.SetChildIndex($presetCombo,1)

    $script:GuiTheme = $InitialTheme
    $applyDetailTheme = {
        $dark = $script:GuiTheme -eq 'Dark'
        $panel = If ($dark) { [Drawing.Color]::FromArgb(31,41,55) } Else { [Drawing.Color]::White }
        $text = If ($dark) { [Drawing.Color]::FromArgb(241,245,249) } Else { [Drawing.Color]::FromArgb(17,24,39) }
        $inputBack = If ($dark) { [Drawing.Color]::FromArgb(17,24,39) } Else { [Drawing.Color]::White }
        $detailsFlow.BackColor=$panel
        ForEach ($control in $detailsFlow.Controls) {
            If ($control -is [Windows.Forms.Label] -or $control -is [Windows.Forms.CheckBox]) { $control.ForeColor=$text; $control.BackColor=$panel }
            If ($control -is [Windows.Forms.TextBox] -or $control -is [Windows.Forms.ComboBox]) { $control.BackColor=$inputBack; $control.ForeColor=$text }
            If ($control -is [Windows.Forms.Button]) {
                If ([string]$control.AccessibleName -eq 'PrimaryAction') {
                    $control.BackColor=[Drawing.Color]::FromArgb(37,99,235); $control.ForeColor=[Drawing.Color]::White; $control.FlatAppearance.BorderSize=0
                } Else {
                    $control.BackColor=$panel; $control.ForeColor=$text; $control.FlatAppearance.BorderSize=1; $control.FlatAppearance.BorderColor=If($dark){[Drawing.Color]::FromArgb(75,85,99)}Else{[Drawing.Color]::FromArgb(203,213,225)}
                }
            }
        }
    }
    $applyTheme = {
        $form.SuspendLayout(); $grid.SuspendLayout(); $detailsFlow.SuspendLayout()
        Try {
            $dark = $script:GuiTheme -eq 'Dark'
            $back = If ($dark) { [Drawing.Color]::FromArgb(17,24,39) } Else { [Drawing.Color]::FromArgb(245,247,250) }
            $panel = If ($dark) { [Drawing.Color]::FromArgb(31,41,55) } Else { [Drawing.Color]::White }
            $text = If ($dark) { [Drawing.Color]::FromArgb(241,245,249) } Else { [Drawing.Color]::FromArgb(17,24,39) }
            $muted = If ($dark) { [Drawing.Color]::FromArgb(148,163,184) } Else { [Drawing.Color]::FromArgb(71,85,105) }
            $form.BackColor=$back; $form.ForeColor=$text; $header.BackColor=$panel; $footer.BackColor=$panel; $repairView.BackColor=$back; $repairTop.BackColor=$back; $repairCards.BackColor=$back; $repairBottom.BackColor=$back; $reportView.BackColor=$back; $reportToolbar.BackColor=$back
            $split.BackColor=$back; $split.Panel1.BackColor=$back; $split.Panel2.BackColor=$panel; $details.BackColor=$panel; $details.ForeColor=$text; $detailsFlow.BackColor=$panel
            $title.ForeColor=$text; $versionLabel.ForeColor=[Drawing.Color]::FromArgb(34,197,94); $subtitle.ForeColor=$muted; $status.ForeColor=$muted; $repairStatus.ForeColor=$muted; $promptReboot.ForeColor=$text; $detailsTitle.ForeColor=$text; $detailsDescription.ForeColor=$muted; $presetLabel.ForeColor=$text; $presetLabel.BackColor=$panel; $repairHeading.ForeColor=$text; $repairIntro.ForeColor=$muted; $reportViewTitle.ForeColor=$text
            $presetCombo.BackColor=If($dark){[Drawing.Color]::FromArgb(17,24,39)}Else{[Drawing.Color]::White}; $presetCombo.ForeColor=$text
            & $applyDetailTheme
            $grid.BackgroundColor=$back; $grid.GridColor=If($dark){[Drawing.Color]::FromArgb(55,65,81)}Else{[Drawing.Color]::FromArgb(226,232,240)}
            $grid.DefaultCellStyle.BackColor=$back; $grid.DefaultCellStyle.ForeColor=$text; $grid.DefaultCellStyle.SelectionBackColor=[Drawing.Color]::FromArgb(37,99,235); $grid.DefaultCellStyle.SelectionForeColor=[Drawing.Color]::White
            $grid.ColumnHeadersDefaultCellStyle.BackColor=$panel; $grid.ColumnHeadersDefaultCellStyle.ForeColor=$text; $grid.EnableHeadersVisualStyles=$false
            ForEach ($card in $repairCards.Controls) {
                $card.BackColor=$panel
                ForEach ($control in $card.Controls) { If($control -is [Windows.Forms.Label]){$control.ForeColor=If($control.Font.Bold){$text}Else{$muted}; $control.BackColor=$panel} }
            }
            ForEach ($button in @($selectAllButton,$selectNoneButton,$repairsButton,$backupButton,$exportButton,$importButton,$restoreButton,$installPrereqButton,$uninstallPrereqButton,$themeButton,$repairBackButton,$repairAllButton,$reportBackButton) + @($repairRunButtons)) {
                $button.BackColor=$panel; $button.ForeColor=$text; $button.FlatAppearance.BorderColor=If($dark){[Drawing.Color]::FromArgb(75,85,99)}Else{[Drawing.Color]::FromArgb(203,213,225)}
            }
            $runButton.BackColor=[Drawing.Color]::FromArgb(37,99,235); $runButton.ForeColor=[Drawing.Color]::White; $runButton.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(59,130,246)
            $koFiButton.BackColor=[Drawing.Color]::FromArgb(47,125,209); $koFiButton.ForeColor=[Drawing.Color]::White; $koFiButton.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(63,142,228)
            $donateButton.BackColor=[Drawing.Color]::FromArgb(255,221,87); $donateButton.ForeColor=[Drawing.Color]::FromArgb(17,24,39); $donateButton.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(250,204,21)
            $themeButton.Text=If($dark){'Light mode'}Else{'Dark mode'}
        } Finally {
            $detailsFlow.ResumeLayout($false); $grid.ResumeLayout($false); $form.ResumeLayout($false)
            If ($form.Visible) { $form.Invalidate($true) }
        }
    }

    $getSelectedIds = {
        @($grid.Rows | Where-Object { $_.Cells['Selected'].Value -eq $true } | ForEach-Object { [string]$_.Cells['Id'].Value })
    }

    Function Add-DetailLabel {
        Param ([string]$Text)
        $label = [Windows.Forms.Label]@{ Text=$Text; AutoSize=$true; MaximumSize=[Drawing.Size]::new(300,0); Margin=[Windows.Forms.Padding]::new(3,8,3,2) }
        $detailsFlow.Controls.Add($label)
    }
    Function Add-DetailCheckbox {
        Param ([string]$Text,[bool]$Checked,[string]$Option,[string]$Value,[switch]$Collection)
        $box = [Windows.Forms.CheckBox]@{ Text=$Text; AutoSize=$true; Checked=$Checked; Tag=[pscustomobject]@{ Option=$Option; Value=$Value; Collection=[bool]$Collection }; Margin=[Windows.Forms.Padding]::new(4,4,4,2) }
        $box.Add_CheckedChanged({
            Param($sender,$eventArgs)
            $metadata = $sender.Tag
            If ($metadata.Collection) {
                $values = @($detailsFlow.Controls | Where-Object { $_ -is [Windows.Forms.CheckBox] -and $_.Tag.Collection -and $_.Tag.Option -eq $metadata.Option -and $_.Checked } | ForEach-Object { [string]$_.Tag.Value })
                $script:RunOptions[$metadata.Option] = $values
            } Else { $script:RunOptions[$metadata.Option] = [bool]$sender.Checked }
        })
        $detailsFlow.Controls.Add($box)
    }
    Function Add-DetailTextBox {
        Param ([string]$Label,[string]$Option)
        Add-DetailLabel $Label
        $box = [Windows.Forms.TextBox]@{ Text=[string]$script:RunOptions[$Option]; Width=300; Tag=$Option; Margin=[Windows.Forms.Padding]::new(4,0,4,2) }
        $box.Add_TextChanged({ Param($sender,$eventArgs) $script:RunOptions[[string]$sender.Tag] = $sender.Text })
        $detailsFlow.Controls.Add($box)
    }
    Function Add-DetailMultilineTextBox {
        Param ([string]$Text,[switch]$Monospace)
        $box = [Windows.Forms.TextBox]@{
            Text=$Text; Width=[Math]::Max(300,$detailsFlow.ClientSize.Width-25); Height=If($Monospace){250}Else{180}; Multiline=$true; ReadOnly=$true
            ScrollBars=If($Monospace){'Both'}Else{'Vertical'}; WordWrap=!$Monospace; Margin=[Windows.Forms.Padding]::new(4,4,4,2)
        }
        If ($Monospace) { $box.Font=[Drawing.Font]::new('Consolas',7) }
        $detailsFlow.Controls.Add($box)
    }
    Function Add-DetailRunButton {
        Param ([string]$Text,[string]$ActionId)
        $button = [Windows.Forms.Button]@{
            Text=$Text; Width=300; Height=42; FlatStyle='Flat'; Cursor='Hand'; Tag=$ActionId; AccessibleName='PrimaryAction'
            Font=[Drawing.Font]::new('Segoe UI Semibold',10); Margin=[Windows.Forms.Padding]::new(4,12,4,3)
        }
        $button.FlatAppearance.BorderSize=0
        $button.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(59,130,246)
        $button.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(29,78,216)
        $button.Enabled = !($script:ActiveChild -and !$script:ActiveChild.HasExited)
        $button.Add_Click({ Param($sender,$eventArgs) & $runSingleActionById ([string]$sender.Tag) })
        $detailsFlow.Controls.Add($button)
    }
    Function Show-GuiCustomization {
        Param ([string]$ActionId)
        If ($form.Visible -and $split.ClientSize.Width -gt 850) {
            $detailsWidth=If($ActionId -eq 'Weather'){[Math]::Min(760,$split.ClientSize.Width-360)}Else{360}
            $split.SplitterDistance=[Math]::Max(360,$split.ClientSize.Width-$detailsWidth)
        }
        $detailsFlow.SuspendLayout(); $detailsFlow.Controls.Clear()
        $action = $Catalog | Where-Object Id -EQ $ActionId | Select-Object -First 1
        $details.Text = 'Option details'
        $detailsTitle.Text = If ($action) { $action.Name } Else { 'Select an option' }
        $detailsDescription.Text = If ($action) { $action.Description } Else { 'Select an option on the left.' }

        Switch ($ActionId) {
            'Weather' {
                $cachedWeather = If (Test-Path -LiteralPath ([string]$script:RunOptions.WeatherCachePath) -PathType Leaf) {
                    Get-Content -LiteralPath ([string]$script:RunOptions.WeatherCachePath) -Raw
                } Else { 'Run this option to load the current-day forecast here.' }
                Add-DetailLabel 'Latest current-day forecast:'
                Add-DetailMultilineTextBox -Text $cachedWeather -Monospace
            }
            'Prerequisites' {
                Add-DetailLabel 'Install or update:'
                $labels = [ordered]@{ WinGet='WinGet / Microsoft App Installer'; Chocolatey='Chocolatey fallback package manager'; PowerShell='Verify Windows PowerShell 5+'; NuGet='NuGet package provider'; PowerShellGet='PowerShellGet module'; PSWindowsUpdate='PSWindowsUpdate module' }
                ForEach ($item in $labels.Keys) { Add-DetailCheckbox $labels[$item] ($item -in @($script:RunOptions.PrerequisiteItems)) 'PrerequisiteItems' $item -Collection }
                Add-DetailLabel 'Uninstall removes Chocolatey and PSWindowsUpdate when selected. Windows-provided components are preserved.'
            }
            'BaseSoftware' {
                Add-DetailLabel 'Install or update:'
                $labels = [ordered]@{ '7zip'='7-Zip'; googlechrome='Google Chrome'; temurin='Java (Eclipse Temurin OpenJDK 21 LTS)'; 'microsoft-edge'='Microsoft Edge'; adobereader='Adobe Acrobat Reader' }
                ForEach ($item in $labels.Keys) { Add-DetailCheckbox $labels[$item] ($item -in @($script:RunOptions.SoftwarePackages)) 'SoftwarePackages' $item -Collection }
                Add-DetailCheckbox 'Install detected GPU driver tools' ([bool]$script:RunOptions.InstallGpuDrivers) 'InstallGpuDrivers' ''
            }
            'OEMInfo' {
                Add-DetailTextBox 'Manufacturer' 'OEMManufacturer'
                Add-DetailTextBox 'Support phone' 'OEMSupportPhone'
                Add-DetailTextBox 'Support URL' 'OEMSupportURL'
                Add-DetailTextBox 'Logo path (.bmp, optional)' 'OEMLogo'
            }
            'RenameComputer' {
                Add-DetailTextBox 'New computer name (1-15 letters, numbers, or hyphens)' 'ComputerName'
                Add-DetailLabel "Current name: $env:COMPUTERNAME. Leave blank to prompt only when Windows still has a default DESKTOP or WIN- name."
            }
            'PowerPlan' {
                Add-DetailLabel 'Power plan:'
                $combo = [Windows.Forms.ComboBox]@{ Width=240; DropDownStyle='DropDownList'; Margin=[Windows.Forms.Padding]::new(4) }
                [void]$combo.Items.AddRange([object[]]@('High Performance','Balanced'))
                $combo.SelectedItem = If ($script:RunOptions.PowerPlan -eq 'Balanced') { 'Balanced' } Else { 'High Performance' }
                $combo.Add_SelectedIndexChanged({ Param($sender,$eventArgs) If($sender.SelectedItem){$script:RunOptions.PowerPlan=([string]$sender.SelectedItem -replace ' ','')} })
                $detailsFlow.Controls.Add($combo)
                Add-DetailLabel 'High Performance is the project default. Balanced remains available for laptops and Modern Standby devices.'
            }
            'TimeZone' {
                Add-DetailLabel 'US time zone:'
                $combo = [Windows.Forms.ComboBox]@{ Width=240; DropDownStyle='DropDownList'; Margin=[Windows.Forms.Padding]::new(4) }
                [void]$combo.Items.AddRange([object[]]@('Hawaiian','Alaskan','Pacific','Mountain','Central','Eastern'))
                $combo.SelectedItem = [string]$script:RunOptions.TimeZone
                $combo.Add_SelectedIndexChanged({ Param($sender,$eventArgs) If($sender.SelectedItem){$script:RunOptions.TimeZone=[string]$sender.SelectedItem} })
                $detailsFlow.Controls.Add($combo)
            }
            'UpdateHours' {
                Add-DetailTextBox 'Start hour (0-23; blank defaults to 20 / 8 PM)' 'UpdateActiveHoursStart'
                Add-DetailTextBox 'End hour (0-23; blank defaults to 5 / 5 AM)' 'UpdateActiveHoursEnd'
                Add-DetailLabel 'Windows avoids automatic restarts during this interval. The default crosses midnight from 8 PM through 5 AM.'
            }
            'DNS' {
                Add-DetailLabel 'DNS provider:'
                $combo = [Windows.Forms.ComboBox]@{ Width=240; DropDownStyle='DropDownList'; Margin=[Windows.Forms.Padding]::new(4) }
                [void]$combo.Items.AddRange([object[]]@('Dynamic','Cloudflare','Quad9','Google','AdGuard'))
                $combo.SelectedItem = [string]$script:RunOptions.DnsProvider
                $combo.Add_SelectedIndexChanged({ Param($sender,$eventArgs) If($sender.SelectedItem){$script:RunOptions.DnsProvider=[string]$sender.SelectedItem} })
                $detailsFlow.Controls.Add($combo)
                Add-DetailLabel 'Dynamic uses DHCP and is the default for domain and business networks.'
            }
            'DiagnosticsReport' {
                Add-DetailTextBox 'Export folder' 'ReportOutputPath'
                Add-DetailLabel 'System summary (loaded from the latest saved report):'
                $latestReport = Get-LatestDiagnosticReport -OutputPath ([string]$script:RunOptions.ReportOutputPath)
                $summary = ''
                If ($latestReport) {
                    Try {
                        $cachedSnapshot=Get-CachedDiagnosticSnapshot -OutputPath ([string]$script:RunOptions.ReportOutputPath)
                        If ($cachedSnapshot) { $summary=Get-DiagnosticSummaryText -Snapshot $cachedSnapshot }
                    } Catch { $summary="Summary unavailable: $($_.Exception.Message)" }
                }
                Add-DetailMultilineTextBox $summary
                $viewReportButton=[Windows.Forms.Button]@{ Text='View full report'; Width=300; Height=38; FlatStyle='Flat'; Cursor='Hand'; Tag=$latestReport; AccessibleName='SecondaryAction'; Margin=[Windows.Forms.Padding]::new(4,8,4,2); Enabled=[bool]$latestReport }
                $viewReportButton.Add_Click({
                    Param($sender,$eventArgs)
                    $reportPath=[string]$sender.Tag
                    If (!(Test-Path -LiteralPath $reportPath -PathType Leaf)) { Return }
                    $reportViewTitle.Text=[IO.Path]::GetFileNameWithoutExtension($reportPath)
                    $reportBrowser.Navigate($reportPath)
                    $split.Visible=$false; $repairView.Visible=$false; $footer.Visible=$false; $reportView.Visible=$true
                    $subtitle.Text='|  Full hardware and health report'
                })
                $detailsFlow.Controls.Add($viewReportButton)
                Add-DetailLabel 'Running this option fills the summary and exports both a modern HTML report and a machine-readable JSON report.'
            }
            'DefaultApps' {
                Add-DetailCheckbox 'Chrome: HTTP, HTTPS, HTM, and HTML' ([bool]$script:RunOptions.SetChromeDefault) 'SetChromeDefault' ''
                Add-DetailCheckbox 'Adobe Reader: PDF' ([bool]$script:RunOptions.SetAdobePdfDefault) 'SetAdobePdfDefault' ''
                Add-DetailLabel 'Windows applies imported defaults automatically when each new profile first signs in.'
            }
            'AdGuard' {
                Add-DetailCheckbox 'Install AdGuard in Google Chrome' ([bool]$script:RunOptions.InstallAdGuardChrome) 'InstallAdGuardChrome' ''
                Add-DetailCheckbox 'Install AdGuard in Microsoft Edge' ([bool]$script:RunOptions.InstallAdGuardEdge) 'InstallAdGuardEdge' ''
                Add-DetailLabel 'Machine policy applies to current and future browser profiles. Policy-installed extensions cannot be removed by standard users.'
            }
            'WindowsAI' {
                Add-DetailCheckbox 'Disable Windows Copilot, Recall, Click to Do, and agent policies' ([bool]$script:RunOptions.DisableWindowsAIPolicies) 'DisableWindowsAIPolicies' ''
                Add-DetailCheckbox 'Disable Copilot and generative-AI features in Microsoft Edge' ([bool]$script:RunOptions.DisableEdgeAIPolicies) 'DisableEdgeAIPolicies' ''
                Add-DetailCheckbox 'Disable the Rewrite AI feature in Notepad' ([bool]$script:RunOptions.DisableNotepadAI) 'DisableNotepadAI' ''
                Add-DetailCheckbox 'Remove Copilot Appx packages (not automatically restorable)' ([bool]$script:RunOptions.RemoveCopilotPackages) 'RemoveCopilotPackages' ''
                Add-DetailLabel 'This opt-in action is excluded from Full and Minimal. It preserves CoreAI/CBS packages, Defender, system files, and scheduled tasks to avoid breaking servicing on business PCs.'
            }
            Default { Add-DetailLabel 'This option has no additional settings.' }
        }
        If ($action) {
            $runText = If ($ActionId -eq 'DiagnosticsReport') { 'Run hardware report now  ›' } Else { 'Run this option now  ›' }
            Add-DetailRunButton -Text $runText -ActionId $ActionId
        }
        $detailsFlow.ResumeLayout(); & $applyDetailTheme
    }

    $refreshRowState = {
        Param ([Windows.Forms.DataGridViewRow]$Row)
        $stateValue = Get-ActionState -ActionId ([string]$Row.Cells['Id'].Value)
        $color = Switch -Regex ($stateValue) {
            '^(Applied|Ready|Clean|Dynamic)' { [Drawing.Color]::FromArgb(34,197,94); Break }
            '^(Partial|Needs input|Check on run|Unavailable)' { [Drawing.Color]::FromArgb(245,158,11); Break }
            '^(Not applied|Missing|Detected|Different)' { [Drawing.Color]::FromArgb(239,68,68); Break }
            Default { [Drawing.Color]::FromArgb(148,163,184) }
        }
        $Row.Cells['State'].Value = "● $stateValue"
        $Row.Cells['State'].Style.ForeColor = $color
    }
    $script:StateRefreshIndex=0
    $refreshStates = {
        Param ([int]$BatchSize=12)
        If ($script:StateRefreshBusy) { Return }
        $script:StateRefreshBusy = $true
        Try {
            $count=$grid.Rows.Count
            If (!$count) { Return }
            For ($offset=0; $offset -lt [Math]::Min($BatchSize,$count); $offset++) {
                & $refreshRowState $grid.Rows[($script:StateRefreshIndex+$offset)%$count]
            }
            $script:StateRefreshIndex=($script:StateRefreshIndex+$BatchSize)%$count
        } Finally { $script:StateRefreshBusy = $false }
    }

    $startGuiOperation = {
        Param ([string[]]$Arguments,[string]$Label,[string[]]$ActionIds=@())
        If ($script:ActiveChild -and !$script:ActiveChild.HasExited) {
            [Windows.Forms.MessageBox]::Show('Another operation is already running.',$script:AppName,'OK','Information') | Out-Null
            Return
        }
        Try {
            $script:ActiveActionIds = @($ActionIds)
            $script:ActiveOperationLabel = $Label
            $script:ActiveChild = Start-ElevatedSelf -ArgumentList $Arguments
            $status.Text = "$Label is running in the PowerShell window. States update automatically here."
            $runButton.Enabled=$false; $repairAllButton.Enabled=$false
            ForEach ($button in $repairRunButtons) { $button.Enabled=$false }
            ForEach ($button in @($detailsFlow.Controls | Where-Object { $_ -is [Windows.Forms.Button] -and $_.AccessibleName -eq 'PrimaryAction' })) { $button.Enabled=$false }
        } Catch {
            $script:ActiveChild=$null
            [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Unable to start operation','OK','Error') | Out-Null
        }
    }

    $runRepairById = {
        Param ([string]$ActionId)
        $action = $repairActions | Where-Object Id -EQ $ActionId | Select-Object -First 1
        If (!$action) { Return }
        If ([Windows.Forms.MessageBox]::Show("Run $($action.Name) now?",$script:AppName,'YesNo','Question') -ne 'Yes') { Return }
        $settingsPath=New-RunOptionsFile
        & $startGuiOperation @('-Actions',$ActionId,'-SettingsFile',$settingsPath,'-NoReboot') $action.Name @($ActionId)
    }

    $runSingleActionById = {
        Param ([string]$ActionId)
        $action = $mainCatalog | Where-Object Id -EQ $ActionId | Select-Object -First 1
        If (!$action) { Return }
        If ($ActionId -eq 'RenameComputer' -and $script:RunOptions.ComputerName -and !(Test-ComputerName -Name ([string]$script:RunOptions.ComputerName))) {
            [Windows.Forms.MessageBox]::Show('Use 1-15 letters, numbers, or hyphens for the computer name; it cannot be only numbers.',$script:AppName,'OK','Warning') | Out-Null
            Return
        }
        If ($ActionId -eq 'UpdateHours') {
            Try {
                $null=Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursStart -Default 20
                $null=Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursEnd -Default 5
            } Catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,$script:AppName,'OK','Warning') | Out-Null; Return }
        }
        If ($ActionId -eq 'WindowsAI') {
            $aiChoices=@($script:RunOptions.DisableWindowsAIPolicies,$script:RunOptions.DisableEdgeAIPolicies,$script:RunOptions.DisableNotepadAI,$script:RunOptions.RemoveCopilotPackages) | Where-Object { [bool]$_ }
            If (!$aiChoices) { [Windows.Forms.MessageBox]::Show('Select at least one Windows AI option first.',$script:AppName,'OK','Warning') | Out-Null; Return }
            If ($script:RunOptions.RemoveCopilotPackages -and [Windows.Forms.MessageBox]::Show('Copilot Appx removal is not automatically restorable. Continue?',$script:AppName,'YesNo','Warning') -ne 'Yes') { Return }
        }
        $settingsPath=New-RunOptionsFile
        $arguments=@('-Actions',$ActionId,'-SettingsFile',$settingsPath,'-NoReboot')
        & $startGuiOperation $arguments $action.Name @($ActionId)
    }

    $grid.Add_SelectionChanged({
        If ($grid.CurrentRow) { Show-GuiCustomization -ActionId ([string]$grid.CurrentRow.Cells['Id'].Value) }
    })
    $script:ApplyingPreset = $false
    $script:ChangingPresetName = $false
    $setPreset = {
        Param([string]$Name)
        $script:ApplyingPreset = $true
        Try {
            $ids = @(Get-PresetActionIds -Catalog $Catalog -Name $Name)
            ForEach ($row in $grid.Rows) { $row.Cells['Selected'].Value = ([string]$row.Cells['Id'].Value -in $ids) }
        } Finally { $script:ApplyingPreset = $false }
    }
    $presetCombo.Add_SelectedIndexChanged({ If(!$script:ChangingPresetName -and $presetCombo.SelectedItem){ & $setPreset ([string]$presetCombo.SelectedItem) } })
    $grid.Add_CellValueChanged({
        Param($sender,$eventArgs)
        If (!$script:ApplyingPreset -and $eventArgs.ColumnIndex -eq $grid.Columns['Selected'].Index -and $presetCombo.SelectedItem -ne 'Custom') {
            $script:ChangingPresetName=$true; $presetCombo.SelectedItem='Custom'; $script:ChangingPresetName=$false
        }
    })
    $selectAllButton.Add_Click({ $script:ApplyingPreset=$true; ForEach($row in $grid.Rows){$row.Cells['Selected'].Value=$true}; $script:ApplyingPreset=$false; $script:ChangingPresetName=$true; $presetCombo.SelectedItem='Custom'; $script:ChangingPresetName=$false })
    $selectNoneButton.Add_Click({ $script:ApplyingPreset=$true; ForEach($row in $grid.Rows){$row.Cells['Selected'].Value=$false}; $script:ApplyingPreset=$false; $script:ChangingPresetName=$true; $presetCombo.SelectedItem='Custom'; $script:ChangingPresetName=$false })
    $repairsButton.Add_Click({ $split.Visible=$false; $reportView.Visible=$false; $footer.Visible=$false; $repairView.Visible=$true; $subtitle.Text='|  Targeted Windows repair tools' })
    $repairBackButton.Add_Click({ $repairView.Visible=$false; $split.Visible=$true; $footer.Visible=$true; $subtitle.Text='|  Select an option to customize it' })
    $reportBackButton.Add_Click({ $reportView.Visible=$false; $split.Visible=$true; $footer.Visible=$true; $subtitle.Text='|  Select an option to customize it' })
    $repairAllButton.Add_Click({
        If ([Windows.Forms.MessageBox]::Show('Run all four repairs in sequence? DISM and SFC can take a long time, and the network reset requires a restart afterward.',$script:AppName,'YesNo','Warning') -ne 'Yes') { Return }
        $ids=@($repairActions.Id); $settingsPath=New-RunOptionsFile
        & $startGuiOperation @('-Actions',($ids -join ','),'-SettingsFile',$settingsPath,'-NoReboot') 'All repairs' $ids
    })
    $themeButton.Add_Click({ $script:GuiTheme=If($script:GuiTheme -eq 'Dark'){'Light'}Else{'Dark'}; & $applyTheme })
    $koFiButton.Add_Click({ Start-Process $script:KoFiUrl | Out-Null })
    $donateButton.Add_Click({ Start-Process $script:DonateUrl | Out-Null })

    $liveTimer = [Windows.Forms.Timer]::new()
    $liveTimer.Interval = 600
    $liveTimer.Add_Tick({
        If ($script:ActiveChild) {
            $script:ActiveChild.Refresh()
            If ($script:ActiveChild.HasExited) {
                $exitCode=$script:ActiveChild.ExitCode
                $status.Text = "$($script:ActiveOperationLabel) finished with exit code $exitCode. Live states refreshed."
                $script:ActiveChild=$null; $runButton.Enabled=$true; $repairAllButton.Enabled=$true
                ForEach ($button in $repairRunButtons) { $button.Enabled=$true }
                ForEach ($actionId in @($script:ActiveActionIds)) {
                    $row=@($grid.Rows | Where-Object { [string]$_.Cells['Id'].Value -eq $actionId }) | Select-Object -First 1
                    If ($row) { & $refreshRowState $row }
                }
                If ($grid.CurrentRow) { Show-GuiCustomization -ActionId ([string]$grid.CurrentRow.Cells['Id'].Value) }
            } Else { $status.Text = "$($script:ActiveOperationLabel) is running. States update automatically." }
        }
        & $refreshStates -BatchSize 12
    })

    $backupButton.Add_Click({
        $ids = & $getSelectedIds
        If (!$ids) { [Windows.Forms.MessageBox]::Show('Select at least one option first.',$script:AppName) | Out-Null; Return }
        $settingsPath=New-RunOptionsFile
        & $startGuiOperation @('-Actions',($ids -join ','),'-SettingsFile',$settingsPath,'-BackupOnly','-NoReboot') 'Settings backup' $ids
    })
    $exportButton.Add_Click({
        $source = If ($script:SelectedBackupPath) { $script:SelectedBackupPath } Else { Get-LatestBackup }
        If (!$source) { [Windows.Forms.MessageBox]::Show('No temporary backup exists yet.',$script:AppName) | Out-Null; Return }
        $dialog = [Windows.Forms.SaveFileDialog]@{ Filter='New Computer Install backup (*.json)|*.json'; FileName=[IO.Path]::GetFileName($source) }
        If ($dialog.ShowDialog() -eq 'OK') { Copy-Item -LiteralPath $source -Destination $dialog.FileName -Force; $status.Text="Exported: $($dialog.FileName)" }
    })
    $importButton.Add_Click({
        $dialog = [Windows.Forms.OpenFileDialog]@{ Filter='New Computer Install backup (*.json)|*.json'; CheckFileExists=$true }
        If ($dialog.ShowDialog() -eq 'OK') {
            Try {
                $candidate = Get-Content -LiteralPath $dialog.FileName -Raw | ConvertFrom-Json -ErrorAction Stop
                If ($candidate.SchemaVersion -ne 1) { Throw 'This is not a supported New Computer Install backup.' }
                New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
                $destination = Join-Path $script:BackupRoot ("Imported-{0}.json" -f (Get-Date -Format 'yyyy-MM-dd_HH.mm.ss'))
                Copy-Item -LiteralPath $dialog.FileName -Destination $destination -Force
                $script:SelectedBackupPath=$destination; $status.Text="Imported: $destination"
            } Catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Import failed','OK','Error') | Out-Null }
        }
    })
    $restoreButton.Add_Click({
        $ids=& $getSelectedIds; $source=If($script:SelectedBackupPath){$script:SelectedBackupPath}Else{Get-LatestBackup}
        If (!$ids -or !$source) { [Windows.Forms.MessageBox]::Show('Select options and create or import a backup first.',$script:AppName) | Out-Null; Return }
        If ([Windows.Forms.MessageBox]::Show('Restore the selected settings from this backup?',$script:AppName,'YesNo','Question') -eq 'Yes') {
            & $startGuiOperation @('-RestoreBackup',$source,'-Actions',($ids -join ','),'-NoReboot') 'Settings restore' $ids
        }
    })
    $installPrereqButton.Add_Click({
        $settingsPath=New-RunOptionsFile
        & $startGuiOperation @('-Prerequisites','Install','-SettingsFile',$settingsPath,'-NoReboot') 'Prerequisite installation' @('Prerequisites')
    })
    $uninstallPrereqButton.Add_Click({
        $message='Chocolatey will be archived to the temporary backup folder and then removed. Installed Windows applications remain. Continue?'
        If ([Windows.Forms.MessageBox]::Show($message,$script:AppName,'YesNo','Warning') -eq 'Yes') {
            $settingsPath=New-RunOptionsFile
            & $startGuiOperation @('-Prerequisites','Uninstall','-SettingsFile',$settingsPath,'-NoReboot') 'Prerequisite removal' @('Prerequisites')
        }
    })
    $runButton.Add_Click({
        $ids=& $getSelectedIds
        If (!$ids) { [Windows.Forms.MessageBox]::Show('Select at least one option first.',$script:AppName) | Out-Null; Return }
        If ($ids -contains 'RenameComputer' -and $script:RunOptions.ComputerName -and !(Test-ComputerName -Name ([string]$script:RunOptions.ComputerName))) {
            [Windows.Forms.MessageBox]::Show('Use 1-15 letters, numbers, or hyphens for the computer name; it cannot be only numbers.',$script:AppName,'OK','Warning') | Out-Null
            Return
        }
        If ($ids -contains 'UpdateHours') {
            Try {
                $null=Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursStart -Default 20
                $null=Resolve-UpdateActiveHour -Value $script:RunOptions.UpdateActiveHoursEnd -Default 5
            } Catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,$script:AppName,'OK','Warning') | Out-Null; Return }
        }
        If ($ids -contains 'WindowsAI' -and !(@($script:RunOptions.DisableWindowsAIPolicies,$script:RunOptions.DisableEdgeAIPolicies,$script:RunOptions.DisableNotepadAI,$script:RunOptions.RemoveCopilotPackages) | Where-Object { [bool]$_ })) {
            [Windows.Forms.MessageBox]::Show('Select at least one Windows AI option first.',$script:AppName,'OK','Warning') | Out-Null
            Return
        }
        $irreversible=@($Catalog | Where-Object { $_.Id -in $ids -and !$_.Reversible }).Count
        $message="Run $($ids.Count) selected option(s)? A settings backup will be created first."
        If($irreversible){$message+="`n`n$irreversible selected option(s) cannot be automatically restored."}
        If ([Windows.Forms.MessageBox]::Show($message,$script:AppName,'YesNo','Question') -eq 'Yes') {
            $settingsPath=New-RunOptionsFile
            $arguments=@('-Actions',($ids -join ','),'-SettingsFile',$settingsPath); If(!$promptReboot.Checked){$arguments+='-NoReboot'}
            & $startGuiOperation $arguments 'Selected setup actions' $ids
        }
    })

    $form.Controls.Add($split); $form.Controls.Add($repairView); $form.Controls.Add($reportView); $form.Controls.Add($footer); $form.Controls.Add($header)
    & $applyTheme
    $form.Add_Shown({
        $split.Panel2MinSize=320
        $split.SplitterDistance=[Math]::Max(500,$split.ClientSize.Width-360)
        If ($grid.Rows.Count) { $grid.CurrentCell=$grid.Rows[0].Cells['Option']; Show-GuiCustomization -ActionId ([string]$grid.Rows[0].Cells['Id'].Value) }
        $liveTimer.Start()
        $form.Activate()
    })
    $form.Add_FormClosed({ $liveTimer.Stop(); $liveTimer.Dispose(); If($logoImage){$logoImage.Dispose()}; If($appIcon){$appIcon.Dispose()} })
    [void]$form.ShowDialog()
}

<# =================================================================================================================================
====================================================================================================================================
                                              ***    Main Script Code here!    ***
====================================================================================================================================
================================================================================================================================== #>

$catalog = @(Get-ActionCatalog)

If ($SelfTest) {
    $duplicates = @($catalog | Group-Object Id | Where-Object Count -gt 1)
    If ($duplicates) { Throw "Duplicate action IDs: $($duplicates.Name -join ', ')" }
    If (@($catalog | Where-Object { !$_.Id -or !$_.Name -or !$_.Command }).Count) { Throw 'The action catalog contains an incomplete entry.' }
    $backupSpecs = Get-RegistryBackupSpecs
    $unknownBackupIds = @($backupSpecs.Keys | Where-Object { $_ -notin $catalog.Id })
    If ($unknownBackupIds) { Throw "Backup mappings reference unknown actions: $($unknownBackupIds -join ', ')" }
    $specialBackupIds = @('TimeZone','PowerPlan','RenameComputer','ClassicContextMenu','DefaultApps','DNS')
    $missingBackups = @($catalog | Where-Object { $_.Reversible -and $_.Id -notin $backupSpecs.Keys -and $_.Id -notin $specialBackupIds })
    If ($missingBackups) { Throw "Reversible actions missing backup mappings: $($missingBackups.Id -join ', ')" }
    If (!(Test-ComputerName 'OFFICE-PC') -or (Test-ComputerName '-BAD') -or (Test-ComputerName '12345') -or (Test-ComputerName 'THIS-NAME-IS-TOO-LONG')) { Throw 'Computer-name validation self-test failed.' }
    If ((Resolve-UpdateActiveHour -Value '' -Default 20) -ne 20 -or (Resolve-UpdateActiveHour -Value '5' -Default 20) -ne 5) { Throw 'Update active-hours default/parse self-test failed.' }
    $invalidHourAccepted=$true; Try { $null=Resolve-UpdateActiveHour -Value '24' -Default 20 } Catch { $invalidHourAccepted=$false }
    If ($invalidHourAccepted) { Throw 'Update active-hours validation self-test failed.' }
    $weatherTest = @(Get-CurrentDayWeatherLines -Content "Current conditions`n  ┌───┐`n┌───┤ Today ├───┐`n│ Morning │ Night │`n└───────────────┘`nTomorrow")
    If ($weatherTest.Count -ne 4 -or $weatherTest[0] -notmatch '^\s*┌' -or $weatherTest[-1] -notmatch '^└') { Throw 'Current-day weather extraction self-test failed.' }
    ForEach ($presetName in @('Full','Minimal')) {
        $presetIds = @(Get-PresetActionIds -Catalog $catalog -Name $presetName)
        If (!$presetIds -or @($presetIds | Where-Object { $_ -notin $catalog.Id })) { Throw "Preset [$presetName] contains invalid actions." }
    }
    If (@(Get-PresetActionIds -Catalog $catalog -Name Full | Where-Object { $_ -in @($catalog | Where-Object Category -In @('Repair','Diagnostics','Optional') | ForEach-Object Id) }).Count) { Throw 'The Full preset must not run repairs, reports, or optional-risk actions automatically.' }
    & {
        Function New-SettingsBackup { Return @{ Actions = @() } }
        Function New-DailyRestorePoint { }
        $ran = [Collections.Generic.List[string]]::new()
        $testActions = @(
            New-InstallerAction 'Hardware' 'DriverTest' 'Driver test' '' $false {
                Throw [Runtime.InteropServices.COMException]::new('Driver search failed', [int]0x8024802A)
            }
            New-InstallerAction 'System' 'BackupTest' 'Backup test' '' $true { $ran.Add('Unbacked action') }
            New-InstallerAction 'Diagnostics' 'NextTest' 'Later action' '' $false { $ran.Add('Later action') }
        )
        $results = @(Invoke-InstallerActions -SelectedActions $testActions 2>&1 3>$null 6>$null)
        If ($results[-1] -ne 2 -or $ran.Count -ne 1 -or $ran[0] -ne 'Later action') { Throw 'Action isolation self-test failed.' }
    }
    & {
        $moduleAttempts = [Collections.Generic.List[bool]]::new()
        Function Enable-PrerequisiteModuleLoading { }
        Function Update-GalleryModule { Param ([string]$Name,[switch]$Repair) $moduleAttempts.Add([bool]$Repair) }
        Function Import-Module {
            Param ([string]$Name,[switch]$Global,[switch]$PassThru,[switch]$Force,[string]$ErrorAction)
            If (!$Force) { Throw 'Simulated module load failure.' }
            [pscustomobject]@{ Version='2.2.1.5'; ExportedCommands=@{ 'Get-WindowsUpdate'=$true } }
        }
        Try {
            Initialize-PSWindowsUpdate 3>$null 6>$null
            Initialize-PSWindowsUpdate 3>$null 6>$null
            If ($moduleAttempts.Count -ne 2 -or $moduleAttempts[0] -or !$moduleAttempts[1]) { Throw 'PSWindowsUpdate repair self-test failed.' }
        } Finally {
            $script:PSWindowsUpdateReady = $false
        }
    }
    $driverDevices = @(
        @{ Device='Test network device'; HardwareIds=@('PCI\TEST_NET'); CompatibleIds=@('PCI\TEST_CLASS') }
        @{ Device='Test Bluetooth device'; HardwareIds=@('USB\TEST_BT'); CompatibleIds=@() }
        @{ Device='Second test Bluetooth device'; HardwareIds=@('USB\TEST_BT'); CompatibleIds=@() }
    )
    $driverOffers = @(
        [pscustomobject]@{ Title='Optional network'; DriverHardwareID='pci\test_net'; BrowseOnly=$true; Identity=@{UpdateID='network'} }
        [pscustomobject]@{ Title='Generic'; DriverHardwareID='PCI\TEST_CLASS'; BrowseOnly=$false; Identity=@{UpdateID='generic'} }
        [pscustomobject]@{ Title='Bluetooth'; WindowsDriverUpdateEntries=@(@{DriverHardwareID='USB\TEST_BT'}); BrowseOnly=$false; Identity=@{UpdateID='bluetooth'} }
        [pscustomobject]@{ Title='Unrelated'; DriverHardwareID='USB\OTHER'; BrowseOnly=$false; Identity=@{UpdateID='other'} }
    )
    $matchedDrivers = @(Select-DriverUpdates -Updates $driverOffers -Devices $driverDevices 6>$null)
    If (($matchedDrivers.Title -join ',') -ne 'Optional network,Bluetooth') { Throw 'Driver hardware matching self-test failed.' }
    $fixtureId = [guid]'01010101-0202-0303-0404-050505050505'
    $catalogFixture = @"
downloadInformation[0].updateID = '$fixtureId';
downloadInformation[0].files[0].url = 'http://catalog.s.download.windowsupdate.com/test.cab';
downloadInformation[0].files[0].sha256 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
downloadInformation[0].files[1].url = 'https://download.windowsupdate.com.example.net/test.cab';
downloadInformation[0].files[1].sha256 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
downloadInformation[0].files[2].url = 'https://download.windowsupdate.com/test.cab';
"@
    $catalogDownloads = @(Get-DriverCatalogDownloads -Html $catalogFixture -UpdateId $fixtureId)
    If ($catalogDownloads.Count -ne 1 -or $catalogDownloads[0].Uri.Scheme -ne 'https' -or $catalogDownloads[0].Hash -ne ('0' * 64)) {
        Throw 'Driver Catalog download validation self-test failed.'
    }
    If ((Test-DriverCatalogProduct 'Windows 11 Client, version 25H2 and later' 'Windows 11' '24H2') -or
        !(Test-DriverCatalogProduct 'Windows 11 Client, version 24H2 and later' 'Windows 11' '25H2')) {
        Throw 'Driver Catalog Windows release validation self-test failed.'
    }
    & {
        $os = @{ CurrentBuild='26200'; InstallationType='Client'; EditionID='Professional' }
        Function Get-ItemProperty { Param([string]$LiteralPath,[string]$ErrorAction) $os }
        If (Test-NewsAndInterestsPolicy) { Throw 'The Windows 10 feed policy was enabled on Windows 11.' }
        $os.CurrentBuild = '19045'
        If (!(Test-NewsAndInterestsPolicy)) { Throw 'The feed policy was disabled on supported Windows 10.' }
        $os.EditionID = 'Core'
        If (Test-NewsAndInterestsPolicy) { Throw 'The feed policy was enabled on Windows Home.' }
    }
    Write-Output "$($script:AppName) $($script:AppVersion) self-test passed: $($catalog.Count) actions, $($backupSpecs.Count) registry backup groups."
    Return
}

If ($ListActions) {
    $catalog | Select-Object Id,Category,Name,Description,Reversible,@{n='CurrentState';e={Get-ActionState -ActionId $_.Id}} | Format-Table -AutoSize -Wrap
    Return
}

If ($Gui) {
    Hide-CompiledConsoleWindow
    Show-InstallerGui -Catalog $catalog -InitialTheme $Theme -InitialPreset $Preset
    Return
}

$forwardArguments = @()
If ($Actions) { $forwardArguments += @('-Actions',($Actions -join ',')) }
If ($Preset) { $forwardArguments += @('-Preset',$Preset) }
If ($Prerequisites) { $forwardArguments += @('-Prerequisites',$Prerequisites) }
If ($BackupOnly) { $forwardArguments += '-BackupOnly' }
If ($RestoreBackup) { $forwardArguments += @('-RestoreBackup',$RestoreBackup) }
If ($SettingsFile) { $forwardArguments += @('-SettingsFile',$SettingsFile) }
If ($PSBoundParameters.ContainsKey('ComputerName')) { $forwardArguments += @('-ComputerName',$ComputerName) }
If ($DriverSource) { $forwardArguments += @('-DriverSource',$script:RunOptions.DriverSource) }
If ($Theme) { $forwardArguments += @('-Theme',$Theme) }
If ($NoReboot) { $forwardArguments += '-NoReboot' }
If ($PauseOnExit) { $forwardArguments += '-PauseOnExit' }

If (!(Test-IsAdministrator)) {
    Write-Host "[$(timeStamp)] Administrator rights are required. Requesting elevation..." -ForegroundColor Yellow
    $null = Start-ElevatedSelf -ArgumentList $forwardArguments
    Return
}

$ProgressPreference = 'SilentlyContinue'
$offerReboot = $false
$resultCode = 0
Try {
    Initialize-Session
    If ($Prerequisites -eq 'Install') {
        PreRequisites -Items @($script:RunOptions.PrerequisiteItems)
    } ElseIf ($Prerequisites -eq 'Uninstall') {
        Uninstall-Prerequisites -Items @($script:RunOptions.PrerequisiteItems)
    } Else {
        $selectedActions = @(Resolve-ActionSelection -Catalog $catalog -Requested $Actions -PresetName $Preset)
        If ($RestoreBackup) {
            Restore-SettingsBackup -Path $RestoreBackup -ActionIds @($selectedActions.Id)
        } ElseIf ($BackupOnly) {
            $null = New-SettingsBackup -ActionIds @($selectedActions.Id)
        } Else {
            If ((Invoke-InstallerActions -SelectedActions $selectedActions) -gt 0) { $resultCode = 1 }
            $offerReboot = $true
        }
    }
} Catch {
    Write-Host "[$(timeStamp)] $($_.Exception.Message.Trim())" -ForegroundColor Red
    $resultCode = 1
} Finally {
    Complete-Session
    If ($SettingsFile) {
        Try {
            $resolvedSettings = [IO.Path]::GetFullPath($SettingsFile)
            $temporaryRoot = [IO.Path]::GetFullPath($script:RunOptionsRoot).TrimEnd('\') + '\'
            If ($resolvedSettings.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase)) {
                Remove-Item -LiteralPath $resolvedSettings -Force -ErrorAction SilentlyContinue
            }
        } Catch { }
    }
}

If ($PauseOnExit) {
    Write-Host "`nPress any key to close this window.." -ForegroundColor Cyan
    Try { $null=$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } Catch { $null=Read-Host }
}
If ($offerReboot -and !$NoReboot) { RebootNow }
If ($resultCode) { Exit $resultCode }
