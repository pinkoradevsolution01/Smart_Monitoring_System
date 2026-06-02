@echo off
echo Fixing CMake Platform Error
echo ============================
echo.
echo This will completely clean the build directory
echo.

echo Running flutter clean...
call flutter clean
echo.

if exist build (
    echo Deleting entire build directory...
    rmdir /S /Q build
    echo SUCCESS: build directory deleted
) else (
    echo build directory not found
)
echo.

if exist windows\flutter\ephemeral (
    echo Deleting Windows ephemeral directory...
    rmdir /S /Q windows\flutter\ephemeral
    echo SUCCESS: ephemeral directory deleted
) else (
    echo ephemeral directory not found
)
echo.

echo ============================
echo Clean completed successfully!
echo ============================
echo.
echo Now attempting to build...
echo.

call flutter build windows --release

pause
