
# https://github.com/pratyakshm/WinRice/blob/main/WinRice.ps1
# GNU GENERAL PUBLIC LICENSE
# https://github.com/pratyakshm/WinRice/blob/main/LICENSE

# set functions to a task and use a one liner to call each of them at the end? 
# alternatively leave functions as is and use parameters for each of them

$tasks = @(
    ### Maintenance Tasks ###
        "WinRice",
        "OSBuildInfo",
        "CreateSystemRestore",
        "Activity",
    
    ### Apps & Features ###
        "AppsFeatures",
        "InstallRuntimes",
        # "UninstallRuntimes",
        "InstallWinGet",
        "EnableExperimentsWinGet",
        # "DisableExperimentsWinGet",
        "MicrosoftStore",
        "Install7zip", 
        # "Uninstall7zip",
        "WinGetImport",
        "Winstall", 
        "InstallHEVC", 
        # "UninstallHEVC",
        "Widgets",
        "InstallFonts", 
        # "UninstallFonts",
        "UninstallApps", "Activity", 
        "WebApps",
        "UninstallConnect",
        "UnpinStartTiles", "Activity", 
        "UnpinAppsFromTaskbar", 
        "UninstallOneDrive", "Activity",
        # "InstallOneDrive",
        "UninstallFeatures", "Activity", 
        # "InstallFeatures", "Activity", 
        "EnableWSL", "Activity", 
        # "DisableWSL",
        "EnabledotNET3.5", "Activity", 
        # "DisabledotNET3.5",
        "EnableSandbox",
        # "DisableSandbox",
        "SetPhotoViewerAssociation",
        # "UnsetPhotoViewerAssociation",
        "ChangesDone",
        
    ###  Tasks after successful run ###
        "Activity",
        "Success"
    )

# Call the desired functions.
$tasks | ForEach-Object { Invoke-Expression $_ }