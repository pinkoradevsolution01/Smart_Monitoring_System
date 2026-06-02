@echo off
echo Fixing Firebase Windows Build Error
echo =====================================
echo.
echo This will remove the corrupted Firebase SDK download
echo.

echo Step 1: Cleaning build directory...
call flutter clean
echo.

echo Step 2: Removing corrupted Firebase SDK...
if exist build\windows\x64\firebase_cpp_sdk_windows_12.7.0.zip (
    del /F /Q build\windows\x64\firebase_cpp_sdk_windows_12.7.0.zip
    echo Deleted corrupted Firebase SDK zip
)
if exist build\windows\x64 (
    rmdir /S /Q build\windows\x64
    echo Deleted x64 directory
)
if exist build\windows (
    rmdir /S /Q build\windows
    echo Deleted windows build directory
)
echo.

echo Step 3: Removing Firebase cache from pub-cache...
if exist %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\firebase_core* (
    echo Clearing Firebase packages from cache...
    rmdir /S /Q %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\firebase_core*
)
echo.

echo Step 4: Getting fresh dependencies...
call flutter pub get
echo.

echo Step 5: Building Windows application (Firebase disabled)...
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
    echo Note: Firebase is disabled on Windows builds
    echo The app will work fully in offline mode
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
