_____________________
# Changelog
### Newly added features will be updated here. I have added the old versions to the best of my ability.

------------------------------------------------------------------
##### Version: 2.0.1
    - Skipped the legacy News and Interests policy on unsupported Windows builds and editions.
    - Applied the network adapter power-off setting only to physical adapters that expose it, so unsupported Wi-Fi adapters no longer abort the action.
    - Added automatic Microsoft Update Catalog discovery and installation for devices still in error after the initial driver pass. Matches device IDs and platform, verifies download hashes and driver signatures, and respects managed Windows Update restrictions.
    - Matched regular and optional Windows Update drivers to present problem devices by hardware and compatible IDs. Added a targeted Code 43 restart and verified the device state after repair.
    - Logged individual driver package failures and hardware IDs for unresolved devices. Added a local OEM INF source for offline or unavailable Windows Update drivers.
    - Fixed module loading on fresh Windows PowerShell installs with a process-only RemoteSigned policy when the effective policy is Restricted and Group Policy permits it.
    - Installed, updated, and verified PSWindowsUpdate automatically from either Prerequisites or Windows Updates. Kept reboot-required updates eligible without prompting for an immediate restart.
    - Suppressed repeated Chocolatey download progress and verbose Windows Update output, with concise action failure messages.
    - Refreshed provisioned app inventory after installed app removal and continued processing packages after an individual error.
    - Fixed Windows Update driver-search failures terminating the entire installation. Driver searches now use the PC's configured update source.
    - Continued setup after individual prerequisite, package, driver, and repair failures. Recorded failures in the final summary and process exit code.
    - Isolated default-app backup failures and skipped reversible actions whose settings could not be backed up.
    - Preserved existing registry values when applying or restoring settings and restored DNS addresses per protocol family.
    - Protected existing release EXEs during downloads, reported native repair failures, and limited elevated desktop uninstallers to machine registrations.
    - Added a self-test that reproduces the driver failure and verifies that later actions still run.

------------------------------------------------------------------
##### Version: 2.0.0
    - Branded the project as Aar318's New Computer Install with a new GUI, taskbar, and EXE icon
    - Added a selectable dark/light GUI with 60 individual setup, privacy, diagnostics, and repair options with contextual customization panels
    - Added Full (default), Minimal, and Custom presets shared by the GUI and CLI
    - Added one automatic pre-change System Restore point attempt per day for safe repeat runs
    - Added opt-in DISM/SFC, Windows Update, network-stack, and WinGet repairs
    - Made WinGet the primary software installer while retaining Chocolatey as a fallback
    - Added an embedded CIM-based hardware/health summary with customizable HTML and JSON export
    - Added privacy defaults for advertising ID, activity upload, tailored experiences, peer update sharing, and location access
    - Added Dynamic/DHCP DNS as the default with Cloudflare, Quad9, Google, and AdGuard options
    - Added refreshable applied-state detection to the GUI and `-ListActions`
    - Changed GUI state detection to live three-second updates with green, red, and orange status indicators
    - Added a dedicated Repairs view with individual Run buttons, Run All, and Back to Setup navigation
    - Kept the GUI open while elevated work runs so live states and report results can update afterward
    - Fixed the hardware-summary volume expression and left the summary blank until the report is run
    - Clarified Java as Eclipse Temurin OpenJDK and expanded descriptions for less-obvious Windows settings
    - Rendered the existing project artwork from its high-resolution PNG and added a 64-pixel embedded-EXE fallback
    - Added a standalone Run Hardware Report Now button directly below the embedded diagnostics summary
    - Added a branded, fully embedded HTML report viewer with Ko-fi, Donate, and green version attribution
    - Added a modern Run Now button to every individual setup option and automatic state updates afterward
    - Moved option descriptions below a dedicated title row so long names and descriptions remain readable
    - Removed the redundant manual state refresh button now that state monitoring is live
    - Restored wttr.in's detailed, colored current-day forecast with automatic ANSI-safe fallback
    - Cached completed weather results in the GUI details pane and removed the GUI-launched console pause
    - Deferred and batched live-state checks so the GUI paints immediately and remains responsive on slower PCs
    - Loaded hardware summaries from the saved JSON report instead of repeating the CIM inventory
    - Changed report names to one file per computer per day and retained only the latest three daily report pairs
    - Localized the generated timestamp shown in the HTML report
    - Added editable Windows Update active-hour fields with the existing 20:00-05:00 defaults when blank
    - Added an opt-in Windows AI action, excluded from Full and Minimal, with reversible Copilot/Recall/Edge/Notepad policies and optional Copilot Appx removal
    - Kept risky TrustedInstaller, CBS, Defender, system-file, and scheduled-task removal out of routine business provisioning
    - Added a requireAdministrator manifest to the compiled EXE and visible validation/module/compile stages to the build batch
    - Ignored the generated New Computer Install EXE in Git/GitHub Desktop
    - Preserved the original full console run when launched without switches
    - Added automatic temporary settings backups plus individual restore, import, and export
    - Added manual prerequisite install and removal controls
    - Added Ko-fi and Donate buttons
    - Added editable, prefilled OEM support information
    - Removed the unused legacy Dependencies folder from v2.0.0 and retained it in the v1.5.1 archive
    - Made the editable OEM logo optional instead of bundling obsolete artwork
    - Added selectable prerequisite and common-software components
    - Added registered McAfee / WebAdvisor and provisioned package removal
    - Replaced broad Appx removal with a conservative target list to avoid deleting unknown Windows components
    - Fixed compiled prerequisite runs by explicitly loading or bootstrapping PackageManagement and PowerShellGet
    - Changed long-running save progress to concise single-line status messages
    - Changed the GUI launcher to download the current GitHub release and pass the GUI switch through the downloader
    - Allowed the release downloader to recognize EXE asset names that use spaces, periods, or version text
    - Fixed GUI launcher visibility while preserving the original project icon in the window, taskbar, and EXE
    - Added a separate local-only GUI launcher for offline development and testing
    - Fixed the GUI options and customization panels being hidden by an invalid initial splitter size
    - Fixed the enlarged header icon rendering as corrupted pixels and made the version/byline green
    - Fixed the local source fallback being hidden with its PowerShell window
    - Made dark/light theme switching immediate by avoiding automatic resizing and repeated DataGridView repaint work
    - Added an editable computer-name field plus matching `-ComputerName` and `-ListActions` CLI options
    - Replaced obscure Sophia-facing text and removed its duplicate Start-suggestions action
    - Replaced malformed custom cleanup tasks with supported Storage Sense policy and Windows component cleanup
    - Added Win32 long-path and visible file-extension quality-of-life options
    - Added per-run completed/failed action summaries and terminating error capture per action
    - Replaced legacy command patterns with explicit CIM, registry, COM, sleep, and downloaded-installer handling
    - Replaced full IPv6 disablement with Microsoft's recommended IPv4 preference, kept SmartScreen enabled, and made Balanced/High Performance selectable
    - Added supported Chrome and Adobe default-app provisioning for every new Windows profile
    - Added machine-wide AdGuard deployment for Chrome and Edge
    - Renamed the Windows 11 context-menu option to the clearer classic Windows 10 context menu
    - Added one-click GUI launcher and EXE build scripts
    - Kept timestamped console transcripts while improving error visibility
    - Fixed elevation argument forwarding, duplicate device scans, repeated Chrome fallback installs, and unnecessary Windows Update delays
    - Replaced obsolete device rescanning and insecure HTTP endpoints
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
