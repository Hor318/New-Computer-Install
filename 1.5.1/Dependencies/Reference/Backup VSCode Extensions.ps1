
Function BackupVSExts {
    Param(
    [Parameter(Mandatory)]
    $outPath
    )

    $VSCodeExtensions = code --list-extensions
    $VSCodeExtensions | Out-File $outPath -Append -Encoding UTF8
    Get-Content $outPath | Select-Object -Unique | Sort-Object | Set-Content $outPath -Encoding UTF8

        If (( Get-Content $outPath ).Count -ne 0 ) { 
            Write-Host "VSCode Extensions have successfully been backed up to [$outPath]" -ForegroundColor Green
         } Else {
            Write-Warning "VSCode Extensions failed to back up to [$outPath]. Please investigate manually."
         }
}

BackupVSExts -outPath 'C:\Projects\New-Computer-Install\Dependencies\Reference\VSCodeExtensions.txt'
