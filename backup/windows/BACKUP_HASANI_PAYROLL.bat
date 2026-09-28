@echo off
setlocal
cd /d "%~dp0"
title Hasani Payroll Backup
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup_hasani_payroll.ps1"
echo.
if errorlevel 1 (
  echo BACKUP FAILED. Production data was not changed.
) else (
  echo BACKUP COMPLETED SUCCESSFULLY.
)
pause
