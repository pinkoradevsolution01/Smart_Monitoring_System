const { createHash, randomUUID } = require('crypto');
const { query, execute } = require('../db');
const { escapeHtml, sendEmail } = require('./resend_email');

const OWNER_EMAIL_ENABLED = String(
  process.env.SMARTPLUS_OWNER_EMAIL_ENABLED || '',
).trim().toLowerCase() === 'true';

// A successful sync can be triggered by more than one signed-in device.  An
// alert evaluation is read-only, but running the same delivery analysis in
// parallel is wasteful and can monopolise the small production database.
// Coalesce concurrent requests for the same tenant into one evaluation.
const ownerAlertRuns = new Map();
const MAX_EMAIL_ATTEMPTS = Math.max(
  1,
  Math.min(12, Number(process.env.SMARTPLUS_EMAIL_MAX_ATTEMPTS || 8)),
);

/**
 * Reserve a delivery before contacting Resend. A sent delivery can never be
 * sent twice; a failed delivery becomes available again after its backoff.
 * The conditional update is atomic, so concurrent devices cannot both retry.
 */
async function reserveEmailDelivery({ dbExecute, businessId, notificationKey, ownerEmail }) {
  const inserted = await dbExecute(
    `INSERT IGNORE INTO smartplus_email_deliveries
      (id, business_id, notification_key, owner_email, status, attempt_count, last_attempt_at)
      VALUES (?, ?, ?, ?, 'pending', 1, NOW())`,
    [randomUUID(), businessId, notificationKey, ownerEmail],
  );
  const insertResult = Array.isArray(inserted) ? inserted[0] : inserted;
  if (Number(insertResult?.affectedRows || 0) === 1) return { reserved: true, retried: false };

  // Retry only a failed notification that is due. Backoff is set when the
  // previous attempt failed; sent and in-progress records remain untouched.
  const retried = await dbExecute(
    `UPDATE smartplus_email_deliveries
        SET status = 'pending',
            owner_email = ?,
            attempt_count = attempt_count + 1,
            last_attempt_at = NOW(),
            next_retry_at = NULL,
            error_message = NULL
      WHERE business_id = ?
        AND notification_key = ?
        AND status = 'failed'
        AND (next_retry_at IS NULL OR next_retry_at <= NOW())
        AND attempt_count < ?`,
    [ownerEmail, businessId, notificationKey, MAX_EMAIL_ATTEMPTS],
  );
  const retryResult = Array.isArray(retried) ? retried[0] : retried;
  return {
    reserved: Number(retryResult?.affectedRows || 0) === 1,
    retried: Number(retryResult?.affectedRows || 0) === 1,
  };
}

async function markEmailSent({ dbExecute, businessId, notificationKey, providerMessageId }) {
  await dbExecute(
    `UPDATE smartplus_email_deliveries
        SET status = 'sent', provider_message_id = ?, sent_at = CURRENT_TIMESTAMP,
            error_message = NULL, next_retry_at = NULL
      WHERE business_id = ? AND notification_key = ?`,
    [providerMessageId, businessId, notificationKey],
  );
}

async function markEmailFailed({ dbExecute, businessId, notificationKey, error }) {
  await dbExecute(
    `UPDATE smartplus_email_deliveries
        SET status = 'failed', error_message = ?,
            next_retry_at = DATE_ADD(
              NOW(),
              INTERVAL LEAST(360, 5 * POW(2, GREATEST(attempt_count - 1, 0))) MINUTE
            )
      WHERE business_id = ? AND notification_key = ?`,
    [String(error.message || error).slice(0, 1000), businessId, notificationKey],
  ).catch(() => undefined);
}

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

