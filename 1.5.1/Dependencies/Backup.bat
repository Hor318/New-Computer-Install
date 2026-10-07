@Echo off

Echo StartTileBackup
Echo ----------------
Echo A simple batch script to backup and restore the Start menu tiles and pinned apps.
Echo.
Echo Official project page: https://github.com/TurboLabIt/StartTileBackup
Echo.
Echo PRESS A KEY TO **BACKUP**!

Net Session >nul 2>&1
  If %ErrorLevel% == 0 (
    Echo ### Running as administrator
  ) Else (
	Echo ### Permission denied! Please run this script as administrator
      GOTO END
  )
	
SET APPDIR=%~dp0
SET BACKUPDIR=%APPDIR%backup\
  Cd %APPDIR%
  %~d0

  IF NOT EXIST "%BACKUPDIR%" GOTO CREATE_BACKUP_DIR

Echo ### Removing previous backup...
  Rmdir /s/q "%BACKUPDIR%"

:CREATE_BACKUP_DIR
Echo ### Creating new backup dir in %BACKUPDIR%
  Mkdir "%BACKUPDIR%"

Echo ### Killing File Explorer...
  Taskkill /im explorer.exe /f

Echo ### File backup in progress!
  Robocopy "%LocalAppData%\Microsoft\Windows\CloudStore" "%BACKUPDIR%CloudStore" /E
  Robocopy "%LocalAppData%\Microsoft\Windows\Caches" "%BACKUPDIR%Caches" /E
  Robocopy "%LocalAppData%\Microsoft\Windows\Explorer" "%BACKUPDIR%Explorer" /E

Echo ### Registry key backup in progress!
  Reg export HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore "%BACKUPDIR%CloudStore.reg"

Echo ### Restarting File Explorer...
  Explorer.exe

:END
Echo ### Procedure completed. Bye bye.
Echo.
  Ping 127.0.0.1 -n 10 >NUL
  