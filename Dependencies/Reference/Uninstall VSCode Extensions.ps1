
Function RemoveVSExts {
    Param(
    [Parameter(Mandatory)]
    $extList
    )

    $VSInstall  = ( Get-Content $extList )
        ForEach ( $v in $VSInstall ) { code --install-extension $v }

}

RemoveVSExts -extList 'C:\Projects\New-Computer-Install\Dependencies\Reference\VSCodeExtensions.txt'