function calendarDaysBetween(fromDate, toDate) {
  const from = String(fromDate || '').slice(0, 10);
  const to = String(toDate || '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) {
    return 0;
  }
  return Math.floor((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000);
}

function hasOrderReference(reference, orderNumber) {
  const normalizedReference = String(reference || '').toLowerCase();
  const normalizedOrder = String(orderNumber || '').trim().toLowerCase();
  if (!normalizedReference || !normalizedOrder) return false;
  return new RegExp(
    `(^|[^a-z0-9])${normalizedOrder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?=$|[^a-z0-9])`,
  ).test(normalizedReference);
}

// Keep reference matching out of MySQL. The legacy reference is free text, so
// INSTR(LOWER(...)) forced a restock-table scan for every purchase-order item.
// We fetch the tenant's bounded records once and match them in memory instead.
function buildSupplierDeliveryRows(orderItems = [], restockRecords = [], now = new Date()) {
  const restocksByProduct = new Map();
  for (const restock of restockRecords) {
    const productId = String(restock.product_id ?? '');
    if (!productId) continue;
    const records = restocksByProduct.get(productId) || [];
    records.push({
      quantity: asNumber(restock.quantity),
      reference: String(restock.referenced_by || '').toLowerCase(),
      restockDate: String(restock.restock_date || '').slice(0, 10),
    });
    restocksByProduct.set(productId, records);
  }

  const today = manilaDate(now);
  const orders = new Map();
  for (const item of orderItems) {
    const orderId = String(item.order_id ?? item.order_number ?? '');
    if (!orderId) continue;
    const existing = orders.get(orderId) || {
      order_number: item.order_number,
      status: String(item.status || '').toLowerCase(),
      order_date: item.order_date,
      expected_delivery: item.expected_delivery,
      supplier_name: item.supplier_name,
      orderedItems: [],
      low_stock_count: 0,
      missing_inventory: 0,
      fully_restocked: 1,
      itemCount: 0,
      lineKeys: new Set(),
    };

    if (item.product_id != null) {
      const productId = String(item.product_id);
      const orderNumber = String(item.order_number || '').toLowerCase();
      const orderedQuantity = asNumber(item.quantity);
      const receivedQuantity = asNumber(item.received_quantity);
      // Legacy clients re-created local item IDs after each restore. Their
      // next sync produced an identical server line again. Treat an exact
      // duplicate as one order line so it cannot turn a completed delivery
      // into hundreds of false critical alerts.
      const lineKey = [
        productId,
        String(item.product_name || '').trim().toLowerCase(),
        orderedQuantity,
        receivedQuantity,
      ].join('|');
      if (existing.lineKeys.has(lineKey)) {
        orders.set(orderId, existing);
        continue;
      }
      existing.lineKeys.add(lineKey);

      const productRestocks = restocksByProduct.get(productId) || [];
      const exactRestockedQuantity = productRestocks
        .filter((restock) => hasOrderReference(restock.reference, orderNumber))
        .reduce((total, restock) => total + restock.quantity, 0);
      // Older completed deliveries were saved before the purchase-order
      // number was included in the restock reference. A later generic
      // “purchase order” restock for the same product is enough to prevent a
      // false critical email; newer records always use the exact match above.
      const legacyRestockedQuantity = exactRestockedQuantity > 0
        ? 0
        : productRestocks
          .filter((restock) =>
            /purchase\s+order/i.test(restock.reference) &&
            (!restock.restockDate || !item.order_date || restock.restockDate >= String(item.order_date).slice(0, 10)))
          .reduce((total, restock) => total + restock.quantity, 0);
      const restockedQuantity = Math.max(
        exactRestockedQuantity,
        legacyRestockedQuantity,
      );
      existing.itemCount += 1;
      existing.orderedItems.push(`${item.product_name || 'Unnamed product'} x${orderedQuantity}`);
      if (item.product_quantity != null &&
          asNumber(item.product_quantity) <= asNumber(item.low_stock_threshold)) {
        existing.low_stock_count += 1;
      }
      if (existing.status === 'received' && receivedQuantity > 0 && restockedQuantity < receivedQuantity) {
        existing.missing_inventory = 1;
      }
      if (orderedQuantity <= 0 || receivedQuantity < orderedQuantity || restockedQuantity < receivedQuantity) {
        existing.fully_restocked = 0;
      }
    }
    orders.set(orderId, existing);
  }

  return [...orders.values()].map((order) => ({
    order_number: order.order_number,
    status: order.status,
    order_date: order.order_date,
    expected_delivery: order.expected_delivery,
    supplier_name: order.supplier_name || 'Unassigned supplier',
    ordered_items: order.orderedItems.join(', ') || 'No line items recorded',
    low_stock_count: order.low_stock_count,
    missing_inventory: order.missing_inventory,
    fully_restocked: order.itemCount > 0 && order.fully_restocked === 1 ? 1 : 0,
    overdue_days: calendarDaysBetween(order.expected_delivery, today),
    pending_days: calendarDaysBetween(order.order_date, today),
  }));
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
    // Delivery email preferences are intentionally calm: due today, the
    // first overdue day, then every third overdue day. The rule may remain
    // visible in-app, but it must not produce a new email every day.
    if (overdueDays > 0 && overdueDays !== 1 && overdueDays % 3 !== 0) {
      return null;
    }
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
      // Due-today delivery reminders are owner-actionable. Marking this as a
      // warning makes it eligible for the existing preference-controlled,
      // deduplicated Resend owner email flow.
      level: 'warning',
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
  const completedAtValue = action?.executedAt || action?.executed_at;
  const completedAt = completedAtValue
    ? new Date(completedAtValue).toLocaleString('en-PH', {
      timeZone: 'Asia/Manila', dateStyle: 'medium', timeStyle: 'short',
    })
    : 'just now';
  const result = String(
    action?.resultMessage || action?.result_message ||
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
  const reservation = await reserveEmailDelivery({
    dbExecute,
    businessId: business.id,
    notificationKey,
    ownerEmail: business.owner_email,
  });
  if (!reservation.reserved) return { skipped: 'already_sent_or_retry_pending' };

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
    await markEmailSent({
      dbExecute, businessId: business.id, notificationKey, providerMessageId,
    });
    return { sent: true, retried: reservation.retried };
  } catch (error) {
    await markEmailFailed({ dbExecute, businessId: business.id, notificationKey, error });
    throw error;
  }
}

/**
 * Sends one combined email when a new or materially changed important
 * SmartPlus condition is found. The owner email and tenant scope always come
 * from the database; this service never accepts either from a Flutter client.
 */
async function evaluateOwnerAlert(businessId, dependencies = {}) {
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
  const [
    outOfStock,
    lowStock,
    discountRows,
    supplierDeliveryLines,
    restockRecords,
  ] = await Promise.all([
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
    // Return tenant-scoped order lines only. Restock reference matching is
    // intentionally performed once in JavaScript below: doing it as a
    // correlated INSTR subquery caused full restock-table scans per line.
    dbQuery(
      `SELECT po.id AS order_id, po.order_number, po.status, po.order_date,
              po.expected_delivery, COALESCE(s.name, 'Unassigned supplier') AS supplier_name,
              poi.product_id, poi.product_name, poi.quantity, poi.received_quantity,
              p.quantity AS product_quantity, p.low_stock_threshold
         FROM purchase_orders po
         LEFT JOIN suppliers s ON s.id = po.supplier_id AND s.business_id = po.business_id
         LEFT JOIN purchase_order_items poi ON poi.order_id = po.id AND poi.business_id = po.business_id
         LEFT JOIN products p ON p.id = poi.product_id AND p.business_id = po.business_id
        WHERE po.business_id = ?
          AND po.status <> 'cancelled'
          AND (
            po.status IN ('received', 'completed', 'partial')
            OR (po.status = 'pending' AND po.expected_delivery IS NULL
                AND po.order_date <= DATE_SUB(CURDATE(), INTERVAL 2 DAY))
            OR (po.expected_delivery IS NOT NULL AND po.expected_delivery <= CURDATE())
          )`,
      [businessId],
    ).catch((error) => {
      console.error('SmartPlus supplier delivery query failed:', error.message);
      return [];
    }),
    dbQuery(
      `SELECT product_id, quantity, referenced_by, restock_date
         FROM restock_records
        WHERE business_id = ?
          AND referenced_by IS NOT NULL
          AND referenced_by <> ''`,
      [businessId],
    ).catch((error) => {
      console.error('SmartPlus restock-reference query failed:', error.message);
      return [];
    }),
  ]);
  const supplierDelivery = buildSupplierDeliveryRows(
    supplierDeliveryLines,
    restockRecords,
  );
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
  const reservation = await reserveEmailDelivery({
    dbExecute,
    businessId: business.id,
    notificationKey,
    ownerEmail: business.owner_email,
  });
  if (!reservation.reserved) return { skipped: 'already_sent_or_retry_pending' };

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
    await markEmailSent({
      dbExecute, businessId: business.id, notificationKey, providerMessageId,
    });
    return { sent: true, retried: reservation.retried, suggestionCount: emailSuggestions.length };
  } catch (error) {
    await markEmailFailed({ dbExecute, businessId: business.id, notificationKey, error });
    throw error;
  }
}

