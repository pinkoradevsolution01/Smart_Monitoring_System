# 📧 Customer Activation Email Setup

## Overview

When you fulfill an activation request in the Developer Dashboard, the system will **automatically send a professional email** to the customer with their activation code and setup instructions.

## Email Format

The customer receives a beautiful HTML email with:

```
🎉 Smart POS Activation Code

Package: [Customer's Package]
Code: [ACTIVATION-CODE-HERE]

How to activate:
1. Install Smart POS app
2. Open app (will show "Payment Required")
3. Tap "Enter Activation Code"
4. Paste this code: [CODE]
5. Enjoy your subscription!

Valid for 1 device | 30 days
Support: [Your Developer Email]
```

## Quick Setup (5 minutes)

### Step 1: Deploy Edge Function

```bash
# Navigate to your project
 

# Deploy the function
supabase functions deploy send-activation-code
```

### Step 2: Set Developer Email

```bash
# Set your support email (customers can reply to this)
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
```

### Step 3: Email Provider (Choose One)

You already set this up for developer notifications, so use the same provider:

**Option A: Resend (Recommended)**
```bash
# Use your existing Resend API key
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxxx
```

**Option B: SendGrid**
```bash
# Use your existing SendGrid API key
supabase secrets set SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
```

### Step 4: Test It!

1. Open your app → Developer Dashboard
2. Go to Customer Requests → Activation Requests
3. Click "Fulfill Request" on any pending request
4. System will:
   - Find available code
   - Mark it as "used"
   - Fulfill the request
   - **Send email to customer** ✉️
5. Check customer's email inbox!

---

## How It Works

### Workflow

```
Developer clicks "Fulfill Request"
    ↓
System finds available activation code
    ↓
Marks code as "used" in database
    ↓
Updates request status to "fulfilled"
    ↓
Calls Edge Function: send-activation-code
    ↓
Edge Function sends email to customer
    ↓
Dashboard shows: "✅ Request fulfilled! 📧 Email sent"
```

### What Happens if Email Fails?

- Request is still fulfilled ✅
- Code is still marked as used ✅
- Customer can still activate (you can send code manually)
- Dashboard shows: `"⚠️ Email failed (code still valid)"`

---

## Email Customization

### Change Developer Email

```bash
supabase secrets set DEVELOPER_EMAIL=your-email@example.com
```

### Update "From" Name/Domain

Edit `supabase/functions/send-activation-code/index.ts`:

```typescript
// Line ~120 for Resend
from: `Your Business Name <noreply@yourdomain.com>`,

// Line ~150 for SendGrid
from: { 
  email: 'noreply@yourdomain.com',
  name: 'Your Business Name'
},
```

Then redeploy:
```bash
supabase functions deploy send-activation-code
```

### Customize Email Template

The HTML template is in `buildActivationEmailHTML()` function (line ~190).

You can customize:
- Colors (change `#667eea` and `#764ba2`)
- Text content
- Logo/branding
- Footer information

After editing, redeploy the function.

---

## Troubleshooting

### Email Not Received

**1. Check Edge Function Logs**
```bash
supabase functions logs send-activation-code --follow
```

**2. Verify Secrets Set**
```bash
supabase secrets list
```

Should show:
- `DEVELOPER_EMAIL`
- `RESEND_API_KEY` or `SENDGRID_API_KEY`

**3. Check Spam Folder**

Customer's email provider might flag automated emails as spam initially.

**4. Test Edge Function Directly**

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-activation-code \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_email": "test@example.com",
    "business_name": "Test Business",
    "package_name": "Basic",
    "activation_code": "TEST-CODE-1234"
  }'
```

**5. Check Email Provider Dashboard**

- **Resend**: [resend.com/emails](https://resend.com/emails) - see delivery status
- **SendGrid**: [app.sendgrid.com/email_activity](https://app.sendgrid.com/email_activity) - see activity log

### Email Shows Wrong Developer Email

Update the secret:
```bash
supabase secrets set DEVELOPER_EMAIL=correct-email@example.com
```

No need to redeploy - takes effect immediately.

### "Failed to send activation email" in Logs

**Possible causes:**
- Email provider API key expired/invalid
- Rate limit exceeded (free tier limits)
- Invalid customer email address
- Edge Function not deployed

**Solutions:**
1. Verify API key is correct and active
2. Check provider dashboard for issues
3. Upgrade email provider plan if needed
4. Ensure function is deployed: `supabase functions list`

---

## Email Delivery Limits

### Resend (Recommended)
- **Free**: 100 emails/day, 3,000/month
- **Pro ($20/mo)**: 50,000 emails/month
- **Delivery time**: Usually <5 seconds

### SendGrid
- **Free**: 100 emails/day
- **Essentials ($15/mo)**: 40,000 emails/month
- **Delivery time**: Usually <10 seconds

### Estimated Usage

- **10 fulfillments/day** = 300/month → ✅ Free tier
- **50 fulfillments/day** = 1,500/month → ✅ Free tier
- **200 fulfillments/day** = 6,000/month → Need paid plan

---

## Security & Privacy

### Customer Data
- ✅ Email only used for activation code delivery
- ✅ Not stored beyond request record
- ✅ Can be deleted after fulfillment

### Email Security
- ✅ Sent via secure HTTPS
- ✅ API keys stored as encrypted secrets
- ✅ Reply-to set to your developer email
- ✅ No tracking pixels or analytics

### Spam Compliance
- ✅ Clear "do not reply" notice
- ✅ Support email included for contact
- ✅ Transactional email (not marketing)
- ✅ No unsubscribe needed (single-send)

---

## Testing Checklist

- [ ] Deploy `send-activation-code` Edge Function
- [ ] Set `DEVELOPER_EMAIL` secret
- [ ] Set email provider API key (Resend/SendGrid)
- [ ] Test fulfill request in Developer Dashboard
- [ ] Verify email received in customer inbox
- [ ] Check email formatting (desktop & mobile)
- [ ] Test activation code from email works in app
- [ ] Check Edge Function logs for errors

---

## Commands Reference

```bash
# Deploy function
supabase functions deploy send-activation-code

# View logs
supabase functions logs send-activation-code

# List all functions
supabase functions list

# View secrets
supabase secrets list

# Set secrets
supabase secrets set KEY=value

# Test locally (requires Deno)
cd supabase/functions/send-activation-code
deno run --allow-net --allow-env index.ts
```

---

## Related Documentation

- [ACTIVATION_REQUEST_IMPLEMENTATION_COMPLETE.md](ACTIVATION_REQUEST_IMPLEMENTATION_COMPLETE.md) - Full request system
- [ACTIVATION_REQUEST_NOTIFICATIONS_SETUP.md](ACTIVATION_REQUEST_NOTIFICATIONS_SETUP.md) - Developer notification emails
- [supabase/functions/send-activation-code/index.ts](supabase/functions/send-activation-code/index.ts) - Email function source code

---

## Support

If you encounter issues:

1. **Check logs**: `supabase functions logs send-activation-code`
2. **Verify setup**: Ensure all secrets are set correctly
3. **Test provider**: Check email provider dashboard
4. **Manual fallback**: Copy code and send manually if needed

---

**Status**: ✅ Production Ready  
**Last Updated**: February 12, 2026  
**Email Format**: HTML with responsive design
