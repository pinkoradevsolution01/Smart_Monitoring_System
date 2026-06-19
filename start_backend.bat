@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo Smart Monitoring System - Backend Launcher
echo ===========================================
echo.

set "NO_PAUSE=0"
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"

if not defined PORT set "PORT=3000"
if not defined MYSQL_PORT set "MYSQL_PORT=3306"
if not defined MYSQL_EXE set "MYSQL_EXE=C:\xampp\mysql\bin\mysqld.exe"
if not defined MYSQL_INI set "MYSQL_INI=C:\xampp\mysql\bin\my.ini"
if not defined NPM_CMD set "NPM_CMD=C:\Program Files\nodejs\npm.cmd"

if not exist "%~dp0backend\app.js" (
    echo ERROR: backend\app.js not found.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

call :EnsureMysqlRunning
if errorlevel 1 (
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
if exist "%NPM_CMD%" (
    call "%NPM_CMD%" start
) else (
    npm start
)
set "EXIT_CODE=%ERRORLEVEL%"
popd

echo.
echo Backend exited with code %EXIT_CODE%.
if "%NO_PAUSE%"=="0" pause
exit /b %EXIT_CODE%

:EnsureMysqlRunning
set "MYSQL_LISTENING="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%MYSQL_PORT% .*LISTENING"') do set "MYSQL_LISTENING=%%P"
if defined MYSQL_LISTENING (
    echo MySQL is already listening on port %MYSQL_PORT%.
    echo.
    exit /b 0
)

if not exist "%MYSQL_EXE%" (
    echo ERROR: MySQL is not listening on port %MYSQL_PORT% and "%MYSQL_EXE%" was not found.
    exit /b 1
)

echo MySQL is not listening on port %MYSQL_PORT%. Starting XAMPP MySQL...
start "" /B "%MYSQL_EXE%" --defaults-file="%MYSQL_INI%"

set /a MYSQL_WAIT_COUNT=0
:WaitForMysql
set "MYSQL_LISTENING="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%MYSQL_PORT% .*LISTENING"') do set "MYSQL_LISTENING=%%P"
if defined MYSQL_LISTENING (
    echo MySQL is listening on port %MYSQL_PORT%.
    echo.
    exit /b 0
)

set /a MYSQL_WAIT_COUNT+=1
if !MYSQL_WAIT_COUNT! GEQ 20 (
    echo ERROR: MySQL did not start on port %MYSQL_PORT% within the expected time.
    exit /b 1
)

timeout /t 1 /nobreak >nul
goto WaitForMysql
