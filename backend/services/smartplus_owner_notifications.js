const { createHash, randomUUID } = require('crypto');
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
    if (status === 'received' && Number(row.missing_inventory || 0) === 1) {
      return {
        level: 'critical',
        title: 'Delivered stock has not been added to inventory',
        message: `${prefix} Delivery is marked received, but no linked restock record was found.${impactText} Suggested next step: Verify the delivery and record stock.`,
      };
    }
    // Received orders with no missing-restock evidence are closed. Without
    // this guard they fall through to the due/overdue rules below.
    if (status === 'received' || status === 'cancelled') return null;
    // A status can lag behind a fully synced receipt. Verified item and
    // restock quantities take precedence over that stale status.
    if (Number(row.fully_restocked || 0) === 1) return null;
    if (status === 'partial') {
      return {
        level: 'warning',
        title: 'Partial supplier delivery needs review',
        message: `${prefix} A partial receipt is recorded.${impactText} Suggested next step: Record the remaining delivery or contact supplier.`,
      };
    }
    if (status === 'completed') {
      // "Completed" is an order-processing stage, not proof the shipment
      // arrived. Do not claim an expected future or undated delivery is late.
      if (!row.expected_delivery || overdueDays === 0) return null;
      return {
        level: 'warning',
        title: 'Delivery awaiting receipt',
        message: `${prefix} The order is marked completed, but delivery has not been fully recorded and is ${overdueDays} day(s) past the expected date.${impactText} Suggested next step: Check the shipment and record quantities when it arrives.`,
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
  }).filter(Boolean);
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
    `SmartPlus alert for ${businessName}`,
    '',
    ...suggestions.flatMap((suggestion) => [`${suggestion.title}`, suggestion.message, '']),
    'Open Smart Monitoring System to review the relevant business records and decide on the next step.',
    '',
    'This is an operational suggestion based on recorded business data. SmartPlus does not make changes or place orders automatically.',
  ];
  const levelColors = { critical: '#b42318', warning: '#b54708', info: '#175cd3' };
  const items = suggestions.map((suggestion) => {
    const color = levelColors[suggestion.level] || levelColors.info;
    const label = String(suggestion.level || 'info').toUpperCase();
    return `
      <tr>
        <td style="padding:0 0 16px">
          <div style="border:1px solid #e2e8f0;border-left:4px solid ${color};border-radius:10px;background:#ffffff;padding:16px">
            <div style="font-size:11px;font-weight:700;letter-spacing:.08em;color:${color};margin-bottom:6px">${label} · SMARTPLUS</div>
            <div style="font-size:16px;line-height:24px;font-weight:700;color:#0f172a;margin-bottom:6px">${escapeHtml(suggestion.title)}</div>
            <div style="font-size:14px;line-height:21px;color:#475569">${escapeHtml(suggestion.message)}</div>
          </div>
        </td>
      </tr>`;
  }).join('');
  const html = `
    <!doctype html>
    <html lang="en"><body style="margin:0;padding:0;background:#f1f5f9">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f1f5f9;padding:32px 16px;font-family:Inter,Arial,sans-serif">
        <tr><td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(15,23,42,.08)">
            <tr><td style="background:linear-gradient(135deg,#312e81,#4f46e5);padding:28px 32px;color:#ffffff">
              <div style="font-size:12px;font-weight:700;letter-spacing:.1em;opacity:.8">SMART MONITORING SYSTEM</div>
              <div style="font-size:26px;line-height:34px;font-weight:800;margin-top:8px">SmartPlus needs your review</div>
              <div style="font-size:14px;line-height:21px;opacity:.9;margin-top:8px">${escapeHtml(businessName)}</div>
            </td></tr>
            <tr><td style="padding:28px 32px 12px">
              <p style="margin:0 0 20px;font-size:15px;line-height:23px;color:#334155">SmartPlus found ${suggestions.length} important ${suggestions.length === 1 ? 'item' : 'items'} in your current business records. Review the details below before taking action.</p>
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">${items}</table>
              <div style="margin:8px 0 20px;padding:14px 16px;border-radius:10px;background:#eef2ff;color:#3730a3;font-size:13px;line-height:20px"><strong>Owner review required.</strong> SmartPlus never changes stock, orders, prices, discounts, or sales automatically.</div>
            </td></tr>
            <tr><td style="padding:20px 32px 28px;background:#f8fafc;border-top:1px solid #e2e8f0;color:#64748b;font-size:12px;line-height:18px">You received this because SmartPlus email notifications are enabled for your owner account. You can change this in SmartPlus notification preferences.</td></tr>
          </table>
        </td></tr>
      </table>
    </body></html>`;
  return { text: textLines.join('\n'), html };
}

