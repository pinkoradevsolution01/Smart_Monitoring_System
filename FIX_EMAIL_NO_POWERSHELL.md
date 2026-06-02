# 🌐 Fix Gmail Email - NO POWERSHELL METHOD

## Alternative Solutions (No Command Line Required)

---

## ✅ METHOD 1: Use Supabase Dashboard (RECOMMENDED - Easiest!)

### Step 1: Generate Gmail App Password

1. **Open browser** → https://myaccount.google.com/apppasswords
2. Sign in with: `jaybe.gubot01@gmail.com`
3. If you don't see App Passwords:
   - Go to: https://myaccount.google.com/security
   - Enable **"2-Step Verification"** first
   - Return to: https://myaccount.google.com/apppasswords
4. Click **"Select app"** → Choose **"Mail"**
5. Click **"Select device"** → Choose **"Other"**
6. Type: `Smart POS Email`
7. Click **"Generate"**
8. **COPY the 16-character password** (example: `abcd efgh ijkl mnop`)
9. **Remove spaces** → Final: `abcdefghijklmnop`
10. **Save this somewhere safe** (you'll need it in Step 2)

---

### Step 2: Set Secrets via Supabase Web Dashboard

1. **Open browser** → https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/settings/functions

2. **Click "Edge Functions" in left sidebar**

3. **Scroll down to "Secrets" section**

4. **Add each secret** (click "Add new secret" for each):

   **Secret 1:**
   - Name: `SMTP_HOST`
   - Value: `smtp.gmail.com`
   - Click "Add secret"

   **Secret 2:**
   - Name: `SMTP_PORT`
   - Value: `587`
   - Click "Add secret"

   **Secret 3:**
   - Name: `SMTP_USER`
   - Value: `jaybe.gubot01@gmail.com`
   - Click "Add secret"

   **Secret 4:**
   - Name: `SMTP_PASS`
   - Value: `[Paste your 16-character password from Step 1]`
   - Click "Add secret"

   **Secret 5:**
   - Name: `DEVELOPER_EMAIL`
   - Value: `jaybe.gubot01@gmail.com`
   - Click "Add secret"

5. **Verify all 5 secrets are listed** - you should see:
   - SMTP_HOST
   - SMTP_PORT
   - SMTP_USER
   - SMTP_PASS (value hidden)
   - DEVELOPER_EMAIL

---

### Step 3: Deploy Edge Function via Dashboard

**Option A: If function already exists (just needs update):**

1. Go to: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/functions
2. Find `send-activation-code` in the list
3. Click on it
4. Click **"Redeploy"** button
5. Wait for "Deployed successfully" message

**Option B: If function doesn't exist (create new):**

1. Go to: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/functions
2. Click **"Create a new function"**
3. Name: `send-activation-code`
4. **Copy the code below** and paste in editor:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const SMTP_HOST = Deno.env.get('SMTP_HOST')
const SMTP_PORT = parseInt(Deno.env.get('SMTP_PORT') || '587')
const SMTP_USER = Deno.env.get('SMTP_USER')
const SMTP_PASS = Deno.env.get('SMTP_PASS')
const DEVELOPER_EMAIL = Deno.env.get('DEVELOPER_EMAIL') || 'support@smartpos.app'

interface EmailPayload {
  email: string
  code: string
  business_name: string
  package_name: string
}

serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload: EmailPayload = await req.json()
    const { email, code, business_name, package_name } = payload

    if (!email || !code) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: email and code' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📧 Sending activation code to: ${email}`)
    console.log(`   Business: ${business_name} | Package: ${package_name}`)

    const sendResult = await sendViaSmtp({ email, code, business_name, package_name })

    if (!sendResult.success) {
      console.error('❌ Failed to send email:', sendResult.error)
      return new Response(
        JSON.stringify({ error: 'Failed to send email', details: sendResult.error }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Activation email sent via smtp`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Activation code emailed to ${email}`,
        provider: 'smtp',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('❌ Unhandled error:', err)
    const msg = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: msg }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function sendViaSmtp(data: EmailPayload): Promise<{ success: boolean; error?: string }> {
  try {
    console.log(`📧 Sending via SMTP: ${SMTP_HOST}:${SMTP_PORT} as ${SMTP_USER}`)

    const { SMTPClient } = await import("https://deno.land/x/denomailer@1.6.0/mod.ts")

    const client = new SMTPClient({
      connection: {
        hostname: SMTP_HOST!,
        port: SMTP_PORT,
        tls: false,
        auth: {
          username: SMTP_USER!,
          password: SMTP_PASS!,
        },
      },
    })

    await client.send({
      from: SMTP_USER!,
      to: data.email,
      subject: '🎉 Your Smart POS Activation Code',
      html: buildEmailHtml(data),
    })

    await client.close()
    console.log('✅ Email sent via SMTP')
    return { success: true }
  } catch (e) {
    console.error('❌ SMTP error:', e)
    return { success: false, error: String(e) }
  }
}

function buildEmailHtml(data: EmailPayload): string {
  const { code, business_name, package_name } = data
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
    .card { background: #fff; border-radius: 12px; max-width: 480px; margin: 0 auto;
            padding: 32px; box-shadow: 0 2px 8px rgba(0,0,0,.1); }
    .header { text-align: center; margin-bottom: 24px; }
    .header h1 { color: #1a73e8; font-size: 24px; margin: 0; }
    .code-box { background: #f0f4ff; border: 2px dashed #1a73e8; border-radius: 8px;
                text-align: center; padding: 20px; margin: 24px 0; }
    .code-box .code { font-size: 28px; font-weight: bold; color: #1a73e8;
                      letter-spacing: 3px; font-family: monospace; }
    .steps { background: #f9f9f9; border-radius: 8px; padding: 16px 20px; margin: 20px 0; }
    .steps h3 { color: #333; margin: 0 0 12px; font-size: 15px; }
    .steps ol { margin: 0; padding-left: 20px; color: #555; line-height: 1.8; font-size: 14px; }
    .info { font-size: 13px; color: #888; text-align: center; margin-top: 20px; }
    .footer { text-align: center; margin-top: 24px; font-size: 12px; color: #aaa; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>🎉 Your Smart POS Activation Code</h1>
      <p style="color:#555;margin:8px 0 0;">
        Hello <strong>${business_name}</strong>! Your <strong>${package_name}</strong> is ready.
      </p>
    </div>
    <div class="code-box">
      <div class="code">${code}</div>
    </div>
    <div class="steps">
      <h3>🚀 How to Activate</h3>
      <ol>
        <li>Open the <strong>Smart POS</strong> app</li>
        <li>Tap <strong>"Enter Activation Code"</strong></li>
        <li>Paste the code above</li>
        <li>Tap <strong>Activate</strong></li>
      </ol>
    </div>
    <p class="info">
      Valid for <strong>1 device</strong> · <strong>30 days</strong> subscription<br>
      Questions? Reply to this email
    </p>
    <div class="footer">Smart POS System</div>
  </div>
</body>
</html>
`
}
```

5. Click **"Deploy function"**
6. Wait for success message

---

### Step 4: Test It

1. **Open app** and fulfill another customer request
2. **Check logs** in Supabase:
   - Go to: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/functions
   - Click on `send-activation-code`
   - Click **"Logs"** tab
   - Look for: `✅ Email sent via SMTP`

---

## ✅ METHOD 2: Use Command Prompt (CMD) Instead

If you have Command Prompt but not PowerShell:

### Step 1: Open Command Prompt

1. Press `Windows Key + R`
2. Type: `cmd`
3. Press Enter

### Step 2: Navigate to Project

```cmd
cd C:\smart_monitoring_system
```

### Step 3: Run Supabase Commands

```cmd
supabase secrets set SMTP_HOST=smtp.gmail.com

supabase secrets set SMTP_PORT=587

supabase secrets set SMTP_USER=jaybe.gubot01@gmail.com

supabase secrets set SMTP_PASS=your_16_char_password_here

supabase secrets set DEVELOPER_EMAIL=jaybe.gubot01@gmail.com

supabase functions deploy send-activation-code
```

**Note:** Commands are the same as PowerShell!

---

## ✅ METHOD 3: Manual Email (No Automation)

If you can't fix the automated system right now, manually email the customer:

### Step 1: Open Gmail

Go to: https://mail.google.com

### Step 2: Compose Email

- **To:** `jay-begubot@student.trimexcolleges.edu.ph`
- **Subject:** `Your Smart POS Activation Code`
- **Body:** (Copy this)

```
Hello!

Your Smart POS activation code is ready:

═══════════════════════════════════════
ACTIVATION CODE: 88VDIX91QGS5GAX4WQOJ
═══════════════════════════════════════

HOW TO ACTIVATE:
1. Open the Smart POS app
2. Tap "Enter Activation Code"
3. Copy and paste: 88VDIX91QGS5GAX4WQOJ
4. Tap "Activate"

SUBSCRIPTION DETAILS:
✓ Package: Standard
✓ Duration: 30 days
✓ Valid for: 1 device

This code can only be used once and is tied to your device after activation.

Questions? Reply to this email.

Best regards,
Smart Monitoring System Team
```

### Step 3: Send

Click **Send** button.

---

## ✅ METHOD 4: Use Supabase CLI in Browser

Supabase provides a web-based terminal:

1. Go to: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/settings/general
2. Scroll to **"Project Settings"**
3. Look for **"CLI access"** or **"Terminal"** option
4. Run the same commands as in Method 2

---

## ❓ Which Method Should I Choose?

| Method | Difficulty | Time | Best For |
|--------|-----------|------|----------|
| **Method 1: Dashboard** | ⭐ Easy | 5 min | Can't use command line at all |
| **Method 2: CMD** | ⭐⭐ Medium | 3 min | Have Command Prompt |
| **Method 3: Manual Email** | ⭐ Easy | 2 min | Quick fix for one customer |
| **Method 4: Browser CLI** | ⭐⭐ Medium | 4 min | No local terminal access |

**Recommendation:** Try **Method 1 (Dashboard)** first - it's the easiest and doesn't require any command line!

---

## 📧 Verify Customer Received Email

After using any method above:

1. Wait 1-2 minutes
2. Ask customer to check email (including spam folder)
3. Customer should receive email with code: `88VDIX91QGS5GAX4WQOJ`

---

## 🆘 Still Need Help?

**Check if you actually have PowerShell:**

1. Press `Windows Key`
2. Type: `powershell`
3. If it appears, you DO have PowerShell! Click it to open.

**All Windows 10/11 computers have PowerShell by default.**

If you see PowerShell in your start menu, use the original guide: [DETAILED_EMAIL_FIX_SOLUTION.md](DETAILED_EMAIL_FIX_SOLUTION.md)

---

**Quick Links:**
- Supabase Functions: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/functions
- Supabase Secrets: https://app.supabase.com/project/olrrbyrzrotojsjkqcxr/settings/functions
- Gmail App Passwords: https://myaccount.google.com/apppasswords

**Last Updated:** March 1, 2026  
**Customer Code:** 88VDIX91QGS5GAX4WQOJ  
**Customer Email:** jay-begubot@student.trimexcolleges.edu.ph
