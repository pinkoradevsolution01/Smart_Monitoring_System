@echo off
setlocal enabledelayedexpansion
echo Cleaning CMake/Windows build artifacts...

if exist "build\windows\x64\CMakeCache.txt" (
  echo Deleting build\windows\x64\CMakeCache.txt
  del /f /q "build\windows\x64\CMakeCache.txt"
)

if exist "build\windows\x64\CMakeFiles" (
  echo Removing build\windows\x64\CMakeFiles
  rmdir /s /q "build\windows\x64\CMakeFiles"
)

if exist "build\windows" (
  echo Removing build\windows (will remove Windows build artifacts)
  rmdir /s /q "build\windows"
)

echo Running flutter clean...
flutter clean

echo.
echo Done. Recommended next steps:
echo 1) Re-run build: flutter build windows
echo 2) Or run: flutter run -d windows
echo If the project was moved from OneDrive, consider cloning/moving it to a path without spaces or OneDrive syncing.

endlocal
