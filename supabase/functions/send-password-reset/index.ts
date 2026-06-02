// ============================================================================
// Supabase Edge Function: send-password-reset
// ============================================================================
// Sends password reset email to owner with a secure reset link
// Uses Gmail SMTP with App Password
// Called from: password_reset_service.dart → sendPasswordResetEmail()
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
import { createHash } from "https://deno.land/std@0.168.0/hash/mod.ts"

const SMTP_HOST        = Deno.env.get('SMTP_HOST') || 'smtp.gmail.com'
const SMTP_PORT        = parseInt(Deno.env.get('SMTP_PORT') || '587')
const SMTP_USER        = Deno.env.get('SMTP_USER')
const SMTP_PASS        = Deno.env.get('SMTP_PASS')
const DEVELOPER_EMAIL  = Deno.env.get('DEVELOPER_EMAIL') || 'support@smartpos.app'

// In-memory storage for reset tokens (valid for 1 hour)
// In production, use a database like Supabase
const resetTokens = new Map<string, { email: string; expires: number }>()

interface ResetEmailPayload {
  email: string
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
    const payload: ResetEmailPayload = await req.json()
    const { email } = payload

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'Missing required field: email' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`🔐 Generating password reset token for: ${email}`)

    // Generate secure token
    const token = generateSecureToken()
    const expiresAt = Date.now() + 3600000 // 1 hour from now
    
    // Store token with expiry
    resetTokens.set(token, { email, expires: expiresAt })

    // Clean up expired tokens
    cleanupExpiredTokens()

    console.log(`📧 Sending password reset email to: ${email}`)

    // Send the email with reset link
    const sendResult = await sendResetEmail(email, token)

    if (!sendResult.success) {
      console.error('❌ Failed to send email:', sendResult.error)
      
      const isConfigError = sendResult.error?.includes('not configured')
      const statusCode = isConfigError ? 400 : 500
      
      return new Response(
        JSON.stringify({ 
          success: false,
          error: sendResult.error,
          details: 'Check Supabase secrets: SMTP_USER, SMTP_PASS, and DEVELOPER_EMAIL'
        }),
        { status: statusCode, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Password reset email sent via Gmail SMTP`)

    return new Response(
      JSON.stringify({
        success: true,
        message: `Password reset link sent to ${email}`,
        token: token, // Return token for the app to use
        expiresIn: 3600 // seconds
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    console.error('❌ Unhandled error in send-password-reset:', err)
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

// ── Helper Functions ──────────────────────────────────────────────────────────

function generateSecureToken(): string {
  const bytes = new Uint8Array(32)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, byte => byte.toString(16).padStart(2, '0')).join('')
}

function cleanupExpiredTokens(): void {
  const now = Date.now()
  for (const [token, data] of resetTokens.entries()) {
    if (data.expires < now) {
      resetTokens.delete(token)
      console.log(`🧹 Cleaned up expired token for: ${data.email}`)
    }
  }
}

// Export token storage for verify function to access
export { resetTokens }

// ── Gmail SMTP Sender ─────────────────────────────────────────────────────────

async function sendResetEmail(email: string, token: string): Promise<{ success: boolean; error?: string }> {
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
  4. Set it as SMTP_PASS in Supabase`
      console.error(msg)
      return { success: false, error: msg }
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
      return response
    }

    // Helper to send SMTP command
    async function sendCommand(cmd: string): Promise<string> {
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

    // Upgrade to TLS
    const secConn = await Deno.startTls(conn, { hostname: SMTP_HOST })
    const secEncoder = new TextEncoder()
    const secDecoder = new TextDecoder()

    // Send EHLO again over TLS
    await secConn.write(secEncoder.encode('EHLO smartpos\r\n'))
    const ehloBuf = new Uint8Array(4096)
    await secConn.read(ehloBuf)

    // AUTH LOGIN
    await secConn.write(secEncoder.encode('AUTH LOGIN\r\n'))
    const authPrompt1 = new Uint8Array(4096)
    await secConn.read(authPrompt1)

    // Send username (base64)
    await secConn.write(secEncoder.encode(`${btoa(SMTP_USER)}\r\n`))
    const authPrompt2 = new Uint8Array(4096)
    await secConn.read(authPrompt2)

    // Send password (base64)
    await secConn.write(secEncoder.encode(`${btoa(SMTP_PASS)}\r\n`))
    const authResult = new Uint8Array(4096)
    const authN = await secConn.read(authResult)
    const authResp = secDecoder.decode(authResult.subarray(0, authN || 0))
    
    if (!authResp.startsWith('235')) {
      throw new Error('Authentication failed: ' + authResp)
    }

    // MAIL FROM
    await secConn.write(secEncoder.encode(`MAIL FROM:<${SMTP_USER}>\r\n`))
    const mailBuf = new Uint8Array(4096)
    await secConn.read(mailBuf)

    // RCPT TO
    await secConn.write(secEncoder.encode(`RCPT TO:<${email}>\r\n`))
    const rcptBuf = new Uint8Array(4096)
    await secConn.read(rcptBuf)

    // DATA
    await secConn.write(secEncoder.encode('DATA\r\n'))
    const dataBuf = new Uint8Array(4096)
    await secConn.read(dataBuf)

    // Email content
    const resetLink = `smartpos://reset-password?token=${token}`
    const subject = 'Password Reset Request - Smart Monitoring System'
    const body = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
    .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
    .button { display: inline-block; background: #667eea; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .token { background: #fff; border: 2px solid #667eea; padding: 15px; font-size: 24px; letter-spacing: 3px; text-align: center; font-family: 'Courier New', monospace; margin: 20px 0; border-radius: 5px; }
    .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
    .footer { text-align: center; color: #666; font-size: 12px; margin-top: 30px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🔐 Password Reset Request</h1>
    </div>
    <div class="content">
      <p>Hello,</p>
      <p>We received a request to reset your password for your <strong>Owner Account</strong> in the Smart Monitoring System.</p>
      
      <h3>Reset Token:</h3>
      <div class="token">${token.substring(0, 16)}</div>
      
      <p>Copy this token and paste it in the app to reset your password.</p>
      
      <div class="warning">
        <strong>⚠️ Security Notice:</strong>
        <ul>
          <li>This token is valid for <strong>1 hour</strong></li>
          <li>If you didn't request this reset, please ignore this email</li>
          <li>Never share this token with anyone</li>
          <li>Our team will never ask for your password</li>
        </ul>
      </div>
      
      <p><strong>Alternative:</strong> Open this link in the app:</p>
      <p style="word-break: break-all; background: #fff; padding: 10px; border-radius: 5px; font-size: 12px;">${resetLink}</p>
      
      <p>If you have any questions or concerns, please contact our support team.</p>
      
      <p>Best regards,<br>
      <strong>Smart Monitoring System Team</strong></p>
    </div>
    <div class="footer">
      <p>This is an automated message. Please do not reply to this email.</p>
      <p>&copy; ${new Date().getFullYear()} Smart Monitoring System. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
    `.trim()

    const emailMessage = [
      `From: Smart POS <${SMTP_USER}>`,
      `To: ${email}`,
      `Subject: ${subject}`,
      `MIME-Version: 1.0`,
      `Content-Type: text/html; charset=UTF-8`,
      ``,
      body,
      `.`
    ].join('\r\n')

    await secConn.write(secEncoder.encode(emailMessage + '\r\n'))
    const sendBuf = new Uint8Array(4096)
    const sendN = await secConn.read(sendBuf)
    const sendResp = secDecoder.decode(sendBuf.subarray(0, sendN || 0))

    if (!sendResp.startsWith('250')) {
      throw new Error('Failed to send email: ' + sendResp)
    }

    // QUIT
    await secConn.write(secEncoder.encode('QUIT\r\n'))
    secConn.close()

    console.log(`✅ Email sent successfully to ${email}`)
    return { success: true }

  } catch (err) {
    console.error('❌ SMTP Error:', err)
    const msg = err instanceof Error ? err.message : String(err)
    return { success: false, error: msg }
  }
}
