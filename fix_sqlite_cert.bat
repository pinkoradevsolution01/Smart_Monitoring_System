@echo off
REM Pre-download sqlite3 binaries to bypass Dart cert verification issue on Windows

setlocal enabledelayedexpansion

set CACHE_DIR=C:\Users\Acer\AppData\Local\Pub\Cache\hosted\pub.dev\sqlite3-3.3.3\.dart_tool\sqlite3
set BIN_FILE=%CACHE_DIR%\libsqlite3.arm.android.so
set URL=https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.3.3/libsqlite3.arm.android.so

if not exist "%CACHE_DIR%" (
  mkdir "%CACHE_DIR%"
  echo Created cache directory
)

if not exist "%BIN_FILE%" (
  echo Downloading sqlite3 binary for Android ARM...
  powershell -NoProfile -Command "Invoke-WebRequest '%URL%' -OutFile '%BIN_FILE%' -UseBasicParsing"
  if !errorlevel! equ 0 (
    echo Successfully downloaded sqlite3 binary
  ) else (
    echo ERROR: Failed to download sqlite3 binary
    exit /b 1
  )
) else (
  echo sqlite3 binary already cached
)

echo File size:
for %%A in ("%BIN_FILE%") do echo %%~zA bytes

echo.
echo Now attempting Flutter build...
cd /d "%~dp0"
call flutter build apk --debug

endlocal

