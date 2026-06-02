import { serve } from 'std/server';
import { createClient } from '@supabase/supabase-js';

// Expects SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables
const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

async function hashString(msg: string) {
  const enc = new TextEncoder();
  const data = enc.encode(msg);
  const hashBuf = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuf));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

serve(async (req) => {
  try {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    const body = await req.json();
    const email = (body.email || '').toLowerCase();
    const otp = (body.otp || '').toString();
    const newPassword = (body.newPassword || '').toString();
    if (!email || !otp || newPassword.length < 6) return new Response('Invalid payload', { status: 400 });

    const supabase = createClient(supabaseUrl, serviceRole);

    // Hash provided otp and find matching OTP that is not used and not expired
    const hashed = await hashString(otp);
    const now = new Date().toISOString();
    const { data: rows, error } = await supabase
      .from('email_otps')
      .select('*')
      .eq('email', email)
      .eq('otp', hashed)
      .eq('used', false)
      .gte('expires_at', now);
    if (error) {
      console.error('DB error select', error);
      return new Response('DB error', { status: 500 });
    }

    if (!rows || rows.length === 0) {
      return new Response(JSON.stringify({ success: false, reason: 'invalid_or_expired' }), { status: 400 });
    }

    // Mark OTP used
    const { error: updErr } = await supabase.from('email_otps').update({ used: true }).match({ id: rows[0].id });
    if (updErr) {
      console.error('DB update error', updErr);
    }

    // Update user's password using admin privileges
    const { data: userData, error: pwErr } = await supabase.auth.admin.updateUserByEmail(email, { password: newPassword });
    if (pwErr) {
      console.error('updateUser error', pwErr);
      return new Response(JSON.stringify({ success: false, reason: 'update_failed' }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response('Internal error', { status: 500 });
  }
});
