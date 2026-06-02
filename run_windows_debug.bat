@echo off
echo Smart Monitoring System - Windows Debug Runner
echo ===============================================
echo.
echo Step 1: Cleaning previous build...
call flutter clean
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter clean failed
    pause
    exit /b %ERRORLEVEL%
)
echo SUCCESS: Clean completed
echo.

echo Step 1.5: Removing CMake cache...
if exist build\windows\CMakeCache.txt (
    del /F /Q build\windows\CMakeCache.txt
    echo Deleted CMakeCache.txt
)
if exist build\windows\CMakeFiles (
    rmdir /S /Q build\windows\CMakeFiles
    echo Deleted CMakeFiles directory
)
echo SUCCESS: CMake cache cleaned
echo.

echo Step 2: Getting dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter pub get failed
    pause
    exit /b %ERRORLEVEL%
)
echo SUCCESS: Dependencies installed
echo.

echo Step 3: Checking Flutter doctor...
call flutter doctor -v
echo.

echo Step 4: Building and running on Windows (Debug Mode)...
call flutter run -d windows -v
pause
