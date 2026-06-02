# ============================================================================
# Deploy Password Reset Edge Functions
# ============================================================================
# This script deploys the password reset Edge Functions to Supabase
# Prerequisites: Supabase CLI installed and logged in
# Usage: .\deploy_password_reset.ps1
# ============================================================================

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  Deploying Password Reset Edge Functions" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Supabase login
Write-Host "[1/3] Checking Supabase login status..." -ForegroundColor Yellow
try {
    $null = supabase projects list 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Not logged in"
    }
    Write-Host "OK: Logged in to Supabase" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Not logged in to Supabase" -ForegroundColor Red
    Write-Host "Please run: supabase login" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Step 2: Deploy send-password-reset
Write-Host "[2/3] Deploying send-password-reset function..." -ForegroundColor Yellow
supabase functions deploy send-password-reset
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to deploy send-password-reset" -ForegroundColor Red
    exit 1
}
Write-Host "OK: send-password-reset deployed" -ForegroundColor Green
Write-Host ""

# Step 3: Deploy verify-password-reset
Write-Host "[3/3] Deploying verify-password-reset function..." -ForegroundColor Yellow
supabase functions deploy verify-password-reset
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to deploy verify-password-reset" -ForegroundColor Red
    exit 1
}
Write-Host "OK: verify-password-reset deployed" -ForegroundColor Green
Write-Host ""

# Success message
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Set Gmail SMTP credentials (if not already set):" -ForegroundColor White
Write-Host "   supabase secrets set SMTP_USER=your-email@gmail.com" -ForegroundColor Gray
Write-Host "   supabase secrets set SMTP_PASS=your-16-char-app-password" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Test the functions:" -ForegroundColor White
Write-Host "   - Open the app" -ForegroundColor Gray
Write-Host "   - Click 'Forgot Password?' on login" -ForegroundColor Gray
Write-Host "   - Enter an owner email" -ForegroundColor Gray
Write-Host "   - Check Gmail for reset token" -ForegroundColor Gray
Write-Host ""
Write-Host "For detailed instructions, see: PASSWORD_RESET_DEPLOYMENT_GUIDE.md" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
