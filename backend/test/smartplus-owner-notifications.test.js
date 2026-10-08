const assert = require('node:assert/strict');
const test = require('node:test');

process.env.SMARTPLUS_OWNER_EMAIL_ENABLED = 'true';

const {
  dispatchOwnerDigest,
  normalizeSuggestions,
} = require('../services/smartplus_owner_notifications');

test('SmartPlus creates owner-safe actionable suggestions only', () => {
  const suggestions = normalizeSuggestions({
    outOfStock: [{ name: 'Milk' }],
    lowStock: [{ name: 'Bread' }],
    discountReview: { count: 2 },
  });
  assert.equal(suggestions.length, 3);
  assert.match(suggestions[0].message, /Milk/);
  assert.match(suggestions[1].message, /Bread/);
  assert.match(suggestions[2].message, /not a fraud finding/);
});

test('SmartPlus emails only the database owner for the verified business and deduplicates the day', async () => {
  const calls = [];
  const emails = [];
  const dbQuery = async (sql, params = []) => {
    calls.push({ sql, params });
    if (sql.includes('FROM businesses')) {
      return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
    }
    if (sql.includes('quantity <= 0')) return [{ name: 'Milk', quantity: 0 }];
    if (sql.includes('low_stock_threshold')) return [{ name: 'Bread', quantity: 2, low_stock_threshold: 5 }];
    if (sql.includes('discount / subtotal')) return [{ count: 0 }];
    throw new Error(`Unexpected query: ${sql}`);
  };
  let inserts = 0;
  const dbExecute = async (sql, params = []) => {
    calls.push({ sql, params });
    if (sql.includes('INSERT IGNORE')) {
      inserts += 1;
      return [{ affectedRows: inserts === 1 ? 1 : 0 }];
    }
    if (sql.includes('UPDATE smartplus_email_deliveries')) return [{ affectedRows: 1 }];
    throw new Error(`Unexpected execute: ${sql}`);
  };
  const send = async (message) => {
    emails.push(message);
    return 'resend-message-id';
  };

  const first = await dispatchOwnerDigest('business-a', {
    query: dbQuery,
    execute: dbExecute,
    sendEmail: send,
  });
  const second = await dispatchOwnerDigest('business-a', {
    query: dbQuery,
    execute: dbExecute,
    sendEmail: send,
  });

  assert.equal(first.sent, true);
  assert.equal(second.skipped, 'already_sent_today');
  assert.equal(emails.length, 1);
  assert.equal(emails[0].to, 'owner-a@example.com');
  assert.match(emails[0].text, /Milk/);
  assert.match(emails[0].text, /Bread/);
  for (const call of calls) assert.equal(call.params.includes('business-b'), false);
});
