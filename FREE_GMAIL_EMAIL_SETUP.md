# 📧 FREE Gmail Email Setup (No Cost!)

Use your Gmail account to send activation codes - **100% FREE**!

---

## Step 1: Generate Gmail App Password

1. Go to [myaccount.google.com](https://myaccount.google.com)
2. Click **Security** (left sidebar)
3. Enable **2-Step Verification** (if not already enabled)
4. Search for "App passwords" or go to: [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
5. Click **Create app password**
6. Type name: `Smart POS Email`
7. Click **Create**
8. **Copy the 16-character password** (example: `abcd efgh ijkl mnop`)

**Important:** Remove spaces when copying! Final password: `abcdefghijklmnop`

---

## Step 2: Set Supabase Secrets

```bash
supabase secrets set SMTP_HOST=smtp.gmail.com
supabase secrets set SMTP_PORT=587
supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com
supabase secrets set SMTP_PASS=your_16_char_app_password
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
```

**Example:**
```bash
supabase secrets set SMTP_PASS=abcdefghijklmnop
```

---

## Step 3: Deploy Updated Function

```bash
supabase functions deploy send-activation-code
```

Or use the deploy script:
```bash
deploy_email_function.bat
```

---

## Step 4: Test It!

1. **Restart your Flutter app**
2. **Fulfill a customer request**
3. Check logs:
   ```bash
   supabase functions logs send-activation-code --follow
   ```
4. Should see:
   ```
   📧 Sending via SMTP: smtp.gmail.com jaybe.gubot01@gmail.com
   ✅ Email sent via SMTP
   ```
5. **Check customer's inbox** - activation code email arrived!

---

## Verify Your Setup

```bash
# Check all secrets are set
supabase secrets list
```

Should show:
- ✅ `SMTP_HOST`
- ✅ `SMTP_PORT`
- ✅ `SMTP_USER`
- ✅ `SMTP_PASS`
- ✅ `DEVELOPER_EMAIL`

---

## Troubleshooting

### Error: "Invalid credentials"
- Make sure you used **App Password**, not your Gmail password
- Remove spaces from the 16-character password
- App password looks like: `abcdefghijklmnop` (no spaces!)

### Error: "2-Step Verification required"
- Enable 2-Step Verification in Google Account settings
- Then create App Password

### Can't find "App passwords"?
- Make sure 2-Step Verification is ON
- Direct link: [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)

### Gmail blocks login
- Use App Password, not regular password
- Make sure "Less secure app access" is OFF (you don't need it with App Passwords)

---

## Gmail Free Limits

- **500 emails per day** (plenty for your needs!)
- **0 cost** - completely free
- Works with your existing Gmail account

---

## Quick Copy-Paste Commands

Replace `YOUR_APP_PASSWORD` with your actual 16-character password:

```bash
supabase secrets set SMTP_HOST=smtp.gmail.com
supabase secrets set SMTP_PORT=587
supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com
supabase secrets set SMTP_PASS=YOUR_APP_PASSWORD
supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com
supabase functions deploy send-activation-code
```

---

## Why This is Better (For Budget)

| Service | Cost | Setup Time | Limit |
|---------|------|------------|-------|
| **Gmail SMTP** | **FREE** | 5 min | 500/day |
| Resend | $0-20/mo | 2 min | 100-3000/day |
| SendGrid | $0-20/mo | 5 min | 100-40000/day |

**Winner: Gmail SMTP** - Perfect for small businesses! 🎉

---

## Alternative: Yahoo/Outlook SMTP

If you prefer Yahoo or Outlook:

### Yahoo Mail:
```bash
supabase secrets set SMTP_HOST=smtp.mail.yahoo.com
supabase secrets set SMTP_PORT=587
supabase secrets set SMTP_USER=your-email@yahoo.com
supabase secrets set SMTP_PASS=yahoo_app_password
```

### Outlook/Hotmail:
```bash
supabase secrets set SMTP_HOST=smtp-mail.outlook.com
supabase secrets set SMTP_PORT=587
supabase secrets set SMTP_USER=your-email@outlook.com
supabase secrets set SMTP_PASS=outlook_password
```

---

## Summary

1. ✅ Get Gmail App Password (2 minutes)
2. ✅ Set 5 Supabase secrets (1 minute)
3. ✅ Deploy function (1 minute)
4. ✅ Test and enjoy FREE emails forever! 🎉

**Total Cost: ₱0.00 (FREE!)** 💰

---

Need help? The error messages in the terminal will guide you!
