const RESEND_EMAILS_URL = 'https://api.resend.com/emails';

function getResendConfig() {
  return {
    apiKey: String(process.env.RESEND_API_KEY || '').trim(),
    fromEmail: String(process.env.FROM_EMAIL || '').trim(),
  };
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

async function sendEmail({ to, subject, text, html, fetchImpl = fetch }) {
  const { apiKey, fromEmail } = getResendConfig();
  const missing = [];
  if (!apiKey) missing.push('RESEND_API_KEY');
  if (!fromEmail) missing.push('FROM_EMAIL');
  if (!to) missing.push('recipient email');

  if (missing.length) {
    throw new Error(`Resend is not configured. Missing: ${missing.join(', ')}`);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    const response = await fetchImpl(RESEND_EMAILS_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from: fromEmail, to: [to], subject, text, html }),
      signal: controller.signal,
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      const detail = payload.message || payload.name || 'Unknown Resend error.';
      throw new Error(`Resend rejected the email (${response.status}): ${detail}`);
    }

    if (!payload.id) {
      throw new Error('Resend accepted the request without returning an email ID.');
    }

    return payload.id;
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new Error('Resend request timed out after 15 seconds.');
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = {
  escapeHtml,
  sendEmail,
};
