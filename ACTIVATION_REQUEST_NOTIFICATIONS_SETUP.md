# 📧 Activation Request Email & Webhook Notifications

## Overview

Automatically notify developers when customers request activation codes via email, Slack, Discord, or custom webhooks.

## 🚀 Quick Setup

### Step 1: Run Database SQL

Execute `ACTIVATION_REQUEST_NOTIFICATIONS.sql` in your Supabase SQL Editor:

```bash
# Copy SQL content from ACTIVATION_REQUEST_NOTIFICATIONS.sql
# Paste into Supabase Dashboard > SQL Editor > New Query
# Click "Run"
```

This creates:
- `developer_notification_settings` table
- Database trigger to auto-notify on new requests
- Helper functions for testing

### Step 2: Update Developer Email

```sql
UPDATE developer_notification_settings 
SET notification_email = 'your-email@example.com',
    email_enabled = true;
```

### Step 3: Deploy Edge Function

**Option A: Using Supabase CLI (Recommended)**

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the function
supabase functions deploy notify-activation-request

# Set environment variables (choose your email provider)
# Option 1: Resend.com (Recommended - easiest)
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxxx

# Option 2: SendGrid
supabase secrets set SENDGRID_API_KEY=SG.xxxxxxxxxxxxx

# Option 3: Generic SMTP
supabase secrets set SMTP_HOST=smtp.gmail.com SMTP_PORT=587 SMTP_USER=you@gmail.com SMTP_PASS=yourpassword

# Set app URL for dashboard links in emails
supabase secrets set APP_URL=https://yourdomain.com
```

**Option B: Manual Deployment via Dashboard**

1. Go to Supabase Dashboard > Edge Functions
2. Click "New Function"
3. Name: `notify-activation-request`
4. Paste code from `supabase/functions/notify-activation-request/index.ts`
5. Click "Deploy"
6. Add secrets in "Secrets" tab (see Step 4)

### Step 4: Configure Email Service

**Recommended: Resend.com** (Free: 100 emails/day, $20/month for 50k)

1. Sign up at [resend.com](https://resend.com)
2. Generate API key
3. Add to Supabase secrets:
   ```bash
   supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxxx
   ```

**Alternative: SendGrid** (Free: 100 emails/day)

1. Sign up at [sendgrid.com](https://sendgrid.com)
2. Create API key
3. Add to Supabase secrets:
   ```bash
   supabase secrets set SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
   ```

**Alternative: Gmail SMTP** (Free, but less reliable)

1. Enable 2FA on Gmail
2. Create App Password: [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
3. Add to Supabase secrets:
   ```bash
   supabase secrets set SMTP_HOST=smtp.gmail.com SMTP_PORT=587 SMTP_USER=your-email@gmail.com SMTP_PASS=your-app-password
   ```

### Step 5: Configure Database Trigger (Required!)

The SQL trigger needs your Supabase URL and service role key to call the Edge Function.

**Option A: Set via Supabase Dashboard**

1. Go to Project Settings > API
2. Copy your `URL` and `service_role` key
3. Go to Database > Configuration
4. Add these custom settings:
   - `app.supabase_url` = `https://your-project.supabase.co`
   - `app.service_role_key` = `your-service-role-key`

**Option B: Run SQL to set configuration**

```sql
-- Replace with your actual values
ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
ALTER DATABASE postgres SET app.service_role_key = 'your-service-role-key-here';
```

### Step 6: Test the Notification

```sql
-- Insert a test request
INSERT INTO activation_code_requests (
  business_name, package_name, package_price, request_type,
  contact_email, contact_phone, status
) VALUES (
  'Test Business', 'Basic Package', '₱2,500/month', 'monthly',
  'customer@example.com', '+63 912 345 6789', 'pending'
);

-- Check if notification was triggered
-- You should receive an email within seconds
```

## 🔧 Advanced Configuration

### Slack Webhook Integration

