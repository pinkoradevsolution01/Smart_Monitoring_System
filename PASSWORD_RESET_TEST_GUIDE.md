# Password Reset Feature - Quick Test Guide

## ✅ Prerequisites
- [ ] Gmail SMTP configured in Supabase (see deployment guide)
- [ ] Edge functions deployed
- [ ] Flutter app built and running
- [ ] At least one owner account created

## 🧪 Test Scenarios

### Test 1: Successful Password Reset
**Expected Result:** ✅ Password reset successful

1. Open the app
2. On login screen, click "Forgot Password? (Owner Only)"
3. Enter owner's Gmail address (e.g., `owner@gmail.com`)
4. Click "Send Reset Email"
5. Wait for confirmation message: "Password reset link sent to..."
6. Check Gmail inbox for email from developer account
7. Copy the reset token from the email (first 16 characters shown)
8. In the app dialog, paste the token
9. Enter new password (min 6 characters)
10. Confirm new password
11. Click "Reset Password"
12. See success message: "Password changed successfully"
13. Try logging in with new password

**✅ Success Indicators:**
- Email received within 1-2 minutes
- Token accepted
- Password updated
- Can log in with new password

---

### Test 2: Non-Owner Email Rejection
**Expected Result:** ❌ Email rejected

1. Click "Forgot Password?"
2. Enter a non-owner email (e.g., `cashier@gmail.com`)
3. Click "Send Reset Email"

**✅ Success Indicators:**
- Error message: "Owner email required"
- No email sent

---

### Test 3: Invalid Email Format
**Expected Result:** ❌ Email rejected

1. Click "Forgot Password?"
2. Enter invalid email (e.g., `notanemail`)
3. Click "Send Reset Email"

**✅ Success Indicators:**
- Error message: "Valid email required"
- No email sent

---

### Test 4: Token Expiration
**Expected Result:** ❌ Token rejected after 1 hour

1. Request password reset
2. Wait for email
3. **Wait 1 hour** (or modify Edge Function for faster testing)
4. Try to use the token

**✅ Success Indicators:**
- Error message: "Reset token has expired"
- Password not changed

---

### Test 5: Invalid Token
**Expected Result:** ❌ Token rejected

1. Request password reset
2. In the token field, enter random text
3. Try to reset password

**✅ Success Indicators:**
- Error message: "Invalid or expired reset token"
- Password not changed

---

### Test 6: Password Validation
**Expected Result:** ❌ Weak password rejected

1. Request password reset
2. Enter valid token
3. Enter password with less than 6 characters (e.g., `abc`)
4. Try to reset

**✅ Success Indicators:**
- Error message: "Password must be at least 6 characters"
- Password not changed

---

### Test 7: Password Mismatch
**Expected Result:** ❌ Mismatch rejected

1. Request password reset
2. Enter valid token
3. Enter password: `password123`
4. Confirm password: `password456` (different)
5. Try to reset

**✅ Success Indicators:**
- Error message: "Passwords do not match"
- Password not changed

---

## 🔍 Debug Tips

### Email Not Received?
Check Edge Function logs:
```bash
supabase functions logs send-password-reset --limit 50
```

Common issues:
- SMTP credentials not set correctly
- Gmail App Password expired
- 2-Step Verification not enabled
- Email in spam folder

### Token Verification Failed?
Check Edge Function logs:
```bash
supabase functions logs verify-password-reset --limit 50
```

Common issues:
- Token expired (> 1 hour old)
- Token already used
- Typo in token

### Flutter Debug Output
Look for these log messages:
```
[PasswordReset] Sending reset email to: owner@gmail.com
[PasswordReset] Response status: 200
[PasswordReset] ✅ Reset email sent successfully
[PasswordReset] Verifying token and resetting password...
[PasswordReset] ✅ Token verified for email: owner@gmail.com
[PasswordReset] ✅ Password updated successfully in database
```

---

## 📊 Test Results Template

| Test # | Scenario | Expected | Actual | Status |
|--------|----------|----------|--------|--------|
| 1 | Successful reset | ✅ Success | | ⬜ |
| 2 | Non-owner email | ❌ Rejected | | ⬜ |
| 3 | Invalid email | ❌ Rejected | | ⬜ |
| 4 | Token expiration | ❌ Rejected | | ⬜ |
| 5 | Invalid token | ❌ Rejected | | ⬜ |
| 6 | Weak password | ❌ Rejected | | ⬜ |
| 7 | Password mismatch | ❌ Rejected | | ⬜ |

---

## 🎯 Quick Test (Fast Track)

If you just want to verify it works:

1. **Setup** (one-time):
   ```bash
   # Set SMTP credentials
   supabase secrets set SMTP_USER=your@gmail.com
   supabase secrets set SMTP_PASS=your-app-password
   
   # Deploy functions
   .\deploy_password_reset.ps1
   ```

2. **Test**:
   - Open app → Forgot Password
   - Enter owner email
   - Check Gmail
   - Copy token
   - Reset password
   - Login with new password

3. **Done!** ✅

---

## 📧 Sample Email Preview

Subject: **Password Reset Request - Smart Monitoring System**

```
┌─────────────────────────────────────┐
│   🔐 Password Reset Request         │
└─────────────────────────────────────┘

Hello,

We received a request to reset your password for your 
Owner Account in the Smart Monitoring System.

Reset Token:
┌─────────────────────────────────────┐
│   a1b2c3d4e5f6g7h8                 │
└─────────────────────────────────────┘

Copy this token and paste it in the app to reset 
your password.

⚠️ Security Notice:
• This token is valid for 1 hour
• If you didn't request this reset, ignore this email
• Never share this token with anyone

Best regards,
Smart Monitoring System Team
```

---

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Request timeout" | Check internet connection |
| "SMTP not configured" | Set Supabase secrets |
| "Token expired" | Request new reset |
| "Owner not found" | Create owner account first |
| Email in spam | Check spam folder, whitelist sender |

---

## ✨ Success Criteria

All tests should pass with expected results. If any test fails:
1. Check debug logs
2. Verify SMTP configuration
3. Review Edge Function logs
4. Test manually with curl
