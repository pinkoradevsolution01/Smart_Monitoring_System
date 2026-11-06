const express = require('express');
const { createHash } = require('crypto');
const { query } = require('../db');
const { tokenFromRequest, verifySession } = require('../security/session_tokens');
const { activeEntitlementForOwner } = require('../security/business_access');
const { currentOwnerSuggestions } = require('../services/smartplus_owner_notifications');

const router = express.Router();
const BUSINESS_ROLES = new Set(['owner', 'admin', 'manager']);
const MAX_RANGE_DAYS = 3653;
const MAX_PAGE_SIZE = 100;
function tenantScopeFromToken(auth) { return auth?.businessId || null; }

function dateRange(req, res, next) {
  const today = new Date().toISOString().slice(0, 10);
  const to = String(req.query.to || today);
  const from = String(req.query.from || new Date(Date.now() - 29 * 86400000).toISOString().slice(0, 10));
  if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) return res.status(400).json({ success: false, message: 'from and to must be ISO dates.' });
  const days = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000;
  if (days < 0 || days > MAX_RANGE_DAYS) return res.status(400).json({ success: false, message: `Date range must be between 0 and ${MAX_RANGE_DAYS} days.` });
  req.analyticsRange = { from, to, toExclusive: new Date(Date.parse(`${to}T00:00:00Z`) + 86400000).toISOString().slice(0, 10) };
  next();
}

async function requireBusinessAnalytics(req, res, next) {
  const token = tokenFromRequest(req);
  if (!token) return res.status(401).json({ success: false, message: 'Missing authorization token.' });
  try {
    const auth = verifySession(token);
    const businessId = tenantScopeFromToken(auth);
    if (!businessId || !BUSINESS_ROLES.has(String(auth.role || '').toLowerCase())) return res.status(403).json({ success: false, message: 'Analytics access is not permitted.' });
    const rows = await query(`SELECT u.id, u.role AS user_role, u.is_active AS user_active, b.id, b.name, b.owner_email, b.is_active AS business_active
      FROM users u INNER JOIN businesses b ON b.id = u.business_id WHERE u.id = ? AND u.business_id = ? LIMIT 1`, [auth.userId, businessId]);
    const user = rows[0];
    const databaseRole = String(user?.user_role || '').toLowerCase();
    if (!user || (user.user_active ?? 1) !== 1 || (user.business_active ?? 1) !== 1) return res.status(403).json({ success: false, message: 'The account or business is inactive.' });
    if (!BUSINESS_ROLES.has(databaseRole) || databaseRole !== String(auth.role || '').toLowerCase()) return res.status(403).json({ success: false, message: 'Analytics access is not permitted.' });
    if (!await activeEntitlementForOwner(user.owner_email)) {
      return res.status(403).json({ success: false, code: 'subscription_inactive', message: 'This business subscription is inactive, cancelled, revoked, or expired.' });
    }
    req.analytics = { businessId, businessName: user.name, userId: auth.userId, role: databaseRole };
    next();
  } catch (_) { return res.status(401).json({ success: false, message: 'Invalid or expired token.' }); }
}

function meta(req) { return { businessId: req.analytics.businessId, from: req.analyticsRange.from, to: req.analyticsRange.to, timezone: 'Asia/Manila', generatedAt: new Date().toISOString() }; }
function percentageChange(current, previous) {
  const currentValue = Number(current || 0);
  const previousValue = Number(previous || 0);
  if (!Number.isFinite(currentValue) || !Number.isFinite(previousValue)) return null;
  if (previousValue === 0) return currentValue === 0 ? 0 : null;
  return Number((((currentValue - previousValue) / Math.abs(previousValue)) * 100).toFixed(1));
}
function priorRange(from, to) {
  const dayMs = 86400000;
  const fromMs = Date.parse(`${from}T00:00:00Z`);
  const toMs = Date.parse(`${to}T00:00:00Z`);
  const periodDays = Math.round((toMs - fromMs) / dayMs) + 1;
  return {
    from: new Date(fromMs - periodDays * dayMs).toISOString().slice(0, 10),
    toExclusive: from,
  };
}
function activityIcon(eventType, severity) {
  if (severity === 'error') return '⚠';
  if (eventType === 'sync_success') return '↻';
  if (eventType === 'sale_completed') return '↗';
  if (eventType === 'inventory_low') return '□';
  return '•';
}
function page(req) { const value = Math.max(1, Number.parseInt(req.query.page, 10) || 1); const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, Number.parseInt(req.query.pageSize, 10) || 25)); return { value, pageSize, offset: (value - 1) * pageSize }; }
function sendCsv(res, filename, headers, rows) {
  // Excel and similar spreadsheet programs evaluate cells beginning with one
  // of these characters as formulas. Prefix them to keep exports as data.
  const escape = (value) => {
    const text = String(value ?? '');
    const safeText = /^[=+\-@]/.test(text) ? `'${text}` : text;
    return `"${safeText.replace(/"/g, '""')}"`;
  };
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${filename}.csv"`);
  res.send([headers, ...rows.map((row) => row.map(escape).join(','))].join('\n'));
}

