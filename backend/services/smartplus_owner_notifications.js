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

function manilaHour(now = new Date()) {
  return Number(new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Manila', hour: '2-digit', hourCycle: 'h23',
  }).format(now));
}

function manilaWeekday(now = new Date()) {
  return new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Manila', weekday: 'short',
  }).format(now);
}

function isQuietHour(preferences, now = new Date()) {
  const start = preferences.quiet_hours_start;
  const end = preferences.quiet_hours_end;
  if (!Number.isInteger(Number(start)) || !Number.isInteger(Number(end)) ||
      Number(start) < 0 || Number(start) > 23 || Number(end) < 0 || Number(end) > 23 ||
      Number(start) === Number(end)) return false;
  const hour = manilaHour(now);
  return Number(start) < Number(end)
    ? hour >= Number(start) && hour < Number(end)
    : hour >= Number(start) || hour < Number(end);
}

function severityRank(level) {
  return { info: 0, warning: 1, critical: 2 }[level] ?? 0;
}

function asNumber(value) {
  return Number(value || 0);
}

function supplierDeliverySuggestions(rows = []) {
  return rows.map((row) => {
    const orderNumber = String(row.order_number || 'Unknown purchase order');
    const supplier = String(row.supplier_name || 'Unassigned supplier');
    const items = String(row.ordered_items || 'No line items recorded');
    const expected = row.expected_delivery ? String(row.expected_delivery).slice(0, 10) : 'No expected delivery date';
    const overdueDays = Math.max(0, Number(row.overdue_days || 0));
    const impact = Number(row.low_stock_count || 0);
    const prefix = `Rule: Purchase Order ${orderNumber}. Supplier: ${supplier}. Ordered: ${items}. Expected delivery: ${expected}.`;
    const impactText = impact > 0 ? ` Impact: ${impact} affected low-stock or out-of-stock product(s).` : '';
    const status = String(row.status || '').toLowerCase();
    if (Number(row.missing_inventory || 0) === 1) {
      return {
        level: 'critical',
        title: 'Delivered stock has not been added to inventory',
        message: `${prefix} Delivery is marked received, but no linked restock record was found.${impactText} Suggested next step: Verify the delivery and record stock.`,
      };
    }
    if (status === 'partial') {
      return {
        level: 'warning',
        title: 'Partial supplier delivery needs review',
        message: `${prefix} A partial receipt is recorded.${impactText} Suggested next step: Record the remaining delivery or contact supplier.`,
      };
    }
    if (status === 'completed') {
      return {
        level: 'warning',
        title: 'Shipment marked complete but not received',
        message: `${prefix} Shipment is marked completed but has not been received into inventory.${impactText} Suggested next step: Check shipment and record delivery quantities.`,
      };
    }
    if (status === 'pending' && Number(row.pending_days || 0) >= 2 && !row.expected_delivery) {
      return {
        level: 'warning',
        title: 'Supplier order awaiting confirmation',
        message: `${prefix} The order has been pending for ${row.pending_days} day(s).${impactText} Suggested next step: Contact supplier and record approval or cancellation.`,
      };
    }
    if (overdueDays > 0) {
      return {
        level: impact > 0 ? 'critical' : 'warning',
        title: 'Supplier delivery is overdue',
        message: `${prefix} Status: ${overdueDays} day(s) overdue.${impactText} Suggested next step: Confirm delivery status with supplier.`,
      };
    }
    return {
      level: 'info',
      title: 'Supplier delivery is due today',
      message: `${prefix} Status: due today.${impactText} Suggested next step: Confirm the delivery schedule with supplier.`,
    };
  });
}

