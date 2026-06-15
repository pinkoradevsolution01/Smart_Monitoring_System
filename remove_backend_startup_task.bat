@echo off
setlocal

net session >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo This uninstaller needs Administrator privileges.
    echo Requesting elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\remove_backend_startup_task.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo Failed to remove backend startup task.
)

exit /b %EXIT_CODE%
