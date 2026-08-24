const test = require('node:test');
const assert = require('node:assert/strict');
const { sendEmail } = require('../services/resend_email');

test('Resend sender sends a JSON HTTPS request and returns the provider email ID', async () => {
  const previousApiKey = process.env.RESEND_API_KEY;
  const previousFrom = process.env.FROM_EMAIL;
  process.env.RESEND_API_KEY = 're_test_key';
  process.env.FROM_EMAIL = 'Smart Monitoring <noreply@example.com>';

  let captured;
  try {
    const id = await sendEmail({
      to: 'subscriber@example.com',
      subject: 'Test email',
      text: 'Test body',
      html: '<p>Test body</p>',
      fetchImpl: async (url, options) => {
        captured = { url, options };
        return new Response(JSON.stringify({ id: 'email_test_123' }), { status: 200 });
      },
    });

    assert.equal(id, 'email_test_123');
    assert.equal(captured.url, 'https://api.resend.com/emails');
    assert.equal(captured.options.headers.Authorization, 'Bearer re_test_key');
    assert.deepEqual(JSON.parse(captured.options.body), {
      from: 'Smart Monitoring <noreply@example.com>',
      to: ['subscriber@example.com'],
      subject: 'Test email',
      text: 'Test body',
      html: '<p>Test body</p>',
    });
  } finally {
    if (previousApiKey === undefined) delete process.env.RESEND_API_KEY;
    else process.env.RESEND_API_KEY = previousApiKey;
    if (previousFrom === undefined) delete process.env.FROM_EMAIL;
    else process.env.FROM_EMAIL = previousFrom;
  }
});
