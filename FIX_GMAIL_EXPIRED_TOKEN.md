# 🔧 Fix: Gmail Authorization Expired

## Problem
```
❌ Email function error (500): authorization grant is invalid, expired, or revoked
```

## Cause
Your Gmail App Password or SMTP credentials have expired or been revoked.

---

## ✅ Quick Fix (5 minutes)

### Step 1: Generate New Gmail App Password

1. Go to: https://myaccount.google.com/apppasswords
2. If prompted, sign in to your Gmail account
3. Make sure **2-Step Verification** is enabled (required for App Passwords)
4. Click **"Select app"** → Choose **"Mail"** or **"Other"**
5. Type name: `Smart POS Email` (or any name)
6. Click **"Generate"**
7. **Copy the 16-character password** (example: `abcd efgh ijkl mnop`)
8. **IMPORTANT**: Remove all spaces! Final password should be: `abcdefghijklmnop`

---

### Step 2: Update Supabase Secrets

Open PowerShell/Terminal in your project directory and run:

```bash
# Update Gmail credentials
supabase secrets set SMTP_HOST=smtp.gmail.com
supabase secrets set SMTP_PORT=587
supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com
supabase secrets set SMTP_PASS=YOUR_NEW_16_CHAR_PASSWORD_HERE
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
```

**Replace `YOUR_NEW_16_CHAR_PASSWORD_HERE` with the password from Step 1 (no spaces!)**

---

### Step 3: Redeploy Edge Function

```bash
supabase functions deploy send-activation-code
```

Or use the deploy script:
```bash
.\deploy_email_function.bat
```

---

### Step 4: Verify It Works

```bash
# Watch logs in real-time
supabase functions logs send-activation-code --follow
```

Then in your app:
1. **Fulfill another customer request**
2. Check the logs above - should see:
   ```
   📧 Sending via SMTP: smtp.gmail.com
   ✅ Email sent via SMTP
   ```
3. **Check customer inbox** - activation email should arrive

---

## Alternative: Why Did This Happen?

Gmail App Passwords can expire or be revoked if:
- ✅ You changed your Gmail password
- ✅ You disabled 2-Step Verification
- ✅ Google security review flagged the password
- ✅ The password was manually revoked
- ✅ More than 6 months passed (Google sometimes expires old tokens)

---

## If Problem Persists

### Option A: Use a Different Email Provider

Switch to **Resend** (100 emails/day free):

```bash
# Sign up at https://resend.com
# Get API key from dashboard

supabase secrets set RESEND_API_KEY=re_your_api_key_here
supabase functions deploy send-activation-code
```

### Option B: Check Gmail Security Settings

1. Go to: https://myaccount.google.com/security
2. Check **"Less secure app access"** is OFF (App Passwords don't need it)
3. Check **"2-Step Verification"** is ON (required for App Passwords)
4. Review **"Recent security activity"** for blocks

### Option C: Try Different Gmail Account

If your current Gmail has restrictions:
1. Create new Gmail account dedicated to sending emails
2. Enable 2-Step Verification on new account
3. Generate App Password for new account
4. Update SMTP_USER and SMTP_PASS with new account

---

## Quick Commands (Copy-Paste)

```bash
# Generate new App Password at:
# https://myaccount.google.com/apppasswords

# Then run (replace YOUR_PASSWORD):
supabase secrets set SMTP_PASS=YOUR_16_CHAR_PASSWORD
supabase functions deploy send-activation-code

# Test:
supabase functions logs send-activation-code --follow
```

---

## Success Indicators

✅ `supabase secrets list` shows all SMTP_* secrets  
✅ Function deploys without errors  
✅ Logs show "✅ Email sent via SMTP"  
✅ Customer receives email in inbox  

---

## Need Help?

Check these docs:
- [FREE_GMAIL_EMAIL_SETUP.md](FREE_GMAIL_EMAIL_SETUP.md) - Full Gmail setup guide
- [CUSTOMER_ACTIVATION_EMAIL_SETUP.md](CUSTOMER_ACTIVATION_EMAIL_SETUP.md) - Complete email system docs
- [EMAIL_FUNCTION_FIX.md](EMAIL_FUNCTION_FIX.md) - Common email issues

---

**Last Updated**: March 1, 2026  
**Estimated Fix Time**: 5 minutes
