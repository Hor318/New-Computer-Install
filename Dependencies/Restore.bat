@Echo off

Echo StartTileBackup
Echo ----------------
Echo A simple batch script to backup and restore the Start menu tiles and pinned apps.
Echo.
Echo Official project page: https://github.com/TurboLabIt/StartTileBackup
Echo.

Net session >nul 2>&1
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

  IF NOT EXIST "%BACKUPDIR%" (
    Echo ### BACKUP DIRECTORY NOT FOUND!
	 Echo ### Please run Backup.bat first to create a backup
	   GOTO END
  )

Echo ### Killing File Explorer...
  Taskkill /im explorer.exe /f

Echo ### File restore in progress!
  Rmdir /s/q "%LocalAppData%\Microsoft\Windows\CloudStore"
  Robocopy "%BACKUPDIR%CloudStore" "%LocalAppData%\Microsoft\Windows\CloudStore" /E

  Rmdir /s/q "%LocalAppData%\Microsoft\Windows\Caches"
  Robocopy "%BACKUPDIR%Caches" "%LocalAppData%\Microsoft\Windows\Caches" /E

  Rmdir /s/q "%LocalAppData%\Microsoft\Windows\Explorer"
  Robocopy "%BACKUPDIR%Explorer" "%LocalAppData%\Microsoft\Windows\Explorer" /E

Echo ### Registry key restore in progress!
  Reg import "%BACKUPDIR%CloudStore.reg"

Echo ### Restarting File Explorer...
  Explorer.exe
 
:END
Echo ### Procedure completed. Bye bye.
Echo.
  ping 127.0.0.1 -n 3 >NUL
