# 🚀 Quick Fix: Configure Email Provider (2 minutes)

**Status:** Function fixed (v37) ✅  
**Current Issue:** No email provider API key configured

## Your Current Setup
- ✅ Function deployed and working
- ✅ SMTP secrets exist (but SMTP doesn't work in Edge Functions)
- ❌ Missing: RESEND_API_KEY or SENDGRID_API_KEY

## Get Your Email Working (Choose ONE)

### Fast Setup: Resend (Recommended)
**Time:** 2 minutes  
**Cost:** Free (100 emails/day)

1. Go to https://resend.com and sign up (free account)
2. Copy your API key from the dashboard
3. Run this command in PowerShell:
   ```powershell
   supabase secrets set RESEND_API_KEY=re_YOUR_API_KEY_HERE --project-ref olrrbyrzrotojsjkqcxr
   ```
4. Done! Test it by fulfilling an activation request in your app

### Alternative: SendGrid
**Time:** 5 minutes (requires phone)  
**Cost:** Free (100 emails/day)

1. Go to https://sendgrid.com and create free account
2. Create an API key in Settings → API Keys
3. Run this command in PowerShell:
   ```powershell
   supabase secrets set SENDGRID_API_KEY=SG_YOUR_API_KEY_HERE --project-ref olrrbyrzrotojsjkqcxr
   ```
4. Done!

## Verify It's Working

After setting the API key, test by running:
```powershell
supabase functions invoke send-activation-code --project-ref olrrbyrzrotojsjkqcxr --body '{
  "email": "your-test-email@example.com",
  "code": "TEST123456",
  "business_name": "Test",
  "package_name": "Standard"
}'
```

You should see:
```json
{
  "success": true,
  "message": "Activation code emailed to your-test-email@example.com",
  "provider": "resend"
}
```

## Why Not SMTP Anymore?

- The SMTP library (`denomailer`) crashes in Supabase Edge Functions
- Gmail deprecated reliable App Passwords for SMTP
- Resend/SendGrid are more reliable, have better deliverability, and are free

## Next: Check Your Developer Dashboard

Once the API key is set:
1. Open your Flutter app
2. Go to **Developer Dashboard**
3. Click **Fulfill Request** on a pending activation request
4. Customer gets email within seconds ✉️

---

**Questions?** Check [EMAIL_FIX_502_RESOLVED.md](./EMAIL_FIX_502_RESOLVED.md) for full details.
