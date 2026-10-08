const { randomUUID } = require('crypto');
const { query, execute } = require('../db');
const { escapeHtml, sendEmail } = require('./resend_email');

const OWNER_EMAIL_ENABLED = String(
  process.env.SMARTPLUS_OWNER_EMAIL_ENABLED || '',
).trim().toLowerCase() === 'true';

function manilaDate(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const value = Object.fromEntries(
    parts.filter((part) => part.type !== 'literal').map((part) => [part.type, part.value]),
  );
  return `${value.year}-${value.month}-${value.day}`;
}

function asNumber(value) {
  return Number(value || 0);
}

function normalizeSuggestions({ outOfStock, lowStock, discountReview }) {
  const suggestions = [];
  if (outOfStock.length) {
    suggestions.push({
      level: 'critical',
      title: 'Products are out of stock',
      message: `${outOfStock.length} product(s) cannot be sold: ${outOfStock.map((item) => item.name).join(', ')}.`,
    });
  }
  if (lowStock.length) {
    suggestions.push({
      level: 'warning',
      title: 'Low-stock reorder suggested',
      message: `${lowStock.length} product(s) are at their reorder level, including ${lowStock.map((item) => item.name).join(', ')}.`,
    });
  }
  if (asNumber(discountReview?.count) > 0) {
    suggestions.push({
      level: 'info',
      title: 'Large discounts need review',
      message: `${discountReview.count} completed sale(s) in the last 30 days used a discount of 20% or more. This is a review reminder, not a fraud finding.`,
    });
  }
  return suggestions;
}

function emailContent({ businessName, suggestions }) {
  const textLines = [
    `SmartPlus update for ${businessName}`,
    '',
    ...suggestions.flatMap((suggestion) => [`${suggestion.title}`, suggestion.message, '']),
    'Open Smart Monitoring System to review the relevant business records.',
    '',
    'This is an operational suggestion based on recorded business data. It does not make changes or place orders automatically.',
  ];
  const items = suggestions.map((suggestion) => `
    <li style="margin:0 0 16px">
      <strong>${escapeHtml(suggestion.title)}</strong><br>
      <span>${escapeHtml(suggestion.message)}</span>
    </li>`).join('');
  const html = `
    <div style="font-family:Arial,sans-serif;color:#1e293b;line-height:1.5">
      <h2 style="margin:0 0 8px;color:#4338ca">SmartPlus update</h2>
      <p style="margin:0 0 20px">${escapeHtml(businessName)}</p>
      <ul style="padding-left:20px">${items}</ul>
      <p>Open Smart Monitoring System to review the relevant business records.</p>
      <p style="font-size:12px;color:#64748b">This is an operational suggestion based on recorded business data. It does not make changes or place orders automatically.</p>
    </div>`;
  return { text: textLines.join('\n'), html };
}

/**
 * Sends, at most, one non-sensitive SmartPlus digest per business per
 * Philippines business day. The owner email and tenant scope always come
 * from the database; this service never accepts either from a Flutter client.
 */
async function dispatchOwnerDigest(businessId, dependencies = {}) {
  if (!OWNER_EMAIL_ENABLED) return { skipped: 'disabled' };

  const dbQuery = dependencies.query || query;
  const dbExecute = dependencies.execute || execute;
  const emailSender = dependencies.sendEmail || sendEmail;

  const businesses = await dbQuery(
    `SELECT id, name, owner_email
       FROM businesses
      WHERE id = ? AND is_active = 1
      LIMIT 1`,
    [businessId],
  );
  const business = businesses[0];
  if (!business?.owner_email) return { skipped: 'business_not_found' };

  const [outOfStock, lowStock, discountRows] = await Promise.all([
    dbQuery(
      `SELECT name, quantity
         FROM products
        WHERE business_id = ? AND quantity <= 0
        ORDER BY name ASC LIMIT 3`,
      [businessId],
    ),
    dbQuery(
      `SELECT name, quantity, low_stock_threshold
         FROM products
        WHERE business_id = ?
          AND quantity > 0
          AND quantity <= low_stock_threshold
        ORDER BY quantity ASC, name ASC LIMIT 3`,
      [businessId],
    ),
    dbQuery(
      `SELECT COUNT(*) AS count
         FROM sales
        WHERE business_id = ?
          AND status = 'completed'
          AND datetime >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
          AND subtotal > 0
          AND discount / subtotal >= 0.20`,
      [businessId],
    ),
  ]);
  const suggestions = normalizeSuggestions({
    outOfStock,
    lowStock,
    discountReview: discountRows[0],
  });
  if (!suggestions.length) return { skipped: 'no_actionable_suggestions' };

  const notificationKey = `owner-digest-${manilaDate()}`;
  // Reserve the daily delivery before contacting Resend. The unique key makes
  // concurrent device syncs unable to send duplicate owner messages.
  const insert = await dbExecute(
    `INSERT IGNORE INTO smartplus_email_deliveries
      (id, business_id, notification_key, owner_email, status)
      VALUES (?, ?, ?, ?, 'pending')`,
    [randomUUID(), business.id, notificationKey, business.owner_email],
  );
  const result = Array.isArray(insert) ? insert[0] : insert;
  if (Number(result?.affectedRows || 0) !== 1) return { skipped: 'already_sent_today' };

  try {
    const content = emailContent({
      businessName: String(business.name || 'your business'),
      suggestions,
    });
    const providerMessageId = await emailSender({
      to: business.owner_email,
      subject: `SmartPlus update for ${business.name || 'your business'}`,
      ...content,
    });
    await dbExecute(
      `UPDATE smartplus_email_deliveries
          SET status = 'sent', provider_message_id = ?, sent_at = CURRENT_TIMESTAMP, error_message = NULL
        WHERE business_id = ? AND notification_key = ?`,
      [providerMessageId, business.id, notificationKey],
    );
    return { sent: true, suggestionCount: suggestions.length };
  } catch (error) {
    await dbExecute(
      `UPDATE smartplus_email_deliveries
          SET status = 'failed', error_message = ?
        WHERE business_id = ? AND notification_key = ?`,
      [String(error.message || error).slice(0, 1000), business.id, notificationKey],
    ).catch(() => undefined);
    throw error;
  }
}

module.exports = {
  dispatchOwnerDigest,
  emailContent,
  manilaDate,
  normalizeSuggestions,
};
