@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  echo Drag a HasaniPayroll backup ZIP onto this file, or run:
  echo VERIFY_BACKUP_RESTORE.bat "C:\path\to\backup.zip"
  pause
  exit /b 2
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_backup_restore.ps1" -BackupZip "%~1"
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" echo Restore verification FAILED with exit code %EXITCODE%.
pause
exit /b %EXITCODE%
