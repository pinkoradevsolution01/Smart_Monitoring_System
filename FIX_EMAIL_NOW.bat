@echo off
echo ============================================
echo Smart POS - Email Fix Script
echo ============================================
echo.

REM Get new Gmail App Password first!
echo STEP 1: Get Gmail App Password
echo.
echo 1. Open: https://myaccount.google.com/apppasswords
echo 2. Generate new password (16 characters)
echo 3. Copy it and remove all spaces
echo.
set /p GMAIL_PASSWORD="Enter your 16-character Gmail App Password: hatopyilmcrtosas"

echo.
echo STEP 2: Removing old/expired API keys...
call supabase secrets unset RESEND_API_KEY
call supabase secrets unset SENDGRID_API_KEY

echo.
echo STEP 3: Setting Gmail SMTP credentials...
call supabase secrets set SMTP_HOST=smtp.gmail.com
call supabase secrets set SMTP_PORT=587
call supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com
call supabase secrets set SMTP_PASS=%GMAIL_PASSWORD%
call supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com

echo.
echo STEP 4: Deploying email function...
call supabase functions deploy send-activation-code

echo.
echo ============================================
echo Fix complete! Test by fulfilling a customer request.
echo ============================================
pause