function dispatchOwnerAlert(businessId, dependencies = {}) {
  const key = String(businessId || '').trim();
  if (!key) return Promise.resolve({ skipped: 'business_not_found' });
  const running = ownerAlertRuns.get(key);
  if (running) return running;

  const task = evaluateOwnerAlert(key, dependencies).finally(() => {
    if (ownerAlertRuns.get(key) === task) ownerAlertRuns.delete(key);
  });
  ownerAlertRuns.set(key, task);
  return task;
}

// Task-completion messages are normally dispatched as soon as an owner marks
// an Action Review Center task complete. If Resend is temporarily unavailable,
// the completed task is already safely stored; this scheduled retry delivers
// its acknowledgement later without asking the owner to repeat the task.
async function retryFailedActionCompletionEmails(dependencies = {}) {
  const dbQuery = dependencies.query || query;
  const failed = await dbQuery(
    `SELECT d.business_id, a.id, a.title, a.executed_at, a.result_message
       FROM smartplus_email_deliveries d
       INNER JOIN smartplus_action_drafts a
         ON a.business_id = d.business_id
        AND d.notification_key = CONCAT('action-completed-', LEFT(a.id, 120))
      WHERE d.status = 'failed'
        AND (d.next_retry_at IS NULL OR d.next_retry_at <= NOW())
        AND a.status = 'executed'
      ORDER BY d.updated_at ASC
      LIMIT 25`,
  ).catch(() => []);
  let retried = 0;
  let failedCount = 0;
  for (const action of failed) {
    try {
      const result = await dispatchOwnerActionCompletion(action.business_id, {
        id: action.id,
        title: action.title,
        executedAt: action.executed_at,
        resultMessage: action.result_message,
      }, dependencies);
      if (result.sent) retried += 1;
    } catch (error) {
      failedCount += 1;
      console.error('SmartPlus action-completion retry error:', error.message);
    }
  }
  return { retried, failed: failedCount };
}

