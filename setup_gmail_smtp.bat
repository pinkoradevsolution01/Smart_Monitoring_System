@echo off
echo ============================================
echo  Gmail SMTP Setup for Smart POS
echo ============================================
echo.

:: Check if Supabase CLI is installed
where supabase >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Supabase CLI not found!
    echo.
    echo Install it first:
    echo   npm install -g supabase
    echo.
    pause
    exit /b 1
)

echo Step 1: Setting SMTP secrets...
echo.
echo Please enter your Gmail information:
echo.

set /p GMAIL_EMAIL="Your Gmail address (e.g., jaybe.gubot01@gmail.com): "
set /p APP_PASSWORD="Your 16-character App Password (no spaces): "

echo.
echo Setting secrets...
supabase secrets set SMTP_HOST=smtp.gmail.com
supabase secrets set SMTP_PORT=587
supabase secrets set SMTP_USER=%GMAIL_EMAIL%
supabase secrets set SMTP_PASS=%APP_PASSWORD%
supabase secrets set DEVELOPER_EMAIL=%GMAIL_EMAIL%

echo.
echo Step 2: Deploying function...
supabase functions deploy send-activation-code

echo.
echo Step 3: Verifying setup...
supabase secrets list

echo.
echo ============================================
echo  Setup Complete!
echo ============================================
echo.
echo Next steps:
echo  1. Restart your Flutter app
echo  2. Try fulfilling a customer request
echo  3. Check customer email inbox
echo.
echo To view logs:
echo   supabase functions logs send-activation-code --follow
echo.
pause