function actionCompletionEmailContent({ businessName, action }) {
  const title = String(action?.title || 'SmartPlus task');
  const completedAt = action?.executedAt
    ? new Date(action.executedAt).toLocaleString('en-PH', {
      timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short',
    })
    : 'just now';
  const result = String(
    action?.resultMessage ||
      'The owner completed the guided follow-up. SmartPlus did not change business records automatically.',
  );
  const text = [
    `SmartPlus task completed for ${businessName}`,
    '',
    `Task: ${title}`,
    `Completed: ${completedAt}`,
    '',
    result,
    '',
    'Open Smart Monitoring System to review the related records or the SmartPlus Action review center.',
  ].join('\n');
  const html = `
    <!doctype html>
    <html lang="en"><body style="margin:0;padding:0;background:#f1f5f9">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f1f5f9;padding:32px 16px;font-family:Inter,Arial,sans-serif">
        <tr><td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 24px rgba(15,23,42,.08)">
            <tr><td style="background:linear-gradient(135deg,#166534,#16a34a);padding:28px 32px;color:#ffffff">
              <div style="font-size:12px;font-weight:700;letter-spacing:.1em;opacity:.86">SMART MONITORING SYSTEM</div>
              <div style="font-size:26px;line-height:34px;font-weight:800;margin-top:8px">Task completed</div>
              <div style="font-size:14px;line-height:21px;opacity:.92;margin-top:8px">${escapeHtml(businessName)}</div>
            </td></tr>
            <tr><td style="padding:28px 32px">
              <div style="display:inline-block;padding:6px 10px;border-radius:999px;background:#dcfce7;color:#166534;font-size:12px;font-weight:800;letter-spacing:.04em">COMPLETED</div>
              <h1 style="margin:16px 0 8px;font-size:20px;line-height:28px;color:#0f172a">${escapeHtml(title)}</h1>
              <p style="margin:0 0 20px;font-size:14px;line-height:21px;color:#64748b">Completed by the business owner on ${escapeHtml(completedAt)}.</p>
              <div style="border:1px solid #bbf7d0;border-radius:12px;background:#f0fdf4;padding:16px;font-size:14px;line-height:21px;color:#166534">${escapeHtml(result)}</div>
              <p style="margin:20px 0 0;font-size:13px;line-height:20px;color:#475569">SmartPlus records completion only. It does not automatically change stock, supplier orders, prices, sales, discounts, or payments.</p>
            </td></tr>
            <tr><td style="padding:20px 32px 28px;background:#f8fafc;border-top:1px solid #e2e8f0;color:#64748b;font-size:12px;line-height:18px">You received this because SmartPlus email notifications are enabled for your owner account. You can change this in SmartPlus notification preferences.</td></tr>
          </table>
        </td></tr>
      </table>
    </body></html>`;
  return { text, html };
}

