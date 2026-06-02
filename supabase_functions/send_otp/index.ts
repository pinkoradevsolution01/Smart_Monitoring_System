import { serve } from 'std/server';
import { createClient } from '@supabase/supabase-js';
import nodemailer from 'nodemailer';

// Utility: secure random 6-digit code and SHA-256 hashing
async function hashString(msg: string) {
  const enc = new TextEncoder();
  const data = enc.encode(msg);
  const hashBuf = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuf));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

function secureSixDigit() {
  // Use crypto.getRandomValues for secure RNG
  const arr = crypto.getRandomValues(new Uint32Array(1));
  const n = arr[0] % 900000 + 100000; // 100000..999999
  return n.toString();
}

// This Edge Function expects these environment variables to be set:
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, FROM_EMAIL

const supabaseUrl = Deno.env.get('SUPABASE_URL') || '';
const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

const transporter = nodemailer.createTransport({
  host: Deno.env.get('SMTP_HOST'),
  port: Number(Deno.env.get('SMTP_PORT') || 587),
  secure: false,
  auth: {
    user: Deno.env.get('SMTP_USER'),
    pass: Deno.env.get('SMTP_PASS'),
  },
});

// Startup diagnostics
try {
  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!serviceRole) missing.push('SUPABASE_SERVICE_ROLE_KEY');
  if (!Deno.env.get('SMTP_HOST')) missing.push('SMTP_HOST');
  if (!Deno.env.get('SMTP_USER')) missing.push('SMTP_USER');
  if (!Deno.env.get('SMTP_PASS')) missing.push('SMTP_PASS');
  if (!Deno.env.get('FROM_EMAIL')) missing.push('FROM_EMAIL');
  if (missing.length) {
    console.warn('[send-otp] missing env:', missing.join(', '));
  }
  console.log('[send-otp] starting');
} catch (e: any) {
  console.error('[send-otp] startup diagnostics failed', e?.stack || e);
}

serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const body = await req.json();
    const email = (body.email || '').toLowerCase();
    if (!email || !email.includes('@')) return new Response('Invalid email', { status: 400 });

    // fail fast if critical configuration missing
    if (!supabaseUrl || !serviceRole) {
      console.error('[send-otp] missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
      return new Response('Function not configured', { status: 500 });
    }

    const supabase = createClient(supabaseUrl, serviceRole);

    // generate secure 6-digit OTP and hash it
    const otp = secureSixDigit();
    const otpHash = await hashString(otp);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString(); // 10 minutes

    // store hashed OTP in table `email_otps` (create the table via SQL migration provided)
    const { data, error } = await supabase.from('email_otps').insert([
      { email, otp: otpHash, expires_at: expiresAt, used: false },
    ]);
    if (error) {
      console.error('[send-otp] DB insert error', error);
      return new Response('DB error', { status: 500 });
    }
    console.log('[send-otp] stored OTP row', data?.[0]?.id ?? '(no id)');

    // send email with OTP only
    const mail = {
      from: Deno.env.get('FROM_EMAIL') || 'no-reply@example.com',
      to: email,
      subject: 'Your password reset code',
      text: `Your password reset code is: ${otp}\nIt expires in 10 minutes.`,
    };

    try {
      await transporter.sendMail(mail);
      console.log('[send-otp] email sent to', email);
    } catch (mailErr: any) {
      console.error('[send-otp] SMTP send error', mailErr?.stack || mailErr);
      return new Response('SMTP error', { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (err: any) {
    console.error('[send-otp] unhandled error', err?.stack || err);
    return new Response('Internal error', { status: 500 });
  }
});
