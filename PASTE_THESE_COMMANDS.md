# 📋 Copy-Paste Commands to Fix Gmail Email

## Step 1: Get New Gmail App Password

1. Go to: https://myaccount.google.com/apppasswords
2. Generate new password (you'll get 16 characters like: `abcd efgh ijkl mnop`)
3. Copy it and **remove all spaces** → becomes: `abcdefghijklmnop`

---

## Step 2: Run These Commands in PowerShell

**Open PowerShell in your project folder** (`c:\smart_monitoring_system`) and run:

```powershell
# Update Gmail credentials (replace YOUR_16_CHAR_PASSWORD with actual password)
supabase secrets set SMTP_HOST=smtp.gmail.com

supabase secrets set SMTP_PORT=587

supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com

supabase secrets set SMTP_PASS=YOUR_16_CHAR_PASSWORD

supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com

# Deploy the email function
supabase functions deploy send-activation-code
```

**IMPORTANT**: Replace `YOUR_16_CHAR_PASSWORD` with your actual App Password (no spaces!)

---

## Step 3: Verify It Works

```powershell
# Watch logs live
supabase functions logs send-activation-code --follow
```

Keep this running, then fulfill another customer request in your app. You should see:
```
📧 Sending via SMTP: smtp.gmail.com
✅ Email sent via SMTP
```

---

## Alternative: Single Command (if you want to do it all at once)

Replace `abcdefghijklmnop` with your actual App Password:

```powershell
supabase secrets set SMTP_HOST=smtp.gmail.com ; supabase secrets set SMTP_PORT=587 ; supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com ; supabase secrets set SMTP_PASS=abcdefghijklmnop ; supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com ; supabase functions deploy send-activation-code
```

---

## If You Need to Check Current Secrets

```powershell
supabase secrets list
```

Should show:
- ✅ SMTP_HOST
- ✅ SMTP_PORT  
- ✅ SMTP_USER
- ✅ SMTP_PASS
- ✅ DEVELOPER_EMAIL

---

## Manual Email Template (Optional)

If you need to manually send the code to **jay-begubot@student.trimexcolleges.edu.ph**, copy this email:

```
Subject: 🎉 Your Smart POS Activation Code

Hello!

Your Smart POS activation code is ready:

ACTIVATION CODE: 88VDIX91QGS5GAX4WQOJ

HOW TO ACTIVATE:
1. Open the Smart POS app
2. Tap "Enter Activation Code"
3. Paste: 88VDIX91QGS5GAX4WQOJ
4. Tap "Activate"

Your subscription includes:
✅ 30 days of service
✅ Valid for 1 device
✅ Full access to all features

Questions? Reply to this email.

Best regards,
Smart Monitoring System Team
```

**Note:** The 24-hour activation window starts when the code is emailed to the subscriber.

---

## Done!

After running the commands above, the automated emails will work again.
