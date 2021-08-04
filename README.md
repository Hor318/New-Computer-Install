_______________
# New-Computer-Install
_______________

>! Use at your own risk. I am not responsible for any damage that may be caused by running this script. It is expected that you will fully read the script prior to running on any production systems!

_______________
## How do I run this?
_______________

Easy! Either download the .ps1 file, right click, and run with powershell... Or download the latest release from the release page
> [Releases](https://github.com/aar318/New-Computer-Install/releases)

After you run it the program will prompt for admin credentials and then just follow the on screen prompts (95% automated currently with a couple of confirmation prompts and a computer name change)

_______________
## What does it do?
_______________
This is a summary of the script's functions

1. Prerequisites for the script to run
  >    - Chocolatey
  >    - Nuget
  >    - Powershell 5.0+
  >    - PSWindowsUpdate Module
2. Display a friendly Weather report
3. Disable various settings and features 
4. Enable Plug and Play devices that may not be showing up
5. Install missing drivers for devices
6. Remove bloatware
7. Set the timezone to Eastern
8. Set update settings
9. Set various quality of life settings
10. Tweak the interface display settings  
11. Rename computer
12. Offer to reboot to apply various changes

_______________
## Features
_______________
> The features listed apply to the system unless [User] is specified
> This is a list of features, but not necessarily in the order they are executed

    - Add This PC to the desktop [User]
    - Adjust power settings to high performance
    - Auto Arrange icons and align them to tiles [User]
    - Cleanup misc installation / driver files
    - Disable app suggestions and installation for OEM / Subscription apps [User]
    - Disable fast startup
    - Disable IPv6 Components without conflicting with the system
    - Disable meet now [User]
    - Disable news and interests from the taskbar [User]
    - Disable show suggestions in the start menu [User]
    - Disable smart screen through defender
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
    - Install a basic set of software via chocolatey
      > 7zip / Adobe Reader / Google Chrome / Java
    - Install missing drivers for hardware
    - Install available detected windows updates
    - Launch explorer processes in a separate process [User]
    - Open File Explorer to This PC [User]
    - Prevent windows from turning off network adapter to save power
    - Remove bloatware except for defined exceptions [User]
    - Scheduled task to clean up %temp% folder [User]
    - Set allowed Windows Update hours
    - Set computer name
    - Set default control panel view [User]
    - Set default time zone to Eastern
    - Software Distribution cleanup
    - Turn off App Suggestions [User]
    - Turn off silent installation of Suggested Apps [User]
    - Turn on Num Lock at startup

> Additional features courtesy of Sophia script - https://github.com/farag2/Windows-10-Sophia-Script 

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
_______________
> "C:\Windows\Temp\New Computer Install" + "-" + $Date + ".log"
