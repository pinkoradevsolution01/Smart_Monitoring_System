@echo off
echo Smart Monitoring System - Windows Runner
echo ========================================
echo.
echo Cleaning previous build...
call flutter clean
echo.
echo Removing CMake cache...
if exist build\windows\CMakeCache.txt del /F /Q build\windows\CMakeCache.txt
if exist build\windows\CMakeFiles rmdir /S /Q build\windows\CMakeFiles
echo.
echo Getting dependencies...
call flutter pub get
echo.
echo Building and running on Windows...
call flutter run -d windows --release
pause