1. Create Slack App: [api.slack.com/apps](https://api.slack.com/apps)
2. Enable Incoming Webhooks
3. Add webhook URL to database:
   ```sql
   UPDATE developer_notification_settings 
   SET webhook_url = 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL',
       webhook_enabled = true;
   ```

### Discord Webhook Integration

1. Discord Server > Channel Settings > Integrations > Webhooks
2. Create webhook and copy URL
3. Add to database:
   ```sql
   UPDATE developer_notification_settings 
   SET webhook_url = 'https://discord.com/api/webhooks/YOUR/WEBHOOK/URL',
       webhook_enabled = true;
   ```

### Custom Webhook (Any Service)

```sql
UPDATE developer_notification_settings 
SET webhook_url = 'https://your-api.com/webhook',
    webhook_enabled = true;
```

Payload format:
```json
{
  "event": "activation_request",
  "data": {
    "request_id": "uuid",
    "business_name": "ABC Corp",
    "package_name": "Basic Package",
    "contact_email": "user@example.com",
    ...
  }
}
```

## 🧪 Testing

### Manual Test

```sql
-- Get a request ID
SELECT id FROM activation_code_requests LIMIT 1;

-- Test notification for that request
SELECT test_activation_notification('REQUEST-UUID-HERE');
```

### Test via Developer Dashboard

1. Login as developer (7 taps on store icon)
2. Navigate to Customer Requests > Activation Requests
3. Check for pending requests
4. Click "Fulfill Request" to test workflow

### Verify Email Delivery

- Check spam folder
- Verify email service API key is correct
- Check Edge Function logs:
  ```bash
  supabase functions logs notify-activation-request
  ```

## 📊 Monitoring

### View Edge Function Logs

```bash
# Real-time logs
supabase functions logs notify-activation-request --follow

# Filter by error
supabase functions logs notify-activation-request --error
```

### Check Notification Status

```sql
-- View recent requests
SELECT 
  business_name,
  contact_email,
  package_name,
  status,
  requested_at,
  fulfilled_at
FROM activation_code_requests
ORDER BY requested_at DESC
LIMIT 10;
```

## 🛠️ Troubleshooting

### Email Not Received

1. **Check Edge Function deployed:**
   ```bash
   supabase functions list
   ```

2. **Verify secrets set:**
   ```bash
   supabase secrets list
   ```

3. **Check Edge Function logs:**
   ```bash
   supabase functions logs notify-activation-request
   ```

4. **Verify notification settings:**
   ```sql
   SELECT * FROM developer_notification_settings;
   ```

5. **Test email service directly:**
   - Resend: Check dashboard at [resend.com/emails](https://resend.com/emails)
   - SendGrid: Check activity at [app.sendgrid.com/email_activity](https://app.sendgrid.com/email_activity)

### Database Trigger Not Firing

```sql
-- Check if trigger exists
SELECT * FROM pg_trigger WHERE tgname = 'on_activation_request_created';

-- Manually trigger for testing
SELECT notify_new_activation_request();
```

### Edge Function Timeout

Increase timeout in `supabase/functions/notify-activation-request/index.ts`:

```typescript
// Add at top of file
const EDGE_FUNCTION_TIMEOUT = 10000; // 10 seconds
```

## 💰 Cost Estimates

### Email Services

| Service | Free Tier | Paid Plans |
|---------|-----------|------------|
| **Resend** | 100/day | $20/month for 50k |
| **SendGrid** | 100/day | $15/month for 40k |
| **Gmail SMTP** | Free (limited) | N/A |

### Supabase Edge Functions

- Free: 500k requests/month
- Pro: 2M requests/month ($25)
- Each notification = 1 request

**Estimated costs for 1000 customers/month:**
- Edge Functions: Free tier (well within 500k limit)
- Email (Resend): Free tier (100 emails/day × 30 days = 3000 emails/month)
- **Total: $0/month** for typical usage

## 🔒 Security Notes

- Service role key has full database access - keep secure!
- Don't commit secrets to version control
- Use environment variables in production
- Consider IP whitelisting for webhook endpoints
- Enable RLS policies on notification settings table

## 📱 Mobile Push Notifications (Future Enhancement)

For native mobile push notifications:
1. Use Firebase Cloud Messaging (FCM)
2. Store FCM tokens in user table
3. Send push via Edge Function
4. See: [Firebase FCM Guide](https://firebase.google.com/docs/cloud-messaging)

## 🎯 Next Steps

1. ✅ Run SQL setup
2. ✅ Deploy Edge Function
3. ✅ Configure email service
4. ✅ Test with dummy request
5. 📱 (Optional) Add Slack/Discord webhook
6. 📊 Monitor notification delivery
7. 🎨 Customize email template if needed

## 📚 Related Documentation

- [ACTIVATION_CODE_REQUEST_FEATURE.md](ACTIVATION_CODE_REQUEST_FEATURE.md) - Customer request flow
- [ACTIVATION_CODE_REQUESTS_TABLE.sql](ACTIVATION_CODE_REQUESTS_TABLE.sql) - Database schema
- [Developer Dashboard](lib/screens/developer/activation_requests_screen.dart) - View/fulfill requests

## 🆘 Support

If you encounter issues:
1. Check Supabase Edge Function logs
2. Verify all secrets are set correctly
3. Test email service API key independently
4. Ensure database trigger is active
5. Review RLS policies on notification tables

---

**Last Updated:** February 2026
**Status:** Production Ready ✅
