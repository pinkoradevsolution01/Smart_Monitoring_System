# 🔧 COMPLETE SOLUTION: Fix Gmail Email & Resend Activation Code
//hato pyil mcrt osas

## Problem Summary
- ✅ Code `88VDIX91QGS5GAX4WQOJ` was successfully assigned to customer
- ❌ Email failed to send due to expired Gmail credentials
- 📧 Customer email: `jay-begubot@student.trimexcolleges.edu.ph`

---

## SOLUTION PART 1: Fix Gmail Credentials (Choose One Method)

### Method A: Quick Fix - Update App Password (5 minutes)

#### Step 1.1: Generate New Gmail App Password

1. **Open browser** and go to: https://myaccount.google.com/apppasswords
2. **Sign in** with Google account: `jaybe.gubot01@gmail.com`
3. If you see "App passwords" option:
   - Click **"Select app"** dropdown
   - Choose **"Mail"** or **"Other (Custom name)"**
   - Type: `Smart POS Email`
   - Click **"Generate"**
4. **Copy the 16-character password** shown on screen
   - Example displayed: `abcd efgh ijkl mnop`
   - **Remove all spaces**: `abcdefghijklmnop`
   - This is your SMTP_PASS

**Troubleshooting Step 1.1:**
- ❓ **Don't see "App passwords"?**
  - Go to: https://myaccount.google.com/security
  - Enable **"2-Step Verification"** first
  - Then retry accessing: https://myaccount.google.com/apppasswords

- ❓ **"Less secure app access" page shows instead?**
  - This is the OLD method (deprecated)
  - Make sure to use App Passwords (requires 2FA enabled)

---

#### Step 1.2: Open PowerShell in Project Directory

**Windows:**
1. Open File Explorer
2. Navigate to: `C:\smart_monitoring_system`
3. Click address bar, type `powershell`, press Enter
4. PowerShell opens in that directory

**Verify you're in correct directory:**
```powershell
Get-Location
```
**Expected output:** `C:\smart_monitoring_system`

---

#### Step 1.3: Update Supabase Secrets

**Copy these commands ONE BY ONE** (replace `YOUR_PASSWORD` in line 5):

```powershell
# Set Gmail SMTP host
supabase secrets set SMTP_HOST=smtp.gmail.com

# Set Gmail SMTP port
supabase secrets set SMTP_PORT=587

# Set Gmail username (sender email)
supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com

# Set Gmail App Password (REPLACE WITH YOURS - no spaces!)
supabase secrets set SMTP_PASS=abcdefghijklmnop

# Set developer email (appears in "Reply-To")
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
```

**⚠️ CRITICAL:** Replace `abcdefghijklmnop` with YOUR actual 16-character App Password from Step 1.1

**After each command, you should see:**
```
Setting secret SMTP_HOST...
Secret SMTP_HOST set successfully
```

**Expected time:** ~30 seconds for all commands

---

#### Step 1.4: Verify Secrets Are Set

```powershell
supabase secrets list
```

**Expected output:**
```
┌──────────────────┬─────────────────────────────┐
│ Name             │ Value                       │
├──────────────────┼─────────────────────────────┤
│ SMTP_HOST        │ smtp.gmail.com              │
│ SMTP_PORT        │ 587                         │
│ SMTP_USER        │ jaybe.gubot01@gmail.com     │
│ SMTP_PASS        │ ****************            │
│ DEVELOPER_EMAIL  │ jaybe.gubot01@gmail.com     │
└──────────────────┴─────────────────────────────┘
```

✅ All 5 secrets should be listed
❌ If missing, re-run the missing `supabase secrets set` command

---

#### Step 1.5: Deploy Updated Email Function

```powershell
supabase functions deploy send-activation-code
```

**Expected output:**
```
Deploying function send-activation-code...
Deployment complete!
Function URL: https://olrrbyrzrotojsjkqcxr.supabase.co/functions/v1/send-activation-code
```

**Expected time:** ~15 seconds

**Troubleshooting Step 1.5:**
- ❌ **Error: "function not found"**
  - The Edge Function hasn't been created yet
  - See Method B below to create it first

- ❌ **Error: "not logged in"**
  - Run: `supabase login`
  - Follow the browser authentication

