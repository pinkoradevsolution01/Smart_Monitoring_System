const assert = require('node:assert/strict');
const test = require('node:test');

process.env.SMARTPLUS_OWNER_EMAIL_ENABLED = 'true';

const {
  dispatchOwnerDigest,
  dispatchScheduledOwnerDigests,
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

test('SmartPlus supplier delivery suggestions identify the order, timing, impact, and owner action', () => {
  const suggestions = normalizeSuggestions({
    outOfStock: [],
    lowStock: [],
    discountReview: { count: 0 },
    supplierDelivery: [{
      order_number: 'PO-20261016-001',
      supplier_name: 'ABC Supplies',
      ordered_items: 'Milk x12, Bread x6',
      expected_delivery: '2026-10-14',
      overdue_days: 2,
      low_stock_count: 3,
      status: 'approved',
    }],
  });
  assert.equal(suggestions.length, 1);
  assert.match(suggestions[0].title, /overdue/i);
  assert.match(suggestions[0].message, /Rule:/);
  assert.match(suggestions[0].message, /PO-20261016-001/);
  assert.match(suggestions[0].message, /ABC Supplies/);
  assert.match(suggestions[0].message, /2 day\(s\) overdue/);
  assert.match(suggestions[0].message, /3 affected/);
  assert.match(suggestions[0].message, /Confirm delivery status/);
});

test('SmartPlus emails only the database owner for the verified business and deduplicates the day', async () => {
  const calls = [];
  const emails = [];
  const dbQuery = async (sql, params = []) => {
    calls.push({ sql, params });
    if (sql.includes('FROM businesses')) {
      return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
    }
    if (sql.includes('smartplus_notification_preferences')) return [];
    if (sql.includes('quantity <= 0')) return [{ name: 'Milk', quantity: 0 }];
    if (sql.includes('low_stock_threshold')) return [{ name: 'Bread', quantity: 2, low_stock_threshold: 5 }];
    if (sql.includes('discount / subtotal')) return [{ count: 0 }];
    if (sql.includes('FROM purchase_orders po')) return [];
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

test('scheduled SmartPlus digest evaluates active businesses only', async () => {
  const queried = [];
  const result = await dispatchScheduledOwnerDigests({
    query: async (sql, params = []) => {
      queried.push({ sql, params });
      if (sql === 'SELECT id FROM businesses WHERE is_active = 1') {
        return [{ id: 'business-a' }];
      }
      if (sql.includes('FROM businesses')) {
        return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
      }
      if (sql.includes('smartplus_notification_preferences')) return [{ email_enabled: 0 }];
      throw new Error(`Unexpected query: ${sql}`);
    },
  });
  assert.equal(result.processed, 1);
  assert.equal(result.failed, 0);
  assert.equal(queried.some((call) => call.params.includes('business-b')), false);
});
