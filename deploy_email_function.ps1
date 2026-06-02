# ============================================================================
# Deploy Customer Activation Email Function  (Gmail SMTP - FREE)
# ============================================================================
# Uses Gmail App Password for sending - completely free, no API keys needed.
# Run this script from the project root folder.
# ============================================================================

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectRoot

function Write-Step($n, $msg) {
    Write-Host ""
    Write-Host "[$n] $msg" -ForegroundColor Yellow
}

function Write-OK($msg)  { Write-Host "  OK  $msg" -ForegroundColor Green  }
function Write-ERR($msg) { Write-Host "  ERR $msg" -ForegroundColor Red    }
function Write-INFO($msg){ Write-Host "      $msg" -ForegroundColor Gray    }

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  Deploy: send-activation-code  (Gmail SMTP - FREE)      " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# Refresh PATH to pick up newly installed tools
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ------------------------------------------------------------------
# STEP 1 - Check Supabase CLI
# ------------------------------------------------------------------
Write-Step 1 "Checking Supabase CLI..."
if (!(Get-Command supabase -ErrorAction SilentlyContinue)) {
    Write-ERR "Supabase CLI not found!"
    Write-INFO "Install it with:  npm install -g supabase"
    Write-INFO "Or download from: https://supabase.com/docs/guides/cli"
    Write-Host ""
    pause; exit 1
}
supabase --version
Write-OK "Supabase CLI found."

# ------------------------------------------------------------------
# STEP 2 - Gmail SMTP secrets
# ------------------------------------------------------------------
Write-Step 2 "Configure Gmail SMTP secrets"
Write-Host ""
Write-Host "  You need a Gmail App Password (16 chars, no spaces)." -ForegroundColor White
Write-Host "  To generate one:" -ForegroundColor White
Write-Host "    1. Go to https://myaccount.google.com/security" -ForegroundColor Gray
Write-Host "    2. Enable 2-Step Verification" -ForegroundColor Gray
Write-Host "    3. Search 'App Passwords' -> select Mail -> Generate" -ForegroundColor Gray
Write-Host ""

$smtpUser = Read-Host "  Enter your Gmail address (e.g. you@gmail.com)"
if ([string]::IsNullOrWhiteSpace($smtpUser)) {
    Write-ERR "Gmail address cannot be empty."; pause; exit 1
}

$smtpPassRaw = Read-Host "  Enter your 16-char App Password (input hidden)" -AsSecureString
$smtpPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($smtpPassRaw)
)
$smtpPass = $smtpPass -replace '\s', ''   # strip spaces
if ($smtpPass.Length -lt 16) {
    Write-ERR "App Password must be 16 characters. Please generate a new one."
    pause; exit 1
}

Write-Host ""
Write-Host "  Setting Supabase secrets..." -ForegroundColor Yellow

supabase secrets set SMTP_HOST=smtp.gmail.com
supabase secrets set SMTP_PORT=587
supabase secrets set "SMTP_USER=$smtpUser"
supabase secrets set "SMTP_PASS=$smtpPass"
supabase secrets set "DEVELOPER_EMAIL=$smtpUser"

# Clear any old API keys so the cascade goes straight to SMTP
Write-INFO "Clearing unused Resend/SendGrid keys (if any)..."
supabase secrets unset RESEND_API_KEY    2>$null
supabase secrets unset SENDGRID_API_KEY  2>$null

if ($LASTEXITCODE -ne 0) {
    Write-ERR "Failed to set secrets. Make sure you are logged in:"
    Write-INFO "  Run: supabase login"
    Write-INFO "  Then: supabase link --project-ref YOUR_PROJECT_REF"
    pause; exit 1
}
Write-OK "Secrets saved to Supabase."

# ------------------------------------------------------------------
# STEP 3 - Deploy the edge function
# ------------------------------------------------------------------
Write-Step 3 "Deploying send-activation-code edge function..."
supabase functions deploy send-activation-code

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-ERR "Deployment failed!"
    Write-INFO "Make sure you are logged in and linked:"
    Write-INFO "  supabase login"
    Write-INFO "  supabase link --project-ref YOUR_PROJECT_REF"
    pause; exit 1
}
Write-OK "Edge function deployed successfully."

# ------------------------------------------------------------------
# STEP 4 - Verify
# ------------------------------------------------------------------
Write-Step 4 "Verifying deployed secrets..."
supabase secrets list

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-INFO "1. Restart your Flutter app"
Write-INFO "2. Go to Developer Dashboard -> Activation Requests"
Write-INFO "3. Click 'Fulfill Request' on any pending request"
Write-INFO "4. Customer receives the activation code by email!"
Write-Host ""
Write-Host "  Sending from: $smtpUser" -ForegroundColor Green
Write-Host "  Provider    : Gmail SMTP (free)" -ForegroundColor Green
Write-Host ""
pause
