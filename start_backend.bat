@echo off
setlocal

echo Smart Monitoring System - Backend Launcher
echo ===========================================
echo.

set "NO_PAUSE=0"
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"

if not exist "%~dp0backend\app.js" (
    echo ERROR: backend\app.js not found.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

pushd "%~dp0backend"
echo Starting backend from: %cd%
echo.
npm start
set "EXIT_CODE=%ERRORLEVEL%"
popd

echo.
echo Backend exited with code %EXIT_CODE%.
if "%NO_PAUSE%"=="0" pause
exit /b %EXIT_CODE%