router.get('/developer/subscriptions', dateRange, async (req, res) => {
  const token = tokenFromRequest(req);
  try {
    const auth = token && verifySession(token);
    if (!auth || String(auth.role).toLowerCase() !== 'developer') return res.status(403).json({ success: false, message: 'Developer access is required.' });
    const subscriptions = await query(`SELECT package_name, status, COUNT(*) count FROM subscriptions WHERE activated_at >= ? AND activated_at < ? GROUP BY package_name, status ORDER BY package_name, status`, [req.analyticsRange.from, req.analyticsRange.toExclusive]);
    const upcomingExpirations = await query(`SELECT package_name, device_name, expires_at, status FROM subscriptions WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at >= NOW() AND expires_at < DATE_ADD(NOW(), INTERVAL 30 DAY) ORDER BY expires_at ASC LIMIT 100`);
    return res.json({ success: true, data: { subscriptions, upcomingExpirations }, meta: { from: req.analyticsRange.from, to: req.analyticsRange.to, timezone: 'Asia/Manila', generatedAt: new Date().toISOString() } });
  } catch (_) { return res.status(401).json({ success: false, message: 'Invalid or expired token.' }); }
});

router.use(requireBusinessAnalytics, dateRange);

router.get('/overview', async (req, res) => {
  const { businessId } = req.analytics;
  const { from, to, toExclusive } = req.analyticsRange;
  const previous = priorRange(from, to);
  try {
    const [kpi] = await query(`SELECT COALESCE(SUM(subtotal),0) grossSales, COALESCE(SUM(discount),0) discounts, COALESCE(SUM(total_amount),0) netSales, COUNT(*) transactions, COALESCE(SUM(total_amount) / NULLIF(COUNT(*), 0), 0) averageOrderValue, COALESCE(SUM(item_count),0) itemsSold FROM sales WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ?`, [businessId, from, toExclusive]);
    const [previousKpi] = await query(`SELECT COALESCE(SUM(subtotal),0) grossSales, COALESCE(SUM(discount),0) discounts, COALESCE(SUM(total_amount),0) netSales, COUNT(*) transactions, COALESCE(SUM(total_amount) / NULLIF(COUNT(*), 0), 0) averageOrderValue, COALESCE(SUM(item_count),0) itemsSold FROM sales WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ?`, [businessId, previous.from, previous.toExclusive]);
    const [customers] = await query(`SELECT COUNT(*) activeCustomers FROM customers WHERE business_id = ? AND is_active = 1`, [businessId]);
    const [low] = await query(`SELECT COUNT(*) lowStockCount FROM products WHERE business_id = ? AND quantity > 0 AND quantity <= low_stock_threshold`, [businessId]);
    const salesSeries = await query(`SELECT DATE(datetime) date, COALESCE(SUM(subtotal),0) gross, COALESCE(SUM(total_amount),0) net, COUNT(*) orders FROM sales WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ? GROUP BY DATE(datetime) ORDER BY date`, [businessId, from, toExclusive]);
    const payments = await query(`SELECT payment_method name, COALESCE(SUM(total_amount),0) value FROM sales WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ? GROUP BY payment_method ORDER BY value DESC`, [businessId, from, toExclusive]);
    const topProducts = await query(`SELECT si.product_name name, SUM(si.quantity) sold, SUM(si.subtotal) revenue FROM sale_items si INNER JOIN sales s ON s.id = si.sale_id AND s.business_id = si.business_id WHERE s.business_id = ? AND s.status = 'completed' AND s.datetime >= ? AND s.datetime < ? GROUP BY si.product_id, si.product_name ORDER BY sold DESC, revenue DESC LIMIT 10`, [businessId, from, toExclusive]);
    const lowStock = await query(`SELECT name, quantity, low_stock_threshold threshold, CASE WHEN quantity <= 0 THEN 'Out of stock' ELSE 'Low' END status FROM products WHERE business_id = ? AND quantity <= low_stock_threshold ORDER BY quantity ASC LIMIT 10`, [businessId]);
    const [syncHealth] = await query(`SELECT MAX(CASE WHEN event_type = 'sync_success' THEN created_at END) lastSuccessfulSync, MAX(CASE WHEN event_type = 'sync_failed' THEN created_at END) lastFailedSync FROM operational_events WHERE business_id = ?`, [businessId]);
    const events = await query(`SELECT event_type, severity, message, created_at FROM operational_events WHERE business_id = ? ORDER BY created_at DESC LIMIT 6`, [businessId]);
    res.json({
      success: true,
      data: {
        kpis: { ...kpi, activeCustomers: customers.activeCustomers, lowStockCount: low.lowStockCount },
        comparisons: {
          previousPeriod: { from: previous.from, to: new Date(Date.parse(`${from}T00:00:00Z`) - 86400000).toISOString().slice(0, 10) },
          netSales: percentageChange(kpi.netSales, previousKpi.netSales),
          transactions: percentageChange(kpi.transactions, previousKpi.transactions),
          averageOrderValue: percentageChange(kpi.averageOrderValue, previousKpi.averageOrderValue),
        },
        dataHealth: {
          lastSuccessfulSync: syncHealth?.lastSuccessfulSync || null,
          lastFailedSync: syncHealth?.lastFailedSync || null,
          status: syncHealth?.lastSuccessfulSync ? 'synced' : 'awaiting_sync',
        },
        salesSeries,
        payments,
        topProducts,
        lowStock,
        recentActivity: events.map((event) => ({
          type: event.event_type,
          title: event.message,
          time: event.created_at,
          icon: activityIcon(event.event_type, event.severity),
          severity: event.severity,
        })),
      },
      meta: { ...meta(req), businessName: req.analytics.businessName },
    });
  } catch (error) { console.error('Analytics overview error:', error); res.status(500).json({ success: false, message: 'Failed to build analytics overview.' }); }
});

