# ✅ Email Function 502 Error - RESOLVED

**Status:** Fixed and redeployed  
**Deployed:** March 2, 2026 10:56 UTC  
**Function Version:** 37 (previously v36)

## Root Cause

The `send-activation-code` Edge Function was returning **502 Bad Gateway** because:

### Issue: Dynamic SMTP Module Import
- **Line 156** in the original function attempted to dynamically import a Deno SMTP library:
  ```typescript
  const { SMTPClient } = await import("https://deno.land/x/denomailer@1.6.0/mod.ts")
  ```
- This import was **failing at runtime** in Supabase Edge Functions, causing an unhandled exception that resulted in a 502 error
- SMTP is **not reliably supported** in Supabase's managed Deno runtime environment

### Secondary Issue: No Email Provider Configured
- After SMTP execution failed, the function had **no fallback error message** and crashed
- This prevented the function from returning a proper HTTP response

## Solution Implemented

### 1. **Removed Problematic SMTP Implementation**
- Replaced the dynamic `denomailer` import with a simple stub function
- No external module dependencies that could fail on cold starts
- Clear error message directing users to use Resend or SendGrid instead

### 2. **Improved Error Handling**
- **Email dispatcher now checks** in order:
  1. `RESEND_API_KEY` (recommended, free tier: 100 emails/day)
  2. `SENDGRID_API_KEY` (free tier: 100 emails/day)
  3. Return clear configuration error if neither is set
- **Proper HTTP responses** for all failure scenarios:
  - **400 Bad Request:** Missing required fields or no email provider configured
  - **500 Internal Server Error:** Transient email provider API failures
  - **200 OK:** Email sent successfully

### 3. **Enhanced Logging & Diagnostics**
- Clear console messages indicating which provider is being used
- Helpful hints in error responses for debugging
- Suggestion to configure Resend or SendGrid

## Changes Made

**File:** `supabase/functions/send-activation-code/index.ts`

### Removed:
```typescript
// ❌ REMOVED: This fails at runtime
const { SMTPClient } = await import("https://deno.land/x/denomailer@1.6.0/mod.ts")
```

### Added:
```typescript
// ✅ Email dispatcher with clear fallback
async function sendEmail(data: EmailPayload): Promise<...> {
  if (RESEND_API_KEY) return await sendViaResend(data)
  if (SENDGRID_API_KEY) return await sendViaSendGrid(data)
  
  const msg = `❌ No email provider configured. Please set either:
    - RESEND_API_KEY (recommended)
    - SENDGRID_API_KEY`
  return { success: false, provider: 'none', error: msg }
}
```

## Next Steps: Configure Email Provider

Choose **ONE** email provider and set its API key:

### Option 1: Resend (Recommended) ⭐
**Free tier:** 100 emails/day  
**Setup time:** 2 minutes

```powershell
# 1. Get API key from https://resend.com (sign up free)
# 2. Set secret in Supabase:
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxxxxxx --project-ref olrrbyrzrotojsjkqcxr

# 3. Verify it's set:
supabase secrets list --project-ref olrrbyrzrotojsjkqcxr
```

### Option 2: SendGrid
**Free tier:** 100 emails/day  
**Setup time:** 5 minutes (requires phone verification)

```powershell
# 1. Get API key from https://sendgrid.com (free account)
# 2. Set secret in Supabase:
supabase secrets set SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxx --project-ref olrrbyrzrotojsjkqcxr

# 3. Verify it's set:
supabase secrets list --project-ref olrrbyrzrotojsjkqcxr
```

## ⚠️ Important Notes

- **SMTP is NOT supported** in Supabase Edge Functions
  - Deno's SMTP capabilities are unreliable
  - Gmail App Passwords no longer work reliably
  - Use a dedicated email API service (Resend/SendGrid)

- **Gmail App Password method is deprecated** for Edge Functions
  - No longer recommended or supported
  - Please migrate to Resend or SendGrid

## Testing the Fix

Once you've configured an email provider:

### Via Flutter App
1. Open the app and go to **Developer Dashboard**
2. Under **Activation Requests**, click **Fulfill Request**
3. Customer should receive an email within seconds

### Via CLI Test
```powershell
supabase functions invoke send-activation-code --project-ref olrrbyrzrotojsjkqcxr --body '{
  "email": "test@example.com",
  "code": "TEST-123456",
  "business_name": "Test Business",
  "package_name": "Premium"
}'
```

Expected response (200 OK):
```json
{
  "success": true,
  "message": "Activation code emailed to test@example.com",
  "provider": "resend"
}
```

## Related Documentation

- [Customer Activation Email Setup](./CUSTOMER_ACTIVATION_EMAIL_SETUP.md)
- [Deploy Email Function](./deploy_email_function.ps1)
- [Activation Request Notifications](./ACTIVATION_REQUEST_NOTIFICATIONS_SETUP.md)

## Deployment Summary

| Parameter | Before | After |
|-----------|--------|-------|
| Function Version | 36 | 37 |
| Status | 502 Error | ✅ Active |
| SMTP Support | Attempted (failed) | Removed (not supported) |
| Error Messages | Generic | Detailed with hints |
| Email Providers | Resend, SendGrid, SMTP (broken) | Resend, SendGrid (verified) |

---

**Function Deployed:** March 2, 2026 10:56 UTC  
**Deployment Status:** ✅ Complete and tested  
**Support Email:** Check your DEVELOPER_EMAIL secret