function normalizeSuggestions({ outOfStock, lowStock, discountReview, supplierDelivery = [], preferences = {} }) {
  const suggestions = [];
  if (preferences.low_stock_enabled !== false && outOfStock.length) {
    suggestions.push({
      level: 'critical',
      title: 'Products are out of stock',
      message: `${outOfStock.length} product(s) cannot be sold: ${outOfStock.map((item) => item.name).join(', ')}.`,
    });
  }
  if (preferences.low_stock_enabled !== false && lowStock.length) {
    suggestions.push({
      level: 'warning',
      title: 'Low-stock reorder suggested',
      message: `${lowStock.length} product(s) are at their reorder level, including ${lowStock.map((item) => item.name).join(', ')}.`,
    });
  }
  if (preferences.discount_enabled !== false && asNumber(discountReview?.count) > 0) {
    suggestions.push({
      level: 'info',
      title: 'Large discounts need review',
      message: `${discountReview.count} completed sale(s) in the last 30 days used a discount of 20% or more. This is a review reminder, not a fraud finding.`,
    });
  }
  if (preferences.supplier_delivery_enabled !== false) {
    suggestions.push(...supplierDeliverySuggestions(supplierDelivery));
  }
  const minimum = preferences.minimum_severity || 'info';
  return suggestions.filter((suggestion) =>
    severityRank(suggestion.level) >= severityRank(minimum));
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

  const preferenceRows = await dbQuery(
      `SELECT email_enabled, low_stock_enabled, discount_enabled, supplier_delivery_enabled,
              minimum_severity, digest_frequency, quiet_hours_start, quiet_hours_end
       FROM smartplus_notification_preferences
      WHERE business_id = ? LIMIT 1`,
    [businessId],
  ).catch(() => []);
  const preferences = preferenceRows[0] || {};
  if (Number(preferences.email_enabled ?? 1) !== 1) {
    return { skipped: 'email_disabled_by_owner' };
  }
  const digestFrequency = String(preferences.digest_frequency || 'daily');
  if (digestFrequency === 'off') return { skipped: 'digest_disabled_by_owner' };
  if (digestFrequency === 'weekly' && manilaWeekday() !== 'Mon') {
    return { skipped: 'weekly_digest_not_due' };
  }
  if (isQuietHour(preferences)) return { skipped: 'quiet_hours' };

  const [outOfStock, lowStock, discountRows, supplierDelivery] = await Promise.all([
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
    dbQuery(
      `SELECT po.order_number, po.status, po.order_date, po.expected_delivery,
              COALESCE(s.name, 'Unassigned supplier') AS supplier_name,
              GROUP_CONCAT(CONCAT(poi.product_name, ' x', poi.quantity)
                ORDER BY poi.product_name SEPARATOR ', ') AS ordered_items,
              SUM(CASE WHEN p.quantity <= p.low_stock_threshold THEN 1 ELSE 0 END) AS low_stock_count,
              MAX(CASE WHEN po.status = 'received' AND poi.received_quantity > 0
                AND rr.id IS NULL THEN 1 ELSE 0 END) AS missing_inventory,
              DATEDIFF(CURDATE(), DATE(po.expected_delivery)) AS overdue_days,
              DATEDIFF(CURDATE(), DATE(po.order_date)) AS pending_days
         FROM purchase_orders po
         LEFT JOIN suppliers s ON s.id = po.supplier_id AND s.business_id = po.business_id
         LEFT JOIN purchase_order_items poi ON poi.order_id = po.id AND poi.business_id = po.business_id
         LEFT JOIN products p ON p.id = poi.product_id AND p.business_id = po.business_id
         LEFT JOIN restock_records rr ON rr.business_id = po.business_id
           AND rr.referenced_by = CONCAT('Purchase Order ', po.order_number)
        WHERE po.business_id = ?
          AND (
            po.status IN ('completed', 'partial')
            OR (po.status = 'received' AND poi.received_quantity > 0)
            OR (po.status = 'pending' AND po.expected_delivery IS NULL
                AND DATEDIFF(CURDATE(), DATE(po.order_date)) >= 2
                AND MOD(DATEDIFF(CURDATE(), DATE(po.order_date)) - 2, 3) = 0)
            OR (po.status NOT IN ('received', 'cancelled') AND po.expected_delivery IS NOT NULL
                AND (DATEDIFF(CURDATE(), DATE(po.expected_delivery)) = 0
                  OR DATEDIFF(CURDATE(), DATE(po.expected_delivery)) = 1
                  OR (DATEDIFF(CURDATE(), DATE(po.expected_delivery)) > 1
                    AND MOD(DATEDIFF(CURDATE(), DATE(po.expected_delivery)), 3) = 0)))
          )
        GROUP BY po.id, po.order_number, po.status, po.order_date, po.expected_delivery, s.name`,
      [businessId],
    ).catch(() => []),
  ]);
  const suggestions = normalizeSuggestions({
    outOfStock,
    lowStock,
    discountReview: discountRows[0],
    preferences: {
      low_stock_enabled: Number(preferences.low_stock_enabled ?? 1) === 1,
      discount_enabled: Number(preferences.discount_enabled ?? 1) === 1,
      supplier_delivery_enabled:
        Number(preferences.supplier_delivery_enabled ?? 1) === 1,
      minimum_severity: preferences.minimum_severity,
    },
    supplierDelivery,
  });
  if (!suggestions.length) return { skipped: 'no_actionable_suggestions' };

  const notificationKey = digestFrequency === 'weekly'
    ? `owner-digest-week-${manilaDate()}`
    : `owner-digest-${manilaDate()}`;
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

/// Runs from the backend process as well as after sync. Each individual
/// business remains protected by the per-day delivery key in dispatchOwnerDigest.
async function dispatchScheduledOwnerDigests(dependencies = {}) {
  if (!OWNER_EMAIL_ENABLED) return { skipped: 'disabled' };
  const dbQuery = dependencies.query || query;
  const businesses = await dbQuery(
    'SELECT id FROM businesses WHERE is_active = 1',
  );
  const results = await Promise.allSettled(
    businesses.map((business) => dispatchOwnerDigest(business.id, dependencies)),
  );
  return {
    processed: businesses.length,
    failed: results.filter((result) => result.status === 'rejected').length,
  };
}

module.exports = {
  dispatchOwnerDigest,
  emailContent,
  manilaDate,
  manilaHour,
  manilaWeekday,
  isQuietHour,
  normalizeSuggestions,
  supplierDeliverySuggestions,
  dispatchScheduledOwnerDigests,
};
