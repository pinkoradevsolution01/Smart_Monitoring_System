@echo off
setlocal

echo Smart Monitoring System - Open Backend Firewall Rule
echo =====================================================
echo.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo ERROR: Please run this file as Administrator.
    pause
    exit /b 1
)

echo Adding inbound firewall rule for TCP port 3000...
netsh advfirewall firewall add rule name="Smart Monitoring Backend TCP 3000" dir=in action=allow protocol=TCP localport=3000 >nul

if "%errorlevel%"=="0" (
    echo SUCCESS: Port 3000 is now allowed through Windows Firewall.
) else (
    echo ERROR: Failed to add the firewall rule.
)

echo.
pause
