@echo off
setlocal enabledelayedexpansion

echo Smart Monitoring System - Android Build (No-Space Path)
echo =======================================================
echo.

set "PROJECT_ROOT=%~dp0"
for %%I in ("%PROJECT_ROOT%") do set "PROJECT_SHORT=%%~sI"

set "FLUTTER_SDK=C:\flutter"
set "FLUTTER_BAT=%FLUTTER_SDK%\bin\flutter.bat"

if not exist "%FLUTTER_BAT%" (
    echo ERROR: Flutter SDK not found at %FLUTTER_BAT%
    echo Update android\local.properties if your Flutter SDK lives elsewhere.
    exit /b 1
)

echo Using project path:
echo   %PROJECT_SHORT%
echo.

pushd "%PROJECT_SHORT%"

echo Cleaning...
call "%FLUTTER_BAT%" clean
if errorlevel 1 goto :fail

echo Getting dependencies...
call "%FLUTTER_BAT%" pub get
if errorlevel 1 goto :fail

echo Building Android debug APK...
call "%FLUTTER_BAT%" build apk --debug
set "EXIT_CODE=%ERRORLEVEL%"

popd
exit /b %EXIT_CODE%

:fail
set "EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %EXIT_CODE%
