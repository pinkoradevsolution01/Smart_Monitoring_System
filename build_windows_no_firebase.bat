@echo off
echo Building Windows (Firebase Disabled)
echo ======================================
echo.

echo Step 1: Backing up original pubspec.yaml...
copy /Y pubspec.yaml pubspec_original_backup.yaml >nul
echo Backup created
echo.

echo Step 2: Using Windows-specific pubspec (no Firebase)...
copy /Y pubspec_windows.yaml pubspec.yaml >nul
echo pubspec.yaml updated
echo.

echo Step 3: Cleaning build...
call flutter clean
echo.

echo Step 4: Removing any cached Firebase downloads...
if exist build rmdir /S /Q build
if exist windows\flutter\ephemeral rmdir /S /Q windows\flutter\ephemeral
echo.

echo Step 5: Getting dependencies...
call flutter pub get
echo.

echo Step 6: Building Windows application...
call flutter build windows --release
echo.

echo Step 7: Restoring original pubspec.yaml...
copy /Y pubspec_original_backup.yaml pubspec.yaml >nul
call flutter pub get >nul 2>&1
del pubspec_original_backup.yaml >nul
echo Original pubspec restored
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
    echo NOTE: This build runs in OFFLINE MODE ONLY
    echo Firebase features are disabled
    echo.
) else (
    echo.
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    echo.
    copy /Y pubspec_original_backup.yaml pubspec.yaml >nul
    del pubspec_original_backup.yaml >nul
)

pause