router.get('/sales', async (req, res) => {
  const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; const { value, pageSize, offset } = page(req);
  try { const [total] = await query(`SELECT COUNT(*) total FROM sales WHERE business_id = ? AND datetime >= ? AND datetime < ?`, [businessId, from, toExclusive]); const rows = await query(`SELECT id, cashier_name, payment_method, status, subtotal, discount, total_amount, item_count, datetime, transaction_type, delivery_status FROM sales WHERE business_id = ? AND datetime >= ? AND datetime < ? ORDER BY datetime DESC LIMIT ${pageSize} OFFSET ${offset}`, [businessId, from, toExclusive]); res.json({ success: true, data: rows, pagination: { page: value, pageSize, total: total.total }, meta: meta(req) }); } catch (error) { console.error('Analytics sales error:', error); res.status(500).json({ success: false, message: 'Failed to load sales analytics.' }); }
});

router.get('/inventory', async (req, res) => { const { businessId } = req.analytics; const status = String(req.query.status || 'all'); const allowed = new Set(['all', 'low', 'out']); if (!allowed.has(status)) return res.status(400).json({ success: false, message: 'Invalid inventory status.' }); const clause = status === 'low' ? 'AND quantity > 0 AND quantity <= low_stock_threshold' : status === 'out' ? 'AND quantity <= 0' : ''; try { const products = await query(`SELECT id, barcode, name, category, buying_price, selling_price, quantity, low_stock_threshold, updated_at FROM products WHERE business_id = ? ${clause} ORDER BY quantity ASC, name ASC`, [businessId]); const [value] = await query(`SELECT SUM(quantity * buying_price) costValue, SUM(quantity * selling_price) retailValue, SUM(buying_price IS NULL) missingCostCount FROM products WHERE business_id = ?`, [businessId]); res.json({ success: true, data: { products, value }, meta: meta(req) }); } catch (error) { console.error('Analytics inventory error:', error); res.status(500).json({ success: false, message: 'Failed to load inventory analytics.' }); } });

