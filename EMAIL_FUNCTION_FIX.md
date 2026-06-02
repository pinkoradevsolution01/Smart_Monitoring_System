# ⚡ Quick Fix: Email Function Not Found

## The Error You're Seeing

```
❌ Failed to send activation email: FunctionException(status: 404, details: {code: NOT_FOUND, message: Requested function was not found})
```

## What This Means

The Edge Function `send-activation-code` hasn't been deployed to Supabase yet. The app tried to send an email but couldn't find the function.

**Good news:** Your activation request was still successfully fulfilled! The code was marked as "used" and saved. Only the email part failed.

---

## Quick Fix (2 minutes)

### Option 1: Run Deploy Script (Easiest)

**Windows - Double-click:**
```
deploy_email_function.bat
```

**Or run in PowerShell:**
```powershell
.\deploy_email_function.ps1
```

### Option 2: Manual Commands

```bash
# 1. Deploy the function
supabase functions deploy send-activation-code

# 2. Set your email (if not already set)
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com

# 3. Verify secrets
supabase secrets list
```

---

## First Time Setup?

If you haven't set up Supabase CLI yet:

```bash
# 1. Install Supabase CLI
npm install -g supabase

# 2. Login
supabase login

# 3. Link your project
supabase link --project-ref YOUR_PROJECT_REF

# 4. Deploy the function
supabase functions deploy send-activation-code

# 5. Set secrets
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
supabase secrets set RESEND_API_KEY=your_resend_key_here
```

**Get your project ref:** Supabase Dashboard → Settings → General → Reference ID

---

## After Deployment

1. **Restart your app** (close and reopen)
2. **Try fulfill again** - email will now send automatically
3. **Check customer's inbox** - they'll receive the activation code

---

## Verify It's Working

After deployment, check the logs:

```bash
supabase functions logs send-activation-code --follow
```

When you fulfill a request, you should see:
```
📧 Sending activation code email: [EMAIL]
✅ Email sent via Resend: [ID]
```

---

## Still Not Working?

### Check 1: Function Deployed?
```bash
supabase functions list
```

Should show `send-activation-code` in the list.

### Check 2: Secrets Set?
```bash
supabase secrets list
```

Should show:
- `DEVELOPER_EMAIL`
- `RESEND_API_KEY` (or `SENDGRID_API_KEY`)

### Check 3: Email Provider Working?

**Resend Dashboard:** [resend.com/emails](https://resend.com/emails)  
**SendGrid Dashboard:** [app.sendgrid.com/email_activity](https://app.sendgrid.com/email_activity)

---

## Alternative: Manual Email (Temporary)

If you need to send codes immediately while setting up:

1. Fulfill request (code is still saved)
2. Copy the activation code from the dashboard
3. Manually email/SMS the customer with this template:

```
Subject: 🎉 Your Smart POS Activation Code

Hi [Business Name],

Your activation code is ready!

Code: [ACTIVATION-CODE]
Package: [Package Name]

How to activate:
1. Install Smart POS app
2. Open app
3. Tap "Enter Activation Code"
4. Paste: [CODE]
5. Enjoy!

Support: jaybe.gubot01@gmail.com
```

---

## Need Help?

See full setup guide: **CUSTOMER_ACTIVATION_EMAIL_SETUP.md**

---

**TL;DR:**
1. Run `deploy_email_function.bat` or `deploy_email_function.ps1`
2. Restart your app
3. Fulfill requests - emails now send automatically ✅
