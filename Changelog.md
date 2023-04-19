_____________________
# Changelog
### Newly added features will be updated here. I have added the old versions to the best of my ability.

------------------------------------------------------------------
##### Version: 1.4.6
    - Removed weather widget on windows 11 PC's
------------------------------------------------------------------
##### Version: 1.4.5
    - Add GPU detection (AMD + NVIDIA) + driver installation as part of the prerequisites 
------------------------------------------------------------------
##### Version: 1.4.4
    - Improved bloatware removal
------------------------------------------------------------------
##### Version: 1.4.3
    - Added function to restore Win10 context menu on Win11 - *Note: This will not run on any devices lower than build 22000 (Win11)*
------------------------------------------------------------------
##### Version: 1.4.2
    - Added function to Block Apps from downloading automatically
    - Added function to disable User Experience Reporting
    - Added function to disable the first logon animation "Hi! We're installing the apps..."
    - Added additional exception to bloatware removal for Win11 Notepad app
------------------------------------------------------------------
##### Version: 1.4.1
    - Updated chrome function to include a fallback method in case chocolatey failed
------------------------------------------------------------------
##### Version: 1.4.0
    - Added a loop to attempt to resolve chrome / 7zip install (*fixed in 1.4.1 with a fallback for chrome -- 7 zip was working properly)
------------------------------------------------------------------
##### Version: 1.3.9
    - Internal update to fix formatting to tabbed indentation (4x spaces) globally
------------------------------------------------------------------
##### Version: 1.3.8
    - Update code for legacy windows photo viewer to add reg keys and associations instead of importing reg file
    - Updated function for photo viewer to include Parameters
------------------------------------------------------------------
##### Version: 1.3.7
    - Updated rename computer name function to also include default server names in the check
    - Added secondary software update check and edited text in module updater
    - Created a downloader script to retrieve the newest binary from github and call the main scripts
------------------------------------------------------------------
##### Version: 1.3.6
    - Added a check for OEM information. Creates information if it is missing and copies over logo if missing
------------------------------------------------------------------
##### Version: 1.3.5
    - Updated relaunch function to attempt to avoid crashing and added elapsed time into the script
    - Updated binary manifest to require administrative rights and added instructions to do this in Dependencies
------------------------------------------------------------------
##### Version: 1.3.4
    - Code cleanup and improvements on logging
    - Updated function for the time zone to support Parameters
------------------------------------------------------------------
##### Version: 1.3.3
    - Changed call order of WindowsUpdate function to an earlier time due to a potential restart background
------------------------------------------------------------------
##### Version: 1.3.2
    - Updated WindowsUpdate function to include an automated GUI interaction for better results
------------------------------------------------------------------
##### Version: 1.3.1
    - Massive code cleanup
    - Added a check for the computer name during the Rename Computer function
------------------------------------------------------------------
##### Version: 1.3.0
    - Initial github release - see readme.md for info
    - Migrated local script + dependencies to github

This is a list of features, but not necessarily in the order they are executed:

    - Add 'This PC' to the desktop [User]
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
    - Install a basic set of software via chocolatey (7zip / Adobe Reader / Google Chrome / Java)
    - Install missing drivers for hardware
    - Install available detected windows updates
    - Launch explorer processes in a separate process [User]
    - Modify OEM Information if it does not already exist
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
------------------------------------------------------------------