router.get('/customers', async (req, res) => { const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; const { value, pageSize, offset } = page(req); try { const [total] = await query(`SELECT COUNT(*) total FROM customers WHERE business_id = ?`, [businessId]); const [summary] = await query(`SELECT COUNT(*) activeCustomers, SUM(created_at >= ? AND created_at < ?) newCustomers FROM customers WHERE business_id = ? AND is_active = 1`, [from, toExclusive, businessId]); const rows = await query(`SELECT id, customer_code, full_name, phone_number, email, address, points_balance, lifetime_points, created_at, is_active FROM customers WHERE business_id = ? ORDER BY created_at DESC LIMIT ${pageSize} OFFSET ${offset}`, [businessId]); res.json({ success: true, data: { summary, customers: rows }, pagination: { page: value, pageSize, total: total.total }, meta: meta(req) }); } catch (error) { console.error('Analytics customers error:', error); res.status(500).json({ success: false, message: 'Failed to load customer analytics.' }); } });

router.get('/suppliers', async (req, res) => {
  const { businessId } = req.analytics;
  const { from, toExclusive } = req.analyticsRange;
  try {
    const [summary] = await query(
      `SELECT
         COUNT(*) totalSuppliers,
         COALESCE(SUM(is_active = 1), 0) activeSuppliers
       FROM suppliers WHERE business_id = ?`,
      [businessId],
    );
    const [orderSummary] = await query(
      `SELECT
         COUNT(*) purchaseOrders,
         COALESCE(SUM(status NOT IN ('received', 'cancelled')), 0) openPurchaseOrders,
         COALESCE(SUM(total_amount), 0) totalOrdered
       FROM purchase_orders
       WHERE business_id = ? AND order_date >= ? AND order_date < ?`,
      [businessId, from, toExclusive],
    );
    const suppliers = await query(
      `SELECT
         s.id, s.name, s.contact_person, s.email, s.phone, s.address, s.is_active, s.created_at,
         COUNT(po.id) purchase_order_count,
         COALESCE(SUM(po.total_amount), 0) total_ordered,
         COALESCE(SUM(po.status NOT IN ('received', 'cancelled')), 0) open_order_count,
         MAX(po.order_date) last_order_date,
         (
           SELECT latest_po.status
           FROM purchase_orders latest_po
           WHERE latest_po.business_id = s.business_id
             AND latest_po.supplier_id = s.id
             AND latest_po.order_date >= ? AND latest_po.order_date < ?
           ORDER BY latest_po.order_date DESC, latest_po.created_at DESC
           LIMIT 1
         ) delivery_status,
         (
           SELECT latest_po.expected_delivery
           FROM purchase_orders latest_po
           WHERE latest_po.business_id = s.business_id
             AND latest_po.supplier_id = s.id
             AND latest_po.order_date >= ? AND latest_po.order_date < ?
           ORDER BY latest_po.order_date DESC, latest_po.created_at DESC
           LIMIT 1
         ) expected_delivery
       FROM suppliers s
       LEFT JOIN purchase_orders po
         ON po.supplier_id = s.id
        AND po.business_id = s.business_id
        AND po.order_date >= ? AND po.order_date < ?
       WHERE s.business_id = ?
       GROUP BY s.id, s.name, s.contact_person, s.email, s.phone, s.address, s.is_active, s.created_at
       ORDER BY s.is_active DESC, last_order_date DESC, s.name ASC`,
      [from, toExclusive, from, toExclusive, from, toExclusive, businessId],
    );
    return res.json({ success: true, data: { summary: { ...summary, ...orderSummary }, suppliers }, meta: meta(req) });
  } catch (error) {
    console.error('Analytics suppliers error:', error);
    return res.status(500).json({ success: false, message: 'Failed to load supplier analytics.' });
  }
});

// SmartPlus is intentionally owner-only in Smart Monitoring. Analytics mirrors
// the live, tenant-scoped operational suggestions; it never exposes the Action
// Review Center workflow or lets Analytics approve, dismiss, or execute work.
router.get('/notifications', async (req, res) => {
  if (req.analytics.role !== 'owner') {
    return res.json({ success: true, data: { notifications: [], unreadCount: 0 }, meta: meta(req) });
  }
  try {
    const { suggestions } = await currentOwnerSuggestions(req.analytics.businessId);
    const generatedAt = new Date().toISOString();
    const notifications = suggestions.map((suggestion) => ({
      id: `smartplus-live-${createHash('sha256')
        .update(`${suggestion.level}|${suggestion.title}|${suggestion.message}`)
        .digest('hex')
        .slice(0, 24)}`,
      source: 'SmartPlus',
      actionType: 'operational_suggestion',
      title: suggestion.title,
      message: suggestion.message,
      level: suggestion.level,
      status: 'active',
      createdAt: generatedAt,
      updatedAt: generatedAt,
    }));
    return res.json({
      success: true,
      data: {
        notifications,
        unreadCount: notifications.length,
      },
      meta: meta(req),
    });
  } catch (error) {
    console.error('Analytics SmartPlus notification error:', error);
    return res.status(500).json({ success: false, message: 'Failed to load SmartPlus notifications.' });
  }
});

