_______________
# Aar318's New Computer Install

```diff
- !! USE AT YOUR OWN RISK. I am not responsible for any damage that may be caused by running this script
-      It is expected that you will fully read the script prior to running on any production systems !!
```
_______________
## How do I run this?

### Version 2.0.0

- Double-click `New Computer Install.exe` to run the complete original workflow.
- Double-click `New Computer Install GUI.bat` to download the current GitHub release and launch its selectable GUI (dark mode by default; light mode is available in the header).
- Double-click `New Computer Install GUI Local.bat` to test only the EXE or PowerShell source in the current folder; it never connects to GitHub.
- To test the local build before publishing it, run `.\New Computer Install.exe -Gui` from PowerShell.
- Run selected actions from PowerShell with `.\New Computer Install.exe -Actions TimeZone,FastStartup,WindowsUpdates`.
- Choose a preset with `-Preset Full`, `-Preset Minimal`, or use `-Preset Custom -Actions ...`. Full remains the default; repairs and report export are opt-in.
- List every CLI action ID and description with `.\New Computer Install.exe -ListActions`.
- Rename directly from CLI with `.\New Computer Install.exe -Actions RenameComputer -ComputerName "OFFICE-PC"`.
- For CLI customization, copy `Run Options.example.json`, edit it, then add `-SettingsFile ".\My Run Options.json"`.
- Double-click `Build New Computer Install.bat` to rebuild the EXE. The build script installs the `ps2exe` build module for the current user when needed.

The build batch shows source validation, build-module setup, and compilation stages. Its generated EXE contains a `requireAdministrator` manifest, so Windows requests elevation when the EXE launches. The generated EXE is ignored by Git and GitHub Desktop; publish it separately as a release asset when needed.

The GUI creates a timestamped JSON settings backup under `%TEMP%\New Computer Install\Backups` before it applies selected changes. Backups can be exported, imported, and restored per selected option. Live state indicators complete a staggered refresh every three seconds while the elevated PowerShell process runs: green is applied, red is not applied, and orange means partial, needs input, unavailable, or checked only when run. Every option has its own Run Now control, and its state is checked again automatically when the elevated operation finishes. Weather launched from the GUI closes its console automatically and loads the cached current-day forecast into the Weather details pane. Repairs have their own view with individual and Run All controls. The hardware-report option includes an embedded summary plus a View Full Report screen for the branded HTML export; the report header includes Ko-fi, Donate, localized generation time, and version attribution. Reports use one HTML/JSON pair per computer per day, replace that day when rerun, and retain the latest three days. The saved JSON also supplies the cached GUI summary without collecting the hardware inventory again. The tool attempts one pre-change System Restore point per day, so rerunning after a reboot does not create a trail of duplicate restore points. Software installs, updates, bloatware removal, component cleanup, driver work, and other operations marked **Backup: No** are not automatically reversible.

*Note: You may need to set your execution policy for it to run smoothly. To do so open an elevated powershell session, type ``` Set-ExecutionPolicy RemoteSigned ``` and hit Enter*

