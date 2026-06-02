@echo off
REM ============================================================================
REM Deploy Password Reset Edge Functions
REM ============================================================================
REM This script deploys the password reset Edge Functions to Supabase
REM Prerequisites: Supabase CLI installed and logged in
REM ============================================================================

echo ============================================================================
echo   Deploying Password Reset Edge Functions
echo ============================================================================
echo.

echo [1/3] Checking Supabase login status...
supabase projects list >nul 2>&1
if errorlevel 1 (
    echo ERROR: Not logged in to Supabase
    echo Please run: supabase login
    pause
    exit /b 1
)
echo OK: Logged in to Supabase
echo.

echo [2/3] Deploying send-password-reset function...
supabase functions deploy send-password-reset
if errorlevel 1 (
    echo ERROR: Failed to deploy send-password-reset
    pause
    exit /b 1
)
echo OK: send-password-reset deployed
echo.

echo [3/3] Deploying verify-password-reset function...
supabase functions deploy verify-password-reset
if errorlevel 1 (
    echo ERROR: Failed to deploy verify-password-reset
    pause
    exit /b 1
)
echo OK: verify-password-reset deployed
echo.

echo ============================================================================
echo   DEPLOYMENT COMPLETE!
echo ============================================================================
echo.
echo Next steps:
echo 1. Set Gmail SMTP credentials (if not already set):
echo    supabase secrets set SMTP_USER=your-email@gmail.com
echo    supabase secrets set SMTP_PASS=your-16-char-app-password
echo.
echo 2. Test the functions:
echo    - Open the app
echo    - Click "Forgot Password?" on login
echo    - Enter an owner email
echo    - Check Gmail for reset token
echo.
echo For detailed instructions, see: PASSWORD_RESET_DEPLOYMENT_GUIDE.md
echo ============================================================================

pause
