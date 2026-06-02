@echo off
echo Smart Monitoring System - Windows Build
echo ========================================
echo.
echo Cleaning previous build...
call flutter clean
echo.
echo Removing CMake cache...
if exist build\windows\CMakeCache.txt del /F /Q build\windows\CMakeCache.txt
if exist build\windows\CMakeFiles rmdir /S /Q build\windows\CMakeFiles
echo CMake cache cleaned
echo.
echo Getting dependencies...
call flutter pub get
echo.
echo Building Windows executable (Release)...
call flutter build windows --release
echo.
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo BUILD SUCCESSFUL!
    echo ========================================
    echo.
    echo Your app is ready at:
    echo build\windows\x64\runner\Release\smart_monitoring_system.exe
    echo.
    echo You can run it directly from that location.
    echo.
) else (
    echo.
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    echo.
    echo Please check the error messages above.
    echo.
)
pause