It's easy! Either download the .ps1 file, right click, and run with powershell (Additional option to now use [This-Batch-File](https://github.com/Hor318/New-Computer-Install/blob/main/New%20Computer%20Install%20Launch.bat) )... Or download the latest release from the release page (see changelog below for changes)
> [Releases](https://github.com/aar318/New-Computer-Install/releases)

> [ChangeLog](https://github.com/Hor318/New-Computer-Install/blob/main/Changelog.md)

The program requests administrator access only when it is ready to apply changes. Console output is also saved to a timestamped log in `C:\Windows\Temp`.

The clean header consistently shows **Ko-fi**, **Donate**, and **v2.0.0 by Hor318**. The GUI and compiled EXE use the included project icon.

The included build batch compiles the PowerShell script as a console-capable EXE so full-run and selected-run output remains visible.

Long-running PowerShell progress rendering is suppressed because compiled console hosts can print each refresh as another line. Milestone messages, warnings, errors, and the final log remain visible. Missing PackageManagement or PowerShellGet modules are bootstrapped from the official PowerShell Gallery before prerequisite installation continues.

*Alternatively you can run the [New Computer Install Downloader.ps1](https://github.com/Hor318/New-Computer-Install/blob/main/New%20Computer%20Install%20Downloader.ps1) to download the latest version and launch it automatically*
_______________
## What does it do?

This is a summary of the script's functions

1. Installs Prerequisites for the script to run
      - WinGet, with Chocolatey retained as a fallback
      - Nuget
      - Powershell 5.0+
      - PSWindowsUpdate Module
      - Detects and installs drivers for GPU
2. Prefill and edit OEM support information
3. Display wttr.in's detailed local forecast for the current day
4. Disable various settings and features
5. Enable Plug and Play devices that may not be showing up
6. Install missing drivers for devices
7. Remove bundled bloatware and registered McAfee products (includes exception list)
8. Set the timezone to Eastern (customize via function parameters)
9. Set Windows Updates default settings
10. Set various quality of life settings
11. Tweak the interface display settings  
12. Rename the computer from the GUI or CLI, with an automatic prompt for default DESKTOP/WIN names
13. Offer to reboot to apply various changes
14. Provision Chrome as the web default and Adobe Reader as the PDF default for new Windows profiles
15. Install AdGuard in Chrome and Edge for current and future browser profiles
16. Enable supported Storage Sense maintenance, Win32 long paths, and visible file extensions
17. Apply privacy defaults that disable advertising ID, activity upload, tailored experiences, peer update sharing, and location access
18. Keep DNS dynamic by default, with Cloudflare, Quad9, Google, and AdGuard choices
19. Show live applied-state checks and provide opt-in Windows, Update, network, and WinGet repairs
20. Preview and export a CIM-based hardware and health report as HTML and JSON

_______________
## Features

> The features listed apply to the system unless [User] is specified
>
> This is a list of features, but not necessarily in the order they are executed:

    - Add 'This PC' to the desktop [User]
    - Use High Performance power settings by default, with Balanced available as an option
    - Auto Arrange icons and align them to tiles [User]
    - Enable monthly Storage Sense cleanup and start Windows' built-in component cleanup task
    - Detects and installs drivers for GPU
    - Disable app suggestions and installation for OEM / Subscription apps [User]
    - Disable automatic downloading of apps
    - Disable fast startup
    - Disable first login animation (Hi! We're installing...)
    - Prefer IPv4 without disabling required Windows IPv6 components
    - Disable meet now [User]
    - Disable news and interests from the taskbar [User]
    - Disable show suggestions in the start menu [User]
    - Keep Microsoft Defender SmartScreen enabled for downloaded applications
    - Disable User Experience Reporting [User]
    - Disable windows from managing default printers [User]
    - Discover PnP devices
    - Display the network button on the lock screen
    - Display the shutdown button on the lock screen
    - Enable legacy F8 boot menu
    - Enable legacy Windows Photo Viewer
    - Enable Win32 long-path support for compatible applications
    - Enable restore points and set a default 10 gb of shadow copy storage
    - Enable verbose login status messages
    - Hide People Taskbar icon [User]
    - Hide Task View on the taskbar [User]
    - Hide Windows Ink Workspace [User]
    - Install a basic set of software through WinGet first, with Chocolatey as a fallback (7-Zip / Adobe Reader / Google Chrome / Java via Eclipse Temurin OpenJDK / Edge)
    - Install missing drivers for hardware
    - Install available detected windows updates
    - Launch explorer processes in a separate process [User]
    - Edit OEM manufacturer, support phone, support URL, and logo information
    - Open File Explorer to This PC [User]
    - Show file name extensions in File Explorer [User]
    - Prevent windows from turning off network adapter to save power
    - Remove a conservative list of known consumer and promotional bloatware without deleting unknown Windows components
    - Remove registered McAfee / WebAdvisor desktop products and provisioned Store packages
    - Remove widget for news, weather, alerts, etc. from taskbar in Win11
    - Use the classic Windows 10 context menu (no "More Options" in Windows 11)
    - Set editable Windows Update active hours, defaulting to 8 PM through 5 AM when the fields are blank
    - Set the computer name from GUI, CLI, or a prompt for default names
    - Set default control panel view [User]
    - Set default time zone to Eastern (can specify timezone via parameter)
    - Turn off App Suggestions [User]
    - Turn off silent installation of Suggested Apps [User]
    - Turn on Num Lock at startup
    - Provision Chrome and Adobe Reader default associations for every new Windows profile
    - Force-install AdGuard from the official stores in Chrome and Edge for all browser profiles
    - Choose Full (default), Minimal, or Custom GUI/CLI presets
    - Run repair tools separately: DISM/SFC, Windows Update reset, network reset, and WinGet repair
    - Export a modern hardware and health report without legacy WMI or `Win32_Product`
    - Optionally disable Windows Copilot, Recall, Click to Do, Edge AI, and Notepad Rewrite policies, with a separate Copilot Appx removal choice

Windows protects the current user's default-app choices with a signed UserChoice value. The installer therefore uses Microsoft's supported DISM provisioning path, which applies Chrome and Adobe defaults automatically to **new** Windows profiles without overriding an existing user's choice. AdGuard uses machine browser policy, so it applies to existing and future Chrome and Edge profiles.

The Windows AI action is inspired by [zoicware/RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI), but intentionally uses a small business-safe subset. It is disabled in both Full and Minimal presets. CoreAI/CBS packages, Defender components, system files, and scheduled tasks are preserved; only the explicitly named Copilot Appx packages can optionally be removed.

_______________
> Additional features courtesy of [Sophia script](https://github.com/farag2/Windows-10-Sophia-Script)

    - Disable app smart screen
    - Disable silent installing of apps [User]
    - Disable windows from managing default printers [User]
    - Disable windows ink workspace [User]
    - Enable Num Lock on boot
    - Set default control panel view to large icons
    - Set Windows Explorer to launch in separate processes [User]
    - Set Windows Explorer to launch to This PC

_______________
### A detailed log of the installation process can be found here
> "C:\Windows\Temp\Aar318's New Computer Install" + "-" + $Date + ".log"
_______________