---

#### Step 1.6: Test Email Function

```powershell
# Watch function logs in real-time
supabase functions logs send-activation-code --follow
```

**Keep this terminal open!** It will show logs as emails are sent.

**In a NEW terminal or in your Flutter app:**
- Fulfill another customer activation request
- OR manually trigger the email (see "Manual Trigger" section below)

**Expected log output:**
```
2026-03-01T10:23:15.123Z | 📧 Sending activation code to: test@example.com
2026-03-01T10:23:15.124Z |    Business: Test Business | Package: Standard
2026-03-01T10:23:15.125Z | 📧 Sending via SMTP: smtp.gmail.com:587 as jaybe.gubot01@gmail.com
2026-03-01T10:23:16.456Z | ✅ Email sent via SMTP
2026-03-01T10:23:16.457Z | ✅ Activation email sent via smtp
```

✅ If you see "Email sent via SMTP" - **SUCCESS!**
❌ If you see errors, see Troubleshooting section below

---

### Method B: Alternative - Use Resend (If Gmail Keeps Failing)

#### Why Resend?
- 100 emails/day FREE (no credit card)
- No App Password hassles
- Better deliverability
- 5 minutes setup

#### Step B.1: Sign Up for Resend

1. Go to: https://resend.com/signup
2. Sign up with your email
3. Verify your email
4. Go to dashboard: https://resend.com/api-keys
5. Click **"Create API Key"**
6. Name: `Smart POS`
7. Copy the key (starts with `re_`)

#### Step B.2: Update Supabase Secrets

```powershell
# Remove old SMTP secrets (optional but recommended)
supabase secrets unset SMTP_HOST
supabase secrets unset SMTP_PORT
supabase secrets unset SMTP_USER
supabase secrets unset SMTP_PASS

# Set Resend API key
supabase secrets set RESEND_API_KEY=re_your_api_key_here

# Set developer email (must be verified in Resend)
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
```

#### Step B.3: Verify Email in Resend

1. Go to: https://resend.com/domains
2. Click **"Add Domain"** or **"Verify Email"**
3. Add: `jaybe.gubot01@gmail.com`
4. Check your Gmail for verification email
5. Click verification link

#### Step B.4: Deploy Function

```powershell
supabase functions deploy send-activation-code
```

#### Step B.5: Test

```powershell
supabase functions logs send-activation-code --follow
```

Expected log:
```
✅ Email sent via Resend: msg_abc123xyz
```

---

## SOLUTION PART 2: Manually Email the Customer (While You Fix Automation)

### Option A: Send via Gmail Web Interface

1. **Open Gmail:** https://mail.google.com
2. **Compose new email**
3. **To:** `jay-begubot@student.trimexcolleges.edu.ph`
4. **Subject:** `🎉 Your Smart POS Activation Code`
5. **Body:** Copy the HTML template below
6. Click **Send**

