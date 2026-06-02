#!/usr/bin/env pwsh
# ============================================================================
# Smart POS - Email Fix Script (PowerShell)
# ============================================================================
# Usage: .\Fix-Email.ps1
# ============================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Smart POS - Email Fix Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will fix the email authorization error by:" -ForegroundColor Yellow
Write-Host "1. Removing expired Resend/SendGrid API keys" -ForegroundColor Yellow
Write-Host "2. Setting up Gmail SMTP with fresh credentials" -ForegroundColor Yellow
Write-Host "3. Redeploying the email function" -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# STEP 1: Get Gmail App Password
# ============================================================================

Write-Host "STEP 1: Gmail App Password Setup" -ForegroundColor Green
Write-Host "-------------------------------" -ForegroundColor Green
Write-Host ""
Write-Host "To get a Gmail App Password:" -ForegroundColor White
Write-Host "1. Open: https://myaccount.google.com/apppasswords" -ForegroundColor White
Write-Host "2. Click 'Select app' → 'Mail'" -ForegroundColor White
Write-Host "3. Click 'Generate'" -ForegroundColor White
Write-Host "4. Copy the 16-character password" -ForegroundColor White
Write-Host "5. Remove all spaces (example: abcd efgh → abcdefgh)" -ForegroundColor White
Write-Host ""

$openBrowser = Read-Host "Open Gmail App Passwords page now? (Y/N)"
if ($openBrowser -eq 'Y' -or $openBrowser -eq 'y') {
    Start-Process "https://myaccount.google.com/apppasswords"
    Write-Host ""
    Write-Host "Opened browser. Generate your password, then come back here." -ForegroundColor Yellow
    Write-Host ""
}

$gmailPassword = Read-Host "Enter your 16-character Gmail App Password (no spaces)"

if ([string]::IsNullOrWhiteSpace($gmailPassword)) {
    Write-Host "❌ Error: Password cannot be empty!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✓ Password received: $($gmailPassword.Length) characters" -ForegroundColor Green

# ============================================================================
# STEP 2: Remove Expired API Keys
# ============================================================================

Write-Host ""
Write-Host "STEP 2: Removing expired API keys..." -ForegroundColor Green
Write-Host "-------------------------------" -ForegroundColor Green
Write-Host ""

Write-Host "Removing RESEND_API_KEY..." -ForegroundColor Gray
try {
    supabase secrets unset RESEND_API_KEY 2>$null
    Write-Host "✓ RESEND_API_KEY removed" -ForegroundColor Green
} catch {
    Write-Host "⚠ RESEND_API_KEY not found (OK)" -ForegroundColor Yellow
}

Write-Host "Removing SENDGRID_API_KEY..." -ForegroundColor Gray
try {
    supabase secrets unset SENDGRID_API_KEY 2>$null
    Write-Host "✓ SENDGRID_API_KEY removed" -ForegroundColor Green
} catch {
    Write-Host "⚠ SENDGRID_API_KEY not found (OK)" -ForegroundColor Yellow
}

# ============================================================================
# STEP 3: Set Gmail SMTP Credentials
# ============================================================================

Write-Host ""
Write-Host "STEP 3: Setting Gmail SMTP credentials..." -ForegroundColor Green
Write-Host "-------------------------------" -ForegroundColor Green
Write-Host ""

Write-Host "Setting SMTP_HOST..." -ForegroundColor Gray
supabase secrets set SMTP_HOST=smtp.gmail.com
Write-Host "✓ SMTP_HOST set" -ForegroundColor Green

Write-Host "Setting SMTP_PORT..." -ForegroundColor Gray
supabase secrets set SMTP_PORT=587
Write-Host "✓ SMTP_PORT set" -ForegroundColor Green

Write-Host "Setting SMTP_USER..." -ForegroundColor Gray
supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com
Write-Host "✓ SMTP_USER set" -ForegroundColor Green

Write-Host "Setting SMTP_PASS..." -ForegroundColor Gray
supabase secrets set "SMTP_PASS=$gmailPassword"
Write-Host "✓ SMTP_PASS set" -ForegroundColor Green

Write-Host "Setting DEVELOPER_EMAIL..." -ForegroundColor Gray
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
Write-Host "✓ DEVELOPER_EMAIL set" -ForegroundColor Green

# ============================================================================
# STEP 4: Verify Secrets
# ============================================================================

Write-Host ""
Write-Host "STEP 4: Verifying secrets..." -ForegroundColor Green
Write-Host "-------------------------------" -ForegroundColor Green
Write-Host ""

supabase secrets list

# ============================================================================
# STEP 5: Deploy Email Function
# ============================================================================

Write-Host ""
Write-Host "STEP 5: Deploying email function..." -ForegroundColor Green
Write-Host "-------------------------------" -ForegroundColor Green
Write-Host ""

supabase functions deploy send-activation-code

# ============================================================================
# STEP 6: Done!
# ============================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "✅ Email Fix Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to your Smart POS app" -ForegroundColor White
Write-Host "2. Fulfill a customer activation request" -ForegroundColor White
Write-Host "3. Email should send successfully!" -ForegroundColor White
Write-Host ""
Write-Host "To view logs:" -ForegroundColor Yellow
Write-Host "supabase functions logs send-activation-code --follow" -ForegroundColor Cyan
Write-Host ""
Write-Host "To manually email the current customer:" -ForegroundColor Yellow
Write-Host "To: jay-begubot@student.trimexcolleges.edu.ph" -ForegroundColor White
Write-Host "Code: 88VDIX91QGS5GAX4WQOJ" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"
