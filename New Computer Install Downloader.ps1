# Modified from https://gist.github.com/Splaxi/fe168eaa91eb8fb8d62eba21736dc88a

Param ([switch]$Gui)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Safety net: re-launch as admin if not already elevated
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $elevationArguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $MyInvocation.MyCommand.Path))
    If ($Gui) { $elevationArguments += '-Gui' }
    $elevated = Start-Process powershell.exe -ArgumentList $elevationArguments -Verb RunAs -Wait -PassThru
    Exit $elevated.ExitCode
}

$repo            = "Hor318/New-Computer-Install"
$filenamePattern = "*New*Computer*Install*.exe"
$preRelease      = $false

# Fetch release data in a single API call
If ($preRelease) {
    $releaseData = (Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$repo/releases")[0]
} Else {
    $releaseData = Invoke-RestMethod -Method GET -Uri "https://api.github.com/repos/$repo/releases/latest"
}

$version = $releaseData.tag_name
$asset = $releaseData.assets | Where-Object name -like $filenamePattern | Select-Object -First 1
$downloadUri = $asset.browser_download_url

If (-not $downloadUri) {
    Write-Error "Could not find a release asset matching '$filenamePattern'. Aborting."
    Exit 1
}

If ($version -notmatch '^[vV]?\d+\.\d+\.\d+(?:[.-][A-Za-z0-9]+)*$') { Throw "Unexpected release tag [$version]." }
$pathFile = "$env:Public\Desktop\New.Computer.Install $version.exe"
$downloadFile = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName() + '.exe')
$downloadMoved = $false

Try {
    Write-Output "Downloading version [$version] from [$downloadUri]"
    Invoke-WebRequest -Uri $downloadUri -OutFile $downloadFile -UseBasicParsing -ErrorAction Stop
    Write-Output "Download complete: $([Math]::Round((Get-Item $downloadFile).Length / 1MB,2)) MB"

    If ($asset.digest -match '^sha256:(?<Hash>[0-9a-fA-F]{64})$') {
        $actualHash = (Get-FileHash -LiteralPath $downloadFile -Algorithm SHA256).Hash
        If ($actualHash -ne $Matches.Hash) { Throw "Release checksum mismatch. Expected [$($Matches.Hash)], received [$actualHash]." }
        Write-Output 'GitHub release SHA-256 verified.'
    } Else {
        Write-Warning 'This release does not publish a SHA-256 digest; HTTPS transport is the only integrity check.'
    }

    If (Test-Path -LiteralPath $pathFile) {
        $pathFile = "$env:Public\Desktop\New.Computer.Install $version-$([guid]::NewGuid().ToString('N')).exe"
    }
    Move-Item -LiteralPath $downloadFile -Destination $pathFile
    $downloadMoved = $true
    $installer = If ($Gui) { Start-Process -FilePath $pathFile -ArgumentList '-Gui' -Wait -PassThru }
    Else { Start-Process -FilePath $pathFile -Wait -PassThru }
    Exit $installer.ExitCode
} Finally {
    Remove-Item -LiteralPath $downloadFile -Force -ErrorAction SilentlyContinue
    If ($downloadMoved) { Remove-Item -LiteralPath $pathFile -Force -ErrorAction SilentlyContinue }
}