#### Professional HTML Email Template:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
    .card { background: #fff; border-radius: 12px; max-width: 480px; margin: 0 auto;
            padding: 32px; box-shadow: 0 2px 8px rgba(0,0,0,.1); }
    .header { text-align: center; margin-bottom: 24px; }
    .header h1 { color: #1a73e8; font-size: 24px; margin: 0; }
    .code-box { background: #f0f4ff; border: 2px dashed #1a73e8; border-radius: 8px;
                text-align: center; padding: 20px; margin: 24px 0; }
    .code-box .label { font-size: 13px; color: #666; margin-bottom: 8px; }
    .code-box .code { font-size: 28px; font-weight: bold; color: #1a73e8;
                      letter-spacing: 3px; font-family: monospace; }
    .steps { background: #f9f9f9; border-radius: 8px; padding: 16px 20px; margin: 20px 0; }
    .steps h3 { color: #333; margin: 0 0 12px; font-size: 15px; }
    .steps ol { margin: 0; padding-left: 20px; color: #555; line-height: 1.8; font-size: 14px; }
    .info { font-size: 13px; color: #888; text-align: center; margin-top: 20px; }
    .footer { text-align: center; margin-top: 24px; font-size: 12px; color: #aaa; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>🎉 Your Smart POS Activation Code</h1>
      <p style="color:#555;margin:8px 0 0;">
        Your <strong>Standard Package</strong> is ready!
      </p>
    </div>

    <div class="code-box">
      <div class="label">ACTIVATION CODE</div>
      <div class="code">88VDIX91QGS5GAX4WQOJ</div>
    </div>

    <div class="steps">
      <h3>🚀 How to Activate</h3>
      <ol>
        <li>Open the <strong>Smart POS</strong> app</li>
        <li>Tap <strong>"Enter Activation Code"</strong></li>
        <li>Paste: <code>88VDIX91QGS5GAX4WQOJ</code></li>
        <li>Tap <strong>Activate</strong> — you're done!</li>
      </ol>
    </div>

    <p class="info">
      Valid for <strong>1 device</strong> · <strong>30 days</strong> subscription<br>
      Questions? Reply to this email or contact jaybe.gubot01@gmail.com
    </p>

    <div class="footer">Smart POS System · Powered by Smart Monitoring</div>
  </div>
</body>
</html>
```

---

### Option B: Plain Text Email (If HTML Doesn't Work)

**To:** `jay-begubot@student.trimexcolleges.edu.ph`

**Subject:** `Your Smart POS Activation Code`

**Body:**
```
Hello!

Your Smart POS activation code is ready:

═══════════════════════════════════════
ACTIVATION CODE: 88VDIX91QGS5GAX4WQOJ
═══════════════════════════════════════

HOW TO ACTIVATE:
1. Open the Smart POS app
2. Tap "Enter Activation Code"
3. Copy and paste: 88VDIX91QGS5GAX4WQOJ
4. Tap "Activate"

SUBSCRIPTION DETAILS:
✓ Package: Standard
✓ Duration: 30 days
✓ Valid for: 1 device
✓ Full access to all features

IMPORTANT NOTES:
• This code can only be used once
• Code is tied to your device after activation
• Subscription starts when you activate
• Monthly renewal required after 30 days

NEED HELP?
Reply to this email or contact:
jaybe.gubot01@gmail.com

Best regards,
Smart Monitoring System Team
```

---

## SOLUTION PART 3: Verify Customer Can Activate

### SQL Query to Check Code Status

Go to: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/sql

Paste this:

```sql
-- Verify code is ready for customer activation
SELECT 
  code,
  package_name,
  status,
  assigned_at,
  device_id,
  device_name,
  CASE 
    WHEN status = 'assigned' THEN '✅ Ready for customer to activate'
    WHEN status = 'unused' THEN '⚠️ Not yet assigned - assign it first'
    WHEN status = 'used' THEN '❌ Already activated by customer'
    WHEN status = 'revoked' THEN '❌ Code has been revoked'
    ELSE '❓ Unknown status'
  END as activation_status
FROM activation_codes
WHERE code = '88VDIX91QGS5GAX4WQOJ';
```

**Expected result:**
```
code                  | 88VDIX91QGS5GAX4WQOJ
package_name          | Standard
status                | assigned
assigned_at           | 2026-03-01 10:15:23
device_id             | NULL
device_name           | NULL
activation_status     | ✅ Ready for customer to activate
```

✅ **status = 'assigned'** means customer can now activate it in the app

---

### Test Customer Activation Flow

1. **Open your Smart POS app**
2. **Navigate to Package Selection**
3. **Click "Enter Activation Code"**
4. **Paste:** `88VDIX91QGS5GAX4WQOJ`
5. **Click Activate**

**Expected behavior:**
- ✅ Code validates successfully
- ✅ Package activates (Standard)
- ✅ Subscription expires in 30 days
- ✅ Status changes from 'assigned' to 'used'

**Verification SQL after activation:**

```sql
-- Check if code was successfully activated
SELECT 
  code,
  status,
  device_id,
  device_name,
  used_at
FROM activation_codes
WHERE code = '88VDIX91QGS5GAX4WQOJ';

-- Check subscription was created
SELECT 
  device_id,
  device_name,
  package_name,
  activated_at,
  expires_at,
  status,
  EXTRACT(DAY FROM (expires_at - NOW())) as days_remaining
FROM subscriptions
WHERE activation_code = '88VDIX91QGS5GAX4WQOJ';
```

---

## SOLUTION PART 4: Prevent Future Email Failures

### Setup 1: Add Email Testing Script

Create: `test_email.ps1`

```powershell
# Test email function manually
Write-Host "Testing email function..." -ForegroundColor Cyan

$payload = @{
    email = "jaybe.gubot01@gmail.com"
    code = "TEST1234567890ABCDEF"
    business_name = "Test Business"
    package_name = "Standard"
} | ConvertTo-Json

$projectRef = "olrrbyrzrotojsjkqcxr"
$anonKey = "YOUR_SUPABASE_ANON_KEY_HERE"

$response = Invoke-RestMethod `
    -Uri "https://$projectRef.supabase.co/functions/v1/send-activation-code" `
    -Method Post `
    -Headers @{
        "Authorization" = "Bearer $anonKey"
        "Content-Type" = "application/json"
    } `
    -Body $payload

Write-Host "Response:" -ForegroundColor Green
$response | ConvertTo-Json
```

**To run:**
```powershell
.\test_email.ps1
```

---

### Setup 2: Monitor Email Health

```powershell
# Create a monitoring script
# Save as: check_email_health.ps1

Write-Host "Checking Supabase email function health..." -ForegroundColor Cyan

# Check secrets
Write-Host "`n1. Checking secrets..." -ForegroundColor Yellow
supabase secrets list

# Check function deployment
Write-Host "`n2. Checking function deployment..." -ForegroundColor Yellow
supabase functions list

# Check recent logs
Write-Host "`n3. Recent email logs (last 10):" -ForegroundColor Yellow
supabase functions logs send-activation-code --tail 10

Write-Host "`nHealth check complete!" -ForegroundColor Green
```

---

### Setup 3: Create Gmail App Password Reminder

Add to your calendar:
- **Title:** "Rotate Gmail App Password for Smart POS"
- **Frequency:** Every 6 months
- **Note:** Generate new password at: https://myaccount.google.com/apppasswords

---

## TROUBLESHOOTING GUIDE

### Issue 1: "Authentication failed" in SMTP logs

**Symptoms:**
```
❌ SMTP error: Authentication failed
```

**Solutions:**

**A. Verify App Password is correct:**
```powershell
# Check current secrets
supabase secrets list

# Regenerate App Password and update
supabase secrets set SMTP_PASS=new_password_here
supabase functions deploy send-activation-code
```

**B. Check Gmail 2FA is enabled:**
1. Go to: https://myaccount.google.com/security
2. Verify "2-Step Verification" shows "On"
3. If "Off", enable it and wait 5 minutes
4. Then generate new App Password

**C. Try different App Password:**
1. Revoke old App Password: https://myaccount.google.com/apppasswords
2. Generate fresh one
3. Update immediately

---

### Issue 2: "Connection timeout" in logs

**Symptoms:**
```
❌ SMTP error: Connection timeout
```

**Solutions:**

**A. Check SMTP settings:**
```powershell
supabase secrets list
```
Verify:
- SMTP_HOST = `smtp.gmail.com` (not smtp.google.com!)
- SMTP_PORT = `587` (not 465!)

**B. Test Gmail SMTP from terminal:**
```powershell
Test-NetConnection -ComputerName smtp.gmail.com -Port 587
```
Should show: `TcpTestSucceeded : True`

**C. Check Supabase region latency:**
- Supabase Edge Functions run in cloud
- Sometimes Gmail blocks certain regions
- Switch to Resend (Method B above) if persistent

---

### Issue 3: Email goes to spam

**Symptoms:**
- Email sends successfully
- Customer doesn't receive it
- Found in spam folder

**Solutions:**

**A. Use Resend instead of Gmail:**
- Resend has better deliverability
- Professional sending infrastructure
- See Method B above

**B. Add SPF/DKIM records (advanced):**
- Only works if you have custom domain
- Requires DNS configuration
- See: https://support.google.com/a/answer/33786

**C. Ask customer to whitelist:**
- Add `jaybe.gubot01@gmail.com` to contacts
- Check spam folder and mark "Not Spam"

---

### Issue 4: Function deploys but doesn't run

**Symptoms:**
```
Deployment complete!
```
But logs show nothing when customer requests code

**Solutions:**

**A. Check function is being called:**
```sql
-- In Supabase SQL Editor
SELECT * FROM activation_code_requests
WHERE customer_email = 'test@example.com'
ORDER BY request_date DESC LIMIT 1;
```

Check if `fulfilled_at` is set but customer didn't get email.

**B. Check Flutter app calls the function:**

File: `lib/services/code_request_service.dart`

Look for:
```dart
final response = await supabase.functions.invoke(
  'send-activation-code',
  body: {
    'email': request.customerEmail,
    'code': assignedCode,
    'business_name': request.businessName,
    'package_name': request.packageName,
  },
);
```

**C. Check function URL is correct:**
```powershell
supabase functions list
```
Should show: `send-activation-code` with correct URL

---

## COMPLETE VERIFICATION CHECKLIST

After following solutions above, verify everything works:

### ✅ Checklist A: Secrets Configuration
```powershell
supabase secrets list
```
- [ ] SMTP_HOST = smtp.gmail.com
- [ ] SMTP_PORT = 587
- [ ] SMTP_USER = jaybe.gubot01@gmail.com
- [ ] SMTP_PASS = (16-char password, no spaces)
- [ ] DEVELOPER_EMAIL = jaybe.gubot01@gmail.com

### ✅ Checklist B: Function Deployment
```powershell
supabase functions list
```
- [ ] `send-activation-code` appears in list
- [ ] Deployment status = Success
- [ ] Function URL is accessible

### ✅ Checklist C: Email Test
```powershell
supabase functions logs send-activation-code --follow
```
Then fulfill a test customer request:
- [ ] Logs show "📧 Sending activation code"
- [ ] Logs show "✅ Email sent via SMTP" or "✅ Email sent via resend"
- [ ] No error messages in logs
- [ ] Customer receives email within 1 minute
- [ ] Email not in spam folder

### ✅ Checklist D: Customer Activation
- [ ] Customer can open app
- [ ] "Enter Activation Code" button works
- [ ] Code validates successfully
- [ ] Subscription activated
- [ ] App shows 30 days remaining

### ✅ Checklist E: Database State
Run in Supabase SQL Editor:
```sql
SELECT code, status FROM activation_codes WHERE code = '88VDIX91QGS5GAX4WQOJ';
```
- [ ] Status changed from 'assigned' to 'used'
- [ ] device_id is populated
- [ ] used_at timestamp is set

```sql
SELECT * FROM subscriptions WHERE activation_code = '88VDIX91QGS5GAX4WQOJ';
```
- [ ] Subscription record exists
- [ ] status = 'active'
- [ ] expires_at = 30 days from now

---

## QUICK REFERENCE COMMANDS

### Daily Operations:
```powershell
# Check email function logs
supabase functions logs send-activation-code --follow

# List all secrets
supabase secrets list

# Redeploy function after changes
supabase functions deploy send-activation-code
```

### Maintenance:
```powershell
# Update App Password
supabase secrets set SMTP_PASS=new_password
supabase functions deploy send-activation-code

# Check function health
supabase functions list
supabase secrets list

# View recent errors
supabase functions logs send-activation-code --tail 50
```

---

## SUPPORT CONTACTS

**Supabase Dashboard:** https://app.supabase.com/project/olrrbyrzrotojsjkqcxr

**Useful Links:**
- Gmail App Passwords: https://myaccount.google.com/apppasswords
- Resend Dashboard: https://resend.com/overview
- Supabase Docs: https://supabase.com/docs/guides/functions

**Documentation Files:**
- [FREE_GMAIL_EMAIL_SETUP.md](FREE_GMAIL_EMAIL_SETUP.md)
- [CUSTOMER_ACTIVATION_EMAIL_SETUP.md](CUSTOMER_ACTIVATION_EMAIL_SETUP.md)
- [FIX_GMAIL_EXPIRED_TOKEN.md](FIX_GMAIL_EXPIRED_TOKEN.md)

---

**Last Updated:** March 1, 2026  
**Solution Time:** 10-15 minutes  
**Customer Code:** 88VDIX91QGS5GAX4WQOJ  
**Customer Email:** jay-begubot@student.trimexcolleges.edu.ph
