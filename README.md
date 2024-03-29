_______________
# New-Computer-Install

```diff
- !! USE AT YOUR OWN RISK. I am not responsible for any damage that may be caused by running this script
-      It is expected that you will fully read the script prior to running on any production systems !!
```
_______________
## How do I run this?

*Note: You may need to set your execution policy for it to run smoothly. To do so open an elevated powershell session, type ``` Set-ExecutionPolicy RemoteSigned ``` and hit Enter*

It's easy! Either download the .ps1 file, right click, and run with powershell (Additional option to now use [This-Batch-File](https://github.com/Hor318/New-Computer-Install/blob/main/New%20Computer%20Install%20Launch.bat) )... Or download the latest release from the release page (see changelog below for changes)
> [Releases](https://github.com/aar318/New-Computer-Install/releases)

> [ChangeLog](https://github.com/Hor318/New-Computer-Install/blob/main/Changelog.md)

After you run it the program will prompt for admin credentials and then just follow the on screen prompts (95% automated currently with a couple of confirmation prompts and a computer name change)

If you would like to compile it yourself you will need to compile the powershell files and dependencies using a .net compiler and then modify the compiled exe's manifest to self elevate. 

*Alternatively you can run the [New Computer Install Downloader.ps1](https://github.com/Hor318/New-Computer-Install/blob/main/New%20Computer%20Install%20Downloader.ps1) to download the latest version and launch it automatically*
_______________
## What does it do?

This is a summary of the script's functions

1. Installs Prerequisites for the script to run
      - Chocolatey
      - Nuget
      - Powershell 5.0+
      - PSWindowsUpdate Module
      - Detects and installs drivers for GPU
2. Modify OEM Information if it is missing
3. Display a friendly local Weather report
4. Disable various settings and features
5. Enable Plug and Play devices that may not be showing up
6. Install missing drivers for devices
7. Remove bloatware (includes exception list)
8. Set the timezone to Eastern (customize via function parameters)
9. Set Windows Updates default settings
10. Set various quality of life settings
11. Tweak the interface display settings  
12. Rename computer if it is set to the default DESKTOP-whatever
13. Offer to reboot to apply various changes

_______________
## Features

> The features listed apply to the system unless [User] is specified
>
> This is a list of features, but not necessarily in the order they are executed:

    - Add 'This PC' to the desktop [User]
    - Adjust power settings to high performance
    - Auto Arrange icons and align them to tiles [User]
    - Cleanup misc installation / driver files
    - Detects and installs drivers for GPU
    - Disable app suggestions and installation for OEM / Subscription apps [User]
    - Disable automatic downloading of apps
    - Disable fast startup
    - Disable first login animation (Hi! We're installing...)
    - Disable IPv6 Components without conflicting with the system
    - Disable meet now [User]
    - Disable news and interests from the taskbar [User]
    - Disable show suggestions in the start menu [User]
    - Disable smart screen through defender
    - Disable User Experience Reporting [User]
    - Disable windows from managing default printers [User]
    - Discover PnP devices
    - Display the network button on the lock screen
    - Display the shutdown button on the lock screen
    - Enable legacy F8 boot menu
    - Enable legacy Windows Photo Viewer
    - Enable restore points and set a default 10 gb of shadow copy storage
    - Enable verbose login status messages
    - Hide People Taskbar icon [User]
    - Hide Task View on the taskbar [User]
    - Hide Windows Ink Workspace [User]
    - Install a basic set of software via chocolatey (7zip / Adobe Reader / Google Chrome / Java) - **Note: I have added a backup method for chrome due to consistent issues with the chocolatey method**
    - Install missing drivers for hardware
    - Install available detected windows updates
    - Launch explorer processes in a separate process [User]
    - Modify OEM Information if it does not already exist
    - Open File Explorer to This PC [User]
    - Prevent windows from turning off network adapter to save power
    - Remove bloatware except for defined exceptions [User]
    - Remove widget for news, weather, alerts, etc. from taskbar in Win11
    - Revert context menu to Win10 (no "More Options" in Win11)
    - Scheduled task to clean up %temp% folder [User]
    - Set allowed Windows Update hours
    - Set computer name (checks for default names and prompts to rename)
    - Set default control panel view [User]
    - Set default time zone to Eastern (can specify timezone via parameter)
    - Software Distribution cleanup
    - Turn off App Suggestions [User]
    - Turn off silent installation of Suggested Apps [User]
    - Turn on Num Lock at startup

_______________
> Additional features courtesy of [Sophia script](https://github.com/farag2/Windows-10-Sophia-Script)

    - Create a cleanup task for the software distribution folder
    - Create a cleanup task for temporary files
    - Disable app smart screen
    - Disable app suggestions [User]
    - Disable silent installing of apps [User]
    - Disable windows from managing default printers [User]
    - Disable windows ink workspace [User]
    - Enable Num Lock on boot
    - Set default control panel view to large icons
    - Set Windows Explorer to launch in separate processes [User]
    - Set Windows Explorer to launch to This PC

_______________
### A detailed log of the installation process can be found here
> "C:\Windows\Temp\New Computer Install" + "-" + $Date + ".log"
_______________