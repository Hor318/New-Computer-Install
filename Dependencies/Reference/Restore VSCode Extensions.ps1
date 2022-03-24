
Function RestoreVSExts {
    Param(
    [Parameter(Mandatory)]
    $extList,
    [Boolean]
    $autoUpdate = $False
    )

    $VSInstall  = ( Get-Content $extList )
        If ( $autoUpdate ) {
            ForEach ( $v in $VSInstall ) { code --install-extension $v --force }
        } Else {
            ForEach ( $v in $VSInstall ) { code --install-extension $v }
        }
}

RestoreVSExts -extList 'C:\Projects\New-Computer-Install\Dependencies\Reference\VSCodeExtensions.txt' -autoUpdate $True
