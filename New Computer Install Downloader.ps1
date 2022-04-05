
# Modified from https://gist.github.com/Splaxi/fe168eaa91eb8fb8d62eba21736dc88a

If (!( [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )) {
    Start-Process powershell.exe "-File",( '"{0}"' -f $MyInvocation.MyCommand.Path ) -Verb RunAs
    Exit
}

Set-ExecutionPolicy RemoteSigned -force

$repo = "Hor318/New-Computer-Install"
$owner = $repo -Split '/' | Select -First 1
$repoName = $repo -Split '/' | Select -Last 1

$filenamePattern = "*New.Computer.Install.exe*"

$preRelease = $false

$version = Invoke-WebRequest -Uri "https://api.github.com/repos/Hor318/New-Computer-Install/releases/latest" -UseBasicParsing
$version = ( $version.content | ConvertFrom-Json ).tag_name

If ( $preRelease ) {
    $releasesUri = "https://api.github.com/repos/$repo/releases"
    $downloadUri = (( Invoke-RestMethod -Method GET -Uri $releasesUri )[0].assets | Where-Object name -like $filenamePattern ).browser_download_url
} Else {
    $releasesUri = "https://api.github.com/repos/$repo/releases/latest"
    $downloadUri = (( Invoke-RestMethod -Method GET -Uri $releasesUri ).assets | Where-Object name -like $filenamePattern ).browser_download_url
}

$pathNoVer = "$env:Public\Desktop\New.Computer.Install"
$pathFile = "$env:Public\Desktop\New.Computer.Install $version.exe"

If ( Test-Path "$pathNoVer*.exe" ) { 
    ForEach ( $p in $( Get-ChildItem "$pathNoVer*.exe" )) {
        Write-Warning "File [$( $p.FullName )] found. Removing and redownloading" 
    }

    Remove-Item "$pathNoVer*.exe" -Force 
}

# Defender exclusions to allow .exe to run
Add-MpPreference -ExclusionPath "$env:TEMP\Quest Software"
Add-MpPreference -ControlledFolderAccessAllowedApplications $pathFile

Invoke-WebRequest -Uri $downloadUri -Out $pathFile #$pathZip
    Write-Output "Variable Summary: `nOwner: [$owner] `nRepo Name: [$repoName] `nFilename Pattern: [$filenamePattern] `nPath Extract: [$pathExtract] `nInner Directory [$innerDirectory]"

# Start .exe and run prerequisites if choco is not detected
$TARGETDIR = 'C:\ProgramData\Chocolatey\choco.exe'
    If (!( Test-Path -Path $TARGETDIR )) {
        Start-Process $pathFile -Wait -Verb Runas
    }

# Remove prerequisite log
$winTemp = [System.Environment]::GetEnvironmentVariable('TEMP','Machine')
$fileContent = Get-ChildItem $winTemp | Where-Object { $_.Name -like "New Computer Install*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1 
    If ( $fileContent.Length -lt '5000' ) { Remove-Item $fileContent.FullName -Force }

Start-Process $pathFile -Wait -Verb Runas

1..10 | ForEach-Object {
    If ( Test-Path "$env:PROGRAMFILES\Google\Chrome\Application\chrome.exe" ) { Continue } Else {
        choco upgrade googlechrome -y --limit-output
        start-sleep -s 1
    }
    If ( Test-Path "$env:PROGRAMFILES\7-Zip\7zFM.exe" ) { Continue } Else {
        choco upgrade 7zip -y --limit-output
        start-sleep -s 1
    }
}   

Remove-Item $pathFile -Force

# Remove Defender exclusions to allow .exe to run
Remove-MpPreference -ExclusionPath "$env:TEMP\Quest Software"
Remove-MpPreference -ControlledFolderAccessAllowedApplications $pathFile
