// ============================================================================
// Supabase Edge Function: send-activation-code
// ============================================================================
// Sends activation code email to customer after developer fulfills request.
// Uses Gmail SMTP with App Password (FREE - no API keys needed)
// Called from: code_request_service.dart → sendActivationEmail()
//
// Setup: 
//   1. Enable 2-Step Verification on your Gmail account
//   2. Generate App Password at: https://myaccount.google.com/apppasswords
//   3. Set Supabase secrets:
//      supabase secrets set SMTP_USER=your-email@gmail.com
//      supabase secrets set SMTP_PASS=your-16-char-app-password
//      supabase secrets set DEVELOPER_EMAIL=your-email@gmail.com
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const SMTP_HOST        = Deno.env.get('SMTP_HOST') || 'smtp.gmail.com'
const SMTP_PORT        = parseInt(Deno.env.get('SMTP_PORT') || '587')
const SMTP_USER        = Deno.env.get('SMTP_USER')
const SMTP_PASS        = Deno.env.get('SMTP_PASS')
const DEVELOPER_EMAIL  = Deno.env.get('DEVELOPER_EMAIL') || 'support@smartpos.app'

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

    // Send the email
    const sendResult = await sendViaSmtp({ email, code, business_name, package_name })

    if (!sendResult.success) {
      console.error('❌ Failed to send email:', sendResult.error)
      
      const isConfigError = sendResult.error?.includes('not configured')
      const statusCode = isConfigError ? 400 : 500
      
      return new Response(
        JSON.stringify({ 
          success: false,
          error: sendResult.error,
          provider: sendResult.provider,
          details: 'Check Supabase secrets: SMTP_USER, SMTP_PASS, and DEVELOPER_EMAIL'
        }),
        { status: statusCode, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Activation email sent via Gmail SMTP`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Activation code emailed to ${email}`,
        provider: 'smtp',
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('❌ Unhandled error in send-activation-code:', err)
    const msg = err instanceof Error ? err.message : String(err)
    return new Response(
      JSON.stringify({ 
        success: false,
        error: 'Internal server error', 
        details: msg,
        hint: 'Check function logs and Gmail SMTP credentials'
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// ── Lightweight Gmail SMTP Sender ────────────────────────────────────────────

async function sendViaSmtp(data: EmailPayload): Promise<{ success: boolean; provider: string; error?: string }> {
  try {
    if (!SMTP_USER || !SMTP_PASS) {
      const msg = `❌ Gmail SMTP is not configured.
      
Set these Supabase secrets:

  supabase secrets set SMTP_USER=your-email@gmail.com
  supabase secrets set SMTP_PASS=16-char-app-password
  supabase secrets set DEVELOPER_EMAIL=your-email@gmail.com

To generate a Gmail App Password:
  1. Go to https://myaccount.google.com/apppasswords
  2. Select "Mail" and "Windows Computer"
  3. Copy the 16-character password (no spaces)
  4. Set it as SMTP_PASS in Supabase

Requirements:
  ✓ Gmail account with 2-Step Verification enabled
  ✓ App Password is SECURE and correct
  ✓ Completely FREE - 500 emails/day`
      console.error(msg)
      return { success: false, provider: 'smtp', error: msg }
    }

    console.log(`📧 Connecting to Gmail SMTP: ${SMTP_HOST}:${SMTP_PORT}`)
    
    // Connect to Gmail SMTP
    const conn = await Deno.connect({
      hostname: SMTP_HOST,
      port: SMTP_PORT,
    })

    const encoder = new TextEncoder()
    const decoder = new TextDecoder()
    
    // Helper to read SMTP response
    async function readResponse(): Promise<string> {
      const buf = new Uint8Array(4096)
      const n = await conn.read(buf)
      if (!n) throw new Error('Connection closed by server')
      const response = decoder.decode(buf.subarray(0, n))
      console.log(`← ${response.trim()}`)
      return response
    }

    // Helper to send SMTP command
    async function sendCommand(cmd: string): Promise<string> {
      console.log(`→ ${cmd}`)
      await conn.write(encoder.encode(cmd + '\r\n'))
      return await readResponse()
    }

    // SMTP handshake
    const greeting = await readResponse()
    if (!greeting.startsWith('220')) {
      throw new Error('Invalid greeting: ' + greeting)
    }

    // EHLO
    await sendCommand(`EHLO smartpos`)

    // STARTTLS
    await sendCommand('STARTTLS')

    // Upgrade to TLS with proper hostname for certificate validation
    const secConn = await Deno.startTls(conn, { hostname: SMTP_HOST })
    const secEncoder = new TextEncoder()
    const secDecoder = new TextDecoder()

    // Send EHLO again over TLS
    const ehloMsg = 'EHLO smartpos\r\n'
    await secConn.write(secEncoder.encode(ehloMsg))
    const ehloBuf = new Uint8Array(4096)
    const ehloN = await secConn.read(ehloBuf)
    const ehloResp = secDecoder.decode(ehloBuf.subarray(0, ehloN || 0))
    console.log(`← ${ehloResp.trim()}`)

    // AUTH LOGIN
    const authMsg = `AUTH LOGIN\r\n`
    await secConn.write(secEncoder.encode(authMsg))
    const authPrompt1 = new Uint8Array(4096)
    const ap1N = await secConn.read(authPrompt1)
    const ap1 = secDecoder.decode(authPrompt1.subarray(0, ap1N || 0))
    console.log(`← ${ap1.trim()}`)

    // Send username (base64 encoded)
    const userB64 = btoa(SMTP_USER)
    const userMsg = `${userB64}\r\n`
    await secConn.write(secEncoder.encode(userMsg))
    const authPrompt2 = new Uint8Array(4096)
    const ap2N = await secConn.read(authPrompt2)
    const ap2 = secDecoder.decode(authPrompt2.subarray(0, ap2N || 0))
    console.log(`← ${ap2.trim()}`)

    // Send password (base64 encoded)
    const passB64 = btoa(SMTP_PASS)
    const passMsg = `${passB64}\r\n`
    await secConn.write(secEncoder.encode(passMsg))
    const authResp = new Uint8Array(4096)
    const authN = await secConn.read(authResp)
    const authRespStr = secDecoder.decode(authResp.subarray(0, authN || 0))
    console.log(`← ${authRespStr.trim()}`)
    
    if (!authRespStr.startsWith('235')) {
      secConn.close()
      return { 
        success: false, 
        provider: 'smtp', 
        error: `Auth failed: Check SMTP_USER and SMTP_PASS (use Gmail App Password, not regular password)`
      }
    }

    // Send email
    const msg = buildSmtpMessage(data)
    
    // MAIL FROM
    const fromCmd = `MAIL FROM:<${DEVELOPER_EMAIL}>\r\n`
    await secConn.write(secEncoder.encode(fromCmd))
    const fromBuf = new Uint8Array(4096)
    const fromN = await secConn.read(fromBuf)
    console.log(`← ${secDecoder.decode(fromBuf.subarray(0, fromN || 0)).trim()}`)

    // RCPT TO
    const toCmd = `RCPT TO:<${data.email}>\r\n`
    await secConn.write(secEncoder.encode(toCmd))
    const toBuf = new Uint8Array(4096)
    const toN = await secConn.read(toBuf)
    console.log(`← ${secDecoder.decode(toBuf.subarray(0, toN || 0)).trim()}`)

    // DATA
    const dataCmd = 'DATA\r\n'
    await secConn.write(secEncoder.encode(dataCmd))
    const dataBuf = new Uint8Array(4096)
    const dataN = await secConn.read(dataBuf)
    console.log(`← ${secDecoder.decode(dataBuf.subarray(0, dataN || 0)).trim()}`)

    // Send message body
    await secConn.write(secEncoder.encode(msg))
    await secConn.write(secEncoder.encode('\r\n.\r\n'))
    
    const msgBuf = new Uint8Array(4096)
    const msgN = await secConn.read(msgBuf)
    const msgResp = secDecoder.decode(msgBuf.subarray(0, msgN || 0))
    console.log(`← ${msgResp.trim()}`)

    if (!msgResp.startsWith('250')) {
      secConn.close()
      throw new Error('Failed to send message: ' + msgResp)
    }

    // QUIT
    await secConn.write(secEncoder.encode('QUIT\r\n'))
    secConn.close()

    console.log('✅ Email sent successfully via Gmail SMTP')
    return { success: true, provider: 'smtp' }
  } catch (e) {
    console.error('❌ Gmail SMTP error:', e)
    const errorMsg = e instanceof Error ? e.message : String(e)
    
    let hint = ''
    if (errorMsg.includes('STARTTLS')) {
      hint = ' (TLS failed - verify SMTP credentials)'
    } else if (errorMsg.includes('Auth') || errorMsg.includes('235')) {
      hint = ' (Auth failed - check SMTP_USER and SMTP_PASS; use Gmail App Password)'
    } else if (errorMsg.includes('ECONNREFUSED') || errorMsg.includes('network')) {
      hint = ' (Network failed - Supabase may block port 587)'
    }
    
    return { 
      success: false, 
      provider: 'smtp', 
      error: `Gmail SMTP error: ${errorMsg}${hint}`
    }
  }
}

function buildSmtpMessage(data: EmailPayload): string {
  const html = buildEmailHtml(data)
  const plaintext = `Your Smart POS Activation Code: ${data.code}`
  const boundary = 'boundary_' + Math.random().toString(36).substring(7)
  
  return `From: Smart POS <${DEVELOPER_EMAIL}>
To: ${data.email}
Subject: Smart POS Activation Code
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="${boundary}"

--${boundary}
Content-Type: text/plain; charset="UTF-8"
Content-Transfer-Encoding: 7bit

${plaintext}

--${boundary}
Content-Type: text/html; charset="UTF-8"
Content-Transfer-Encoding: 7bit

${html}

--${boundary}--`
}

// ── HTML Email Template ──────────────────────────────────────────────────────

function buildEmailHtml(data: EmailPayload): string {
  const { code, business_name, package_name } = data
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
    .card { background: #fff; border-radius: 12px; max-width: 480px; margin: 0 auto;
            padding: 32px; box-shadow: 0 2px 8px rgba(0,0,0,.1); }
    .header { text-align: center; margin-bottom: 24px; }
    .header h1 { color: #1a73e8; font-size: 24px; margin: 0; }
    .code-box { background: #f0f4ff; border: 2px dashed #1a73e8; border-radius: 8px;
                text-align: center; padding: 20px; margin: 24px 0; }
    .code-box .label { font-size: 13px; color: #666; margin-bottom: 8px; }
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
      <div class="label">ACTIVATION CODE</div>
      <div class="code">${code}</div>
    </div>

    <div class="steps">
      <h3>🚀 How to Activate</h3>
      <ol>
        <li>Open the <strong>Smart POS</strong> app</li>
        <li>Tap <strong>"Enter Activation Code"</strong></li>
        <li>Paste the code above</li>
        <li>Tap <strong>Activate</strong> — you're done!</li>
      </ol>
    </div>

    <p class="info">
      Valid for <strong>1 device</strong> · <strong>30 days</strong> subscription<br>
      Questions? Reply to this email or contact <a href="mailto:${DEVELOPER_EMAIL}">${DEVELOPER_EMAIL}</a>
    </p>

    <div class="footer">Smart POS System · Powered by Smart Monitoring</div>
  </div>
</body>
</html>
`
}