router.get('/operations', async (req, res) => {
  const { businessId } = req.analytics;
  const { from, toExclusive } = req.analyticsRange;
  try {
    const [attendance] = await query(`SELECT COUNT(*) entries FROM attendance_entries WHERE business_id = ? AND time >= ? AND time < ?`, [businessId, from, toExclusive]);
    const attendanceEntries = await query(`SELECT a.id, a.user_id, u.full_name AS user_name, a.time, a.type FROM attendance_entries a LEFT JOIN users u ON u.id = a.user_id AND u.business_id = a.business_id WHERE a.business_id = ? AND a.time >= ? AND a.time < ? ORDER BY a.time DESC LIMIT 100`, [businessId, from, toExclusive]);
    const purchaseOrders = await query(`SELECT id, order_number, order_date, status, total_amount, notes, created_by FROM purchase_orders WHERE business_id = ? AND order_date >= ? AND order_date < ? ORDER BY order_date DESC LIMIT 100`, [businessId, from, toExclusive]);
    const inventoryMovements = await query('SELECT id, product_name, movement_type, quantity, reference, notes, performed_by, `timestamp` FROM inventory_movements WHERE business_id = ? AND `timestamp` >= ? AND `timestamp` < ? ORDER BY `timestamp` DESC LIMIT 100', [businessId, from, toExclusive]);
    const damageReports = await query(`SELECT id, product_name, quantity, damage_type, description, reported_by, reported_at, status, resolution_notes FROM damage_reports WHERE business_id = ? AND reported_at >= ? AND reported_at < ? ORDER BY reported_at DESC LIMIT 100`, [businessId, from, toExclusive]);
    res.json({ success: true, data: { attendance, attendanceEntries, purchaseOrders, inventoryMovements, damageReports }, meta: meta(req) });
  } catch (error) {
    console.error('Analytics operations error:', error);
    res.status(500).json({ success: false, message: 'Failed to load operations analytics.' });
  }
});

router.get('/cctv-events', async (req, res) => { const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; const { value, pageSize, offset } = page(req); try { const [total] = await query(`SELECT COUNT(*) total FROM cctv_timestamps WHERE business_id = ? AND \`timestamp\` >= ? AND \`timestamp\` < ?`, [businessId, from, toExclusive]); const rows = await query(`SELECT t.id, t.camera_id, c.name AS camera_name, c.location AS camera_location, t.label, t.description, t.\`timestamp\`, t.created_by FROM cctv_timestamps t INNER JOIN cameras c ON c.id = t.camera_id AND c.business_id = t.business_id WHERE t.business_id = ? AND t.\`timestamp\` >= ? AND t.\`timestamp\` < ? ORDER BY t.\`timestamp\` DESC LIMIT ${pageSize} OFFSET ${offset}`, [businessId, from, toExclusive]); res.json({ success: true, data: rows, pagination: { page: value, pageSize, total: total.total }, meta: meta(req) }); } catch (error) { console.error('Analytics CCTV error:', error); res.status(500).json({ success: false, message: 'Failed to load CCTV events.' }); } });

