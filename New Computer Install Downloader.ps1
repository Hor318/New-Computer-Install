# Modified from https://gist.github.com/Splaxi/fe168eaa91eb8fb8d62eba21736dc88a

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    Exit
}

Set-ExecutionPolicy RemoteSigned -Force

$repo            = "Hor318/New-Computer-Install"
$filenamePattern = "*New.Computer.Install.exe*"
$preRelease      = $false

If ($preRelease) {
    $releaseData = (Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$repo/releases")[0]
} Else {
    $releaseData = Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$repo/releases/latest"
}

$version     = $releaseData.tag_name
$downloadUri = ($releaseData.assets | Where-Object name -like $filenamePattern).browser_download_url

If (-not $downloadUri) {
    Write-Error "Could not find a release asset matching '$filenamePattern'. Aborting."
    Exit 1
}

$pathNoVer = "$env:Public\Desktop\New.Computer.Install"
$pathFile  = "$env:Public\Desktop\New.Computer.Install $version.exe"

# Remove any existing version before downloading the latest
$existing = Get-ChildItem "$pathNoVer*.exe" -ErrorAction SilentlyContinue
If ($existing) {
    ForEach ($p in $existing) {
        Write-Warning "Found existing file [$($p.FullName)]. Removing before redownloading."
    }
    Remove-Item "$pathNoVer*.exe" -Force
}

Write-Output "Downloading version [$version] from [$downloadUri] to [$pathFile]"

Add-MpPreference -ExclusionPath "$env:TEMP\Quest Software"
Add-MpPreference -ControlledFolderAccessAllowedApplications $pathFile

Invoke-WebRequest -Uri $downloadUri -OutFile $pathFile

Start-Process $pathFile -Wait -Verb RunAs

# Clean up: remove the downloaded exe and Defender exclusions
Remove-Item $pathFile -Force -ErrorAction SilentlyContinue
Remove-MpPreference -ExclusionPath "$env:TEMP\Quest Software"
Remove-MpPreference -ControlledFolderAccessAllowedApplications $pathFile