/// Sends a single professional acknowledgement after a backend-recorded,
/// owner-completed SmartPlus task. The recipient and tenant scope are always
/// loaded from MySQL; no client can choose where this email is sent.
async function dispatchOwnerActionCompletion(businessId, action, dependencies = {}) {
  if (!OWNER_EMAIL_ENABLED) return { skipped: 'disabled' };
  if (!action?.id) return { skipped: 'missing_action' };

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
    `SELECT email_enabled
       FROM smartplus_notification_preferences
      WHERE business_id = ? LIMIT 1`,
    [businessId],
  ).catch(() => []);
  if (Number(preferenceRows[0]?.email_enabled ?? 1) !== 1) {
    return { skipped: 'email_disabled_by_owner' };
  }

  const notificationKey = `action-completed-${String(action.id).slice(0, 120)}`;
  const insert = await dbExecute(
    `INSERT IGNORE INTO smartplus_email_deliveries
      (id, business_id, notification_key, owner_email, status)
      VALUES (?, ?, ?, ?, 'pending')`,
    [randomUUID(), business.id, notificationKey, business.owner_email],
  );
  const result = Array.isArray(insert) ? insert[0] : insert;
  if (Number(result?.affectedRows || 0) !== 1) return { skipped: 'already_sent' };

  try {
    const content = actionCompletionEmailContent({
      businessName: String(business.name || 'your business'),
      action,
    });
    const providerMessageId = await emailSender({
      to: business.owner_email,
      subject: `SmartPlus task completed: ${String(action.title || 'Task')}`,
      ...content,
    });
    await dbExecute(
      `UPDATE smartplus_email_deliveries
          SET status = 'sent', provider_message_id = ?, sent_at = CURRENT_TIMESTAMP, error_message = NULL
        WHERE business_id = ? AND notification_key = ?`,
      [providerMessageId, business.id, notificationKey],
    );
    return { sent: true };
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

/**
 * Sends one combined email when a new or materially changed important
 * SmartPlus condition is found. The owner email and tenant scope always come
 * from the database; this service never accepts either from a Flutter client.
 */
async function dispatchOwnerAlert(businessId, dependencies = {}) {
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
              minimum_severity, quiet_hours_start, quiet_hours_end
       FROM smartplus_notification_preferences
      WHERE business_id = ? LIMIT 1`,
    [businessId],
  ).catch(() => []);
  const preferences = preferenceRows[0] || {};
  if (Number(preferences.email_enabled ?? 1) !== 1) {
    return { skipped: 'email_disabled_by_owner' };
  }
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
              CASE WHEN EXISTS (
                SELECT 1 FROM purchase_order_items line
                 WHERE line.business_id = po.business_id AND line.order_id = po.id
              ) AND NOT EXISTS (
                SELECT 1 FROM purchase_order_items line
                 WHERE line.business_id = po.business_id AND line.order_id = po.id
                   AND (line.quantity <= 0 OR line.received_quantity < line.quantity
                     OR COALESCE((SELECT SUM(stock.quantity) FROM restock_records stock
                       WHERE stock.business_id = po.business_id
                         AND stock.product_id = line.product_id
                         AND LOWER(stock.referenced_by) = LOWER(CONCAT('Purchase Order ', po.order_number))), 0)
                       < (SELECT SUM(same_product.received_quantity) FROM purchase_order_items same_product
                         WHERE same_product.business_id = po.business_id AND same_product.order_id = po.id
                           AND same_product.product_id = line.product_id))
              ) THEN 1 ELSE 0 END AS fully_restocked,
              DATEDIFF(CURDATE(), DATE(po.expected_delivery)) AS overdue_days,
              DATEDIFF(CURDATE(), DATE(po.order_date)) AS pending_days
         FROM purchase_orders po
         LEFT JOIN suppliers s ON s.id = po.supplier_id AND s.business_id = po.business_id
         LEFT JOIN purchase_order_items poi ON poi.order_id = po.id AND poi.business_id = po.business_id
         LEFT JOIN products p ON p.id = poi.product_id AND p.business_id = po.business_id
         LEFT JOIN restock_records rr ON rr.business_id = po.business_id
           AND CAST(rr.product_id AS CHAR) = CAST(poi.product_id AS CHAR)
           AND LOWER(rr.referenced_by) LIKE CONCAT('%', LOWER(po.order_number), '%')
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
    ).catch((error) => {
      console.error('SmartPlus supplier delivery query failed:', error.message);
      return [];
    }),
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
  const importantSuggestions = suggestions.filter((suggestion) =>
    severityRank(suggestion.level) >= severityRank('warning'));
  if (!importantSuggestions.length) return { skipped: 'no_important_suggestions' };
  const emailSuggestions = isQuietHour(preferences)
    ? importantSuggestions.filter((suggestion) => suggestion.level === 'critical')
    : importantSuggestions;
  if (!emailSuggestions.length) return { skipped: 'quiet_hours' };

  // A stable fingerprint suppresses duplicate sends from repeated syncs, but
  // a changed alert set produces a fresh, combined owner email immediately.
  const fingerprint = createHash('sha256')
    .update(JSON.stringify(emailSuggestions.map(({ level, title, message }) => ({ level, title, message }))))
    .digest('hex')
    .slice(0, 40);
  const notificationKey = `owner-alert-${fingerprint}`;
  // Reserve the notification before contacting Resend. The unique key makes
  // concurrent device syncs unable to send duplicate owner messages.
  const insert = await dbExecute(
    `INSERT IGNORE INTO smartplus_email_deliveries
      (id, business_id, notification_key, owner_email, status)
      VALUES (?, ?, ?, ?, 'pending')`,
    [randomUUID(), business.id, notificationKey, business.owner_email],
  );
  const result = Array.isArray(insert) ? insert[0] : insert;
  if (Number(result?.affectedRows || 0) !== 1) return { skipped: 'already_sent' };

  try {
    const content = emailContent({
      businessName: String(business.name || 'your business'),
      suggestions: emailSuggestions,
    });
    const providerMessageId = await emailSender({
      to: business.owner_email,
      subject: `SmartPlus alert: ${emailSuggestions[0].title}`,
      ...content,
    });
    await dbExecute(
      `UPDATE smartplus_email_deliveries
          SET status = 'sent', provider_message_id = ?, sent_at = CURRENT_TIMESTAMP, error_message = NULL
        WHERE business_id = ? AND notification_key = ?`,
      [providerMessageId, business.id, notificationKey],
    );
    return { sent: true, suggestionCount: emailSuggestions.length };
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
/// business remains protected by its alert fingerprint in dispatchOwnerAlert.
async function dispatchScheduledOwnerAlerts(dependencies = {}) {
  if (!OWNER_EMAIL_ENABLED) return { skipped: 'disabled' };
  const dbQuery = dependencies.query || query;
  const businesses = await dbQuery(
    'SELECT id FROM businesses WHERE is_active = 1',
  );
  const results = await Promise.allSettled(
    businesses.map((business) => dispatchOwnerAlert(business.id, dependencies)),
  );
  return {
    processed: businesses.length,
    failed: results.filter((result) => result.status === 'rejected').length,
  };
}

module.exports = {
  dispatchOwnerAlert,
  emailContent,
  manilaDate,
  manilaHour,
  isQuietHour,
  normalizeSuggestions,
  supplierDeliverySuggestions,
  actionCompletionEmailContent,
  dispatchOwnerActionCompletion,
  dispatchScheduledOwnerAlerts,
  // Backward-compatible aliases for callers deployed before alert delivery
  // replaced the daily/weekly digest behavior.
  dispatchOwnerDigest: dispatchOwnerAlert,
  dispatchScheduledOwnerDigests: dispatchScheduledOwnerAlerts,
};
