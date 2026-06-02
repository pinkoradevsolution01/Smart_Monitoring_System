# Password Reset for Owner Accounts - Deployment Guide

## 📋 Overview
This implementation enables owner accounts to reset their passwords via email. The system sends a secure reset token to the owner's Gmail account, which they can use to set a new password.

## 🏗️ Architecture

### Components Created:
1. **send-password-reset** Edge Function - Sends reset email with token
2. **verify-password-reset** Edge Function - Verifies token and authorizes reset
3. **PasswordResetService** (Flutter) - Handles password reset flow
4. **Updated Login Screen** - New UI for password reset

### Flow:
```
Owner enters email → Email verified as owner → Reset email sent to Gmail
→ Owner receives token → Enters token in app → Password updated in local DB
```

## 🚀 Deployment Steps

### Step 1: Set Up Gmail SMTP (One-time setup)

1. **Enable 2-Step Verification** on your Gmail account:
   - Go to https://myaccount.google.com/security
   - Enable 2-Step Verification

2. **Generate App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Windows Computer"
   - Copy the 16-character password (no spaces)

3. **Set Supabase Secrets**:
   ```bash
   cd c:\smart_monitoring_system
   
   # Set SMTP credentials
   supabase secrets set SMTP_HOST=smtp.gmail.com
   supabase secrets set SMTP_PORT=587
   supabase secrets set SMTP_USER=your-email@gmail.com
   supabase secrets set SMTP_PASS=your-16-char-app-password
   supabase secrets set DEVELOPER_EMAIL=your-email@gmail.com
   ```

### Step 2: Deploy Edge Functions

```bash
# Navigate to project directory
cd c:\smart_monitoring_system

# Deploy send-password-reset function
supabase functions deploy send-password-reset

# Deploy verify-password-reset function
supabase functions deploy verify-password-reset
```

### Step 3: Test the Deployment

```bash
# Test send-password-reset
curl -X POST https://your-project.supabase.co/functions/v1/send-password-reset \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{"email":"owner@example.com"}'

# Test verify-password-reset
curl -X POST https://your-project.supabase.co/functions/v1/verify-password-reset \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{"token":"test-token","newPassword":"newpass123"}'
```

### Step 4: Update Flutter App

1. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter build windows --release
   ```

2. **Test the feature**:
   - Open the app
   - Click "Forgot Password?" on login screen
   - Enter an owner email address
   - Check the Gmail inbox for reset token
   - Copy token and paste in app
   - Set new password

## 📧 Email Template

The reset email includes:
- 🔐 Secure reset token (first 16 characters displayed)
- ⏰ 1-hour expiration time
- ⚠️ Security warnings
- 📱 Deep link for app (optional future enhancement)

## 🔒 Security Features

1. **Token-based Authentication**
   - Tokens are randomly generated (32 bytes)
   - One-time use (deleted after verification)
   - 1-hour expiration

2. **Owner-Only Access**
   - Verifies email belongs to an owner account
   - Non-owner emails are rejected

3. **Password Validation**
   - Minimum 6 characters
   - Confirmation required
   - Validated on both client and server

4. **Email Security**
   - Uses Gmail SMTP with App Password
   - TLS encrypted connection
   - Professional HTML email template

## 🐛 Troubleshooting

### Email Not Received
1. Check Gmail spam folder
2. Verify SMTP credentials in Supabase secrets
3. Check Edge Function logs: `supabase functions logs send-password-reset`
4. Ensure 2-Step Verification is enabled on Gmail

### Token Verification Failed
1. Check token hasn't expired (1 hour limit)
2. Ensure token is copied completely
3. Check Edge Function logs: `supabase functions logs verify-password-reset`

### Build Errors
1. Clean build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Check for import errors in login_screen.dart

## 📝 Files Created/Modified

### New Files:
- `supabase/functions/send-password-reset/index.ts`
- `supabase/functions/verify-password-reset/index.ts`
- `lib/services/password_reset_service.dart`

### Modified Files:
- `lib/screens/auth/login_screen.dart`
  - Replaced OtpService with PasswordResetService
  - Updated UI to show token input dialog

## 🎯 Testing Checklist

- [ ] Gmail SMTP credentials set in Supabase
- [ ] Edge functions deployed successfully
- [ ] Owner can request password reset
- [ ] Reset email arrives in Gmail inbox
- [ ] Token can be copied from email
- [ ] Password reset completes successfully
- [ ] Can log in with new password
- [ ] Non-owner emails are rejected
- [ ] Expired tokens are rejected
- [ ] Invalid tokens are rejected

## 📊 Usage Limits

**Gmail Free Tier:**
- 500 emails per day
- Sufficient for small to medium deployments
- No API costs

**Supabase Edge Functions:**
- Generous free tier
- Scales automatically
- Pay only for what you use

## 🔄 Future Enhancements

1. **Deep Linking**: Auto-fill token when opening reset link from email
2. **SMS Backup**: Alternative reset via SMS
3. **Database Storage**: Store tokens in Supabase DB instead of memory
4. **Rate Limiting**: Prevent abuse with request throttling
5. **Multi-language**: Translate email templates

## 📞 Support

If you encounter issues:
1. Check Supabase Edge Function logs
2. Verify Gmail App Password is correct
3. Test SMTP connection manually
4. Check Flutter debug logs