router.get('/export', async (req, res) => {
  const report = String(req.query.report || 'overview');
  const supportedReports = new Set(['overview', 'sales', 'inventory', 'customers', 'suppliers', 'operations', 'cctv-events']);
  if (!supportedReports.has(report)) {
    return res.status(400).json({ success: false, message: 'Invalid export report.' });
  }

  const { businessId } = req.analytics;
  const { from, to, toExclusive } = req.analyticsRange;
  try {
    if (report === 'overview') {
      const [summary] = await query(
        `SELECT COALESCE(SUM(total_amount), 0) net_sales, COUNT(*) completed_transactions,
          COALESCE(SUM(item_count), 0) items_sold
         FROM sales
         WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ?`,
        [businessId, from, toExclusive],
      );
      return sendCsv(res, `overview-${from}-to-${to}`,
        ['Business', 'From', 'To', 'Net sales', 'Completed transactions', 'Items sold'],
        [[req.analytics.businessName, from, to, summary.net_sales, summary.completed_transactions, summary.items_sold]]);
    }

    if (report === 'sales') {
      const rows = await query(
        `SELECT id, datetime, cashier_name, payment_method, status, subtotal, discount, total_amount
         FROM sales WHERE business_id = ? AND datetime >= ? AND datetime < ? ORDER BY datetime DESC`,
        [businessId, from, toExclusive],
      );
      return sendCsv(res, `sales-${from}-to-${to}`,
        ['ID', 'Datetime', 'Cashier', 'Payment', 'Status', 'Subtotal', 'Discount', 'Total'], rows.map(Object.values));
    }

    if (report === 'inventory') {
      const rows = await query(
        `SELECT name, category, quantity, low_stock_threshold, buying_price, selling_price
         FROM products WHERE business_id = ? ORDER BY name`,
        [businessId],
      );
      return sendCsv(res, `inventory-${from}-to-${to}`,
        ['Product', 'Category', 'Quantity', 'Threshold', 'Cost', 'Retail'], rows.map(Object.values));
    }

    if (report === 'customers') {
      const rows = await query(
        `SELECT customer_code, points_balance, lifetime_points, created_at, is_active
         FROM customers WHERE business_id = ? ORDER BY created_at DESC`,
        [businessId],
      );
      return sendCsv(res, `customers-${from}-to-${to}`,
        ['Customer', 'Points balance', 'Lifetime points', 'Created at', 'Active'], rows.map(Object.values));
    }

    if (report === 'suppliers') {
      const rows = await query(
        `SELECT s.name, s.contact_person, s.email, s.phone, s.is_active,
          COUNT(po.id) purchase_orders, COALESCE(SUM(po.total_amount), 0) total_ordered,
          MAX(po.order_date) last_order_date
         FROM suppliers s
         LEFT JOIN purchase_orders po
           ON po.supplier_id = s.id AND po.business_id = s.business_id
          AND po.order_date >= ? AND po.order_date < ?
         WHERE s.business_id = ?
         GROUP BY s.id, s.name, s.contact_person, s.email, s.phone, s.is_active
         ORDER BY s.name`,
        [from, toExclusive, businessId],
      );
      return sendCsv(res, `suppliers-${from}-to-${to}`,
        ['Supplier', 'Contact person', 'Email', 'Phone', 'Active', 'Purchase orders', 'Total ordered', 'Last order date'], rows.map(Object.values));
    }

    if (report === 'cctv-events') {
      const rows = await query(
        `SELECT c.name, c.location, t.label, t.description, t.\`timestamp\`, t.created_by
         FROM cctv_timestamps t INNER JOIN cameras c ON c.id = t.camera_id AND c.business_id = t.business_id
         WHERE t.business_id = ? AND t.\`timestamp\` >= ? AND t.\`timestamp\` < ? ORDER BY t.\`timestamp\` DESC`,
        [businessId, from, toExclusive],
      );
      return sendCsv(res, `cctv-events-${from}-to-${to}`,
        ['Camera', 'Location', 'Event', 'Description', 'Timestamp', 'Created by'], rows.map(Object.values));
    }

    const rows = await query(
      `SELECT 'Attendance' AS record_type, user_id AS reference, time AS occurred_at, type AS details, '' AS status
       FROM attendance_entries WHERE business_id = ? AND time >= ? AND time < ?
       UNION ALL
       SELECT 'Purchase order', order_number, order_date, COALESCE(notes, ''), status
       FROM purchase_orders WHERE business_id = ? AND order_date >= ? AND order_date < ?
       UNION ALL
       SELECT 'Damage report', product_name, reported_at, COALESCE(description, ''), status
       FROM damage_reports WHERE business_id = ? AND reported_at >= ? AND reported_at < ?
       ORDER BY occurred_at DESC`,
      [businessId, from, toExclusive, businessId, from, toExclusive, businessId, from, toExclusive],
    );
    return sendCsv(res, `operations-${from}-to-${to}`,
      ['Type', 'Reference', 'Occurred at', 'Details', 'Status'], rows.map(Object.values));
  } catch (error) {
    console.error('Analytics export error:', error);
    return res.status(500).json({ success: false, message: 'Failed to export analytics report.' });
  }
});

module.exports = router;
module.exports.__test = { tenantScopeFromToken, BUSINESS_ROLES };
