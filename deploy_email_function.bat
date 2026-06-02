@echo off
REM ============================================================================
REM Deploy Customer Activation Email Function  (Gmail SMTP - FREE)
REM ============================================================================
REM Delegates to the PowerShell script which handles secrets interactively.
REM ============================================================================

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_email_function.ps1"
exit /b %ERRORLEVEL%

REM ---- legacy code below kept for reference, not executed ----
goto :EOF

echo.
echo ============================================================================
echo  Deploy Customer Activation Email Function
echo ============================================================================
echo.

REM Check if supabase CLI is installed
where supabase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Supabase CLI not found!
    echo.
    echo Please install it first:
    echo   npm install -g supabase
    echo.
    echo Or download from: https://supabase.com/docs/guides/cli
    echo.
    pause
    exit /b 1
)

echo [1/4] Checking Supabase CLI...
supabase --version
echo.

echo [2/4] Deploying send-activation-code function...
supabase functions deploy send-activation-code
echo.

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Deployment failed!
    echo.
    echo Make sure you're logged in and linked to your project:
    echo   supabase login
    echo   supabase link --project-ref YOUR_PROJECT_REF
    echo.
    pause
    exit /b 1
)

echo [3/4] Checking secrets...
echo.
echo Required secrets:
echo   - DEVELOPER_EMAIL (your support email)
echo   - RESEND_API_KEY or SENDGRID_API_KEY (email provider)
echo.

supabase secrets list
echo.

echo [4/4] Testing configuration...
echo.
echo If you see DEVELOPER_EMAIL and an email provider key above, you're ready!
echo.
echo If not, set them:
echo   supabase secrets set DEVELOPER_EMAIL=your-email@example.com
echo   supabase secrets set RESEND_API_KEY=re_xxxxx
echo.

echo ============================================================================
echo  Deployment Complete!
echo ============================================================================
echo.
echo Next steps:
echo   1. Restart your Flutter app
echo   2. Go to Developer Dashboard ^> Activation Requests
echo   3. Click "Fulfill Request"
echo   4. Customer will receive activation email automatically!
echo.
echo For help, see: CUSTOMER_ACTIVATION_EMAIL_SETUP.md
echo.
pause
