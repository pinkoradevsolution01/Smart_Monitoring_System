@echo off
setlocal

echo Smart Monitoring System - Backend Launcher
echo ===========================================
echo.

set "NO_PAUSE=0"
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"

if not defined PORT set "PORT=3000"

if not exist "%~dp0backend\app.js" (
    echo ERROR: backend\app.js not found.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

curl -fsS "http://127.0.0.1:%PORT%/api/health" >nul 2>nul
if "%ERRORLEVEL%"=="0" (
    echo Backend is already running on port %PORT%.
    echo Reusing the existing instance.
    if "%NO_PAUSE%"=="0" pause
    exit /b 0
)

set "PORT_PID="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do set "PORT_PID=%%P"
if defined PORT_PID (
    echo ERROR: Port %PORT% is already in use by PID %PORT_PID%, but it is not responding as the Smart Monitoring backend.
    echo Stop that process, or change PORT and the Flutter backend URL together.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

pushd "%~dp0backend"
echo Starting backend from: %cd%
echo Using port: %PORT%
echo.
npm start
set "EXIT_CODE=%ERRORLEVEL%"
popd

echo.
echo Backend exited with code %EXIT_CODE%.
if "%NO_PAUSE%"=="0" pause
exit /b %EXIT_CODE%
