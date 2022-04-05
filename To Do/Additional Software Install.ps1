
<#
snippet from https://www.snel.com/support/install-chrome-in-windows-server/
#>

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