/// Runs from the backend process as well as after sync. Each individual
/// business remains protected by its alert fingerprint in dispatchOwnerAlert.
async function dispatchScheduledOwnerAlerts(dependencies = {}) {
  if (!OWNER_EMAIL_ENABLED) return { skipped: 'disabled' };
  const dbQuery = dependencies.query || query;
  const completionRetries = await retryFailedActionCompletionEmails(dependencies);
  const businesses = await dbQuery(
    'SELECT id FROM businesses WHERE is_active = 1',
  );
  // Keep scheduled work deliberately sequential. A shared MySQL pool serves
  // real POS and sync requests first; starting one heavy delivery check per
  // business at the same instant can otherwise exhaust the entire pool.
  const results = [];
  for (const business of businesses) {
    try {
      results.push({ status: 'fulfilled', value: await dispatchOwnerAlert(business.id, dependencies) });
    } catch (error) {
      results.push({ status: 'rejected', reason: error });
    }
  }
  return {
    processed: businesses.length,
    retriedCompletions: completionRetries.retried,
    failed: completionRetries.failed + results.filter((result) => result.status === 'rejected').length,
  };
}

module.exports = {
  dispatchOwnerAlert,
  emailContent,
  manilaDate,
  manilaHour,
  isQuietHour,
  normalizeSuggestions,
  buildSupplierDeliveryRows,
  supplierDeliverySuggestions,
  actionCompletionEmailContent,
  dispatchOwnerActionCompletion,
  retryFailedActionCompletionEmails,
  dispatchScheduledOwnerAlerts,
  // Backward-compatible aliases for callers deployed before alert delivery
  // replaced the daily/weekly digest behavior.
  dispatchOwnerDigest: dispatchOwnerAlert,
  dispatchScheduledOwnerDigests: dispatchScheduledOwnerAlerts,
};
