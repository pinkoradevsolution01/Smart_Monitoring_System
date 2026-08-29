const express = require('express');
const jwt = require('jsonwebtoken');
const { query } = require('../db');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret';
const BUSINESS_ROLES = new Set(['owner', 'admin', 'manager']);
const MAX_RANGE_DAYS = 366;
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
  const token = String(req.headers.authorization || '').match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return res.status(401).json({ success: false, message: 'Missing authorization token.' });
  try {
    const auth = jwt.verify(token, JWT_SECRET);
    const businessId = tenantScopeFromToken(auth);
    if (!businessId || !BUSINESS_ROLES.has(String(auth.role || '').toLowerCase())) return res.status(403).json({ success: false, message: 'Analytics access is not permitted.' });
    const rows = await query(`SELECT u.id, u.is_active AS user_active, b.id, b.name, b.is_active AS business_active
      FROM users u INNER JOIN businesses b ON b.id = u.business_id WHERE u.id = ? AND u.business_id = ? LIMIT 1`, [auth.userId, businessId]);
    if (!rows.length || (rows[0].user_active ?? 1) !== 1 || (rows[0].business_active ?? 1) !== 1) return res.status(403).json({ success: false, message: 'The account or business is inactive.' });
    req.analytics = { businessId, businessName: rows[0].name, userId: auth.userId, role: auth.role };
    next();
  } catch (_) { return res.status(401).json({ success: false, message: 'Invalid or expired token.' }); }
}

function meta(req) { return { businessId: req.analytics.businessId, from: req.analyticsRange.from, to: req.analyticsRange.to, timezone: 'Asia/Manila', generatedAt: new Date().toISOString() }; }
function page(req) { const value = Math.max(1, Number.parseInt(req.query.page, 10) || 1); const pageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, Number.parseInt(req.query.pageSize, 10) || 25)); return { value, pageSize, offset: (value - 1) * pageSize }; }
function sendCsv(res, filename, headers, rows) { const escape = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`; res.setHeader('Content-Type', 'text/csv; charset=utf-8'); res.setHeader('Content-Disposition', `attachment; filename="${filename}.csv"`); res.send([headers, ...rows.map((row) => row.map(escape).join(','))].join('\n')); }

router.get('/developer/subscriptions', dateRange, async (req, res) => {
  const token = String(req.headers.authorization || '').match(/^Bearer\s+(.+)$/i)?.[1];
  try {
    const auth = token && jwt.verify(token, JWT_SECRET);
    if (!auth || String(auth.role).toLowerCase() !== 'developer') return res.status(403).json({ success: false, message: 'Developer access is required.' });
    const subscriptions = await query(`SELECT package_name, status, COUNT(*) count FROM subscriptions WHERE activated_at >= ? AND activated_at < ? GROUP BY package_name, status ORDER BY package_name, status`, [req.analyticsRange.from, req.analyticsRange.toExclusive]);
    const upcomingExpirations = await query(`SELECT package_name, device_name, expires_at, status FROM subscriptions WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at >= NOW() AND expires_at < DATE_ADD(NOW(), INTERVAL 30 DAY) ORDER BY expires_at ASC LIMIT 100`);
    return res.json({ success: true, data: { subscriptions, upcomingExpirations }, meta: { from: req.analyticsRange.from, to: req.analyticsRange.to, timezone: 'Asia/Manila', generatedAt: new Date().toISOString() } });
  } catch (_) { return res.status(401).json({ success: false, message: 'Invalid or expired token.' }); }
});

router.get('/developer/subscriptions', dateRange, async (req, res) => {
  const token = String(req.headers.authorization || '').match(/^Bearer\s+(.+)$/i)?.[1];
  try {
    const auth = token && jwt.verify(token, JWT_SECRET);
    if (!auth || String(auth.role).toLowerCase() !== 'developer') return res.status(403).json({ success: false, message: 'Developer access is required.' });
    const subscriptions = await query(`SELECT package_name, status, COUNT(*) count FROM subscriptions WHERE activated_at >= ? AND activated_at < ? GROUP BY package_name, status ORDER BY package_name, status`, [req.analyticsRange.from, req.analyticsRange.toExclusive]);
    const upcomingExpirations = await query(`SELECT package_name, device_name, expires_at, status FROM subscriptions WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at >= NOW() AND expires_at < DATE_ADD(NOW(), INTERVAL 30 DAY) ORDER BY expires_at ASC LIMIT 100`);
    return res.json({ success: true, data: { subscriptions, upcomingExpirations }, meta: { from: req.analyticsRange.from, to: req.analyticsRange.to, timezone: 'Asia/Manila', generatedAt: new Date().toISOString() } });
  } catch (_) { return res.status(401).json({ success: false, message: 'Invalid or expired token.' }); }
});

router.use(requireBusinessAnalytics, dateRange);

router.get('/overview', async (req, res) => {
  const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange;
  try {
    const [kpi] = await query(`SELECT COALESCE(SUM(subtotal),0) grossSales, COALESCE(SUM(discount),0) discounts, COALESCE(SUM(total_amount),0) netSales, COUNT(*) transactions, COALESCE(SUM(total_amount) / NULLIF(COUNT(*), 0), 0) averageOrderValue, COALESCE(SUM(item_count),0) itemsSold FROM sales WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ?`, [businessId, from, toExclusive]);
    const [customers] = await query(`SELECT COUNT(*) activeCustomers FROM customers WHERE business_id = ? AND is_active = 1`, [businessId]);
    const [low] = await query(`SELECT COUNT(*) lowStockCount FROM products WHERE business_id = ? AND quantity > 0 AND quantity <= low_stock_threshold`, [businessId]);
    const salesSeries = await query(`SELECT DATE(datetime) date, COALESCE(SUM(subtotal),0) gross, COALESCE(SUM(total_amount),0) net, COUNT(*) orders FROM sales WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ? GROUP BY DATE(datetime) ORDER BY date`, [businessId, from, toExclusive]);
    const payments = await query(`SELECT payment_method name, COALESCE(SUM(total_amount),0) value FROM sales WHERE business_id = ? AND status = 'completed' AND datetime >= ? AND datetime < ? GROUP BY payment_method ORDER BY value DESC`, [businessId, from, toExclusive]);
    const topProducts = await query(`SELECT si.product_name name, SUM(si.quantity) sold, SUM(si.subtotal) revenue FROM sale_items si INNER JOIN sales s ON s.id = si.sale_id AND s.business_id = si.business_id WHERE s.business_id = ? AND s.status = 'completed' AND s.datetime >= ? AND s.datetime < ? GROUP BY si.product_id, si.product_name ORDER BY sold DESC, revenue DESC LIMIT 10`, [businessId, from, toExclusive]);
    const lowStock = await query(`SELECT name, quantity, low_stock_threshold threshold, CASE WHEN quantity <= 0 THEN 'Out of stock' ELSE 'Low' END status FROM products WHERE business_id = ? AND quantity <= low_stock_threshold ORDER BY quantity ASC LIMIT 10`, [businessId]);
    res.json({ success: true, data: { kpis: { ...kpi, activeCustomers: customers.activeCustomers, lowStockCount: low.lowStockCount }, salesSeries, payments, topProducts, lowStock, recentActivity: [] }, meta: { ...meta(req), businessName: req.analytics.businessName } });
  } catch (error) { console.error('Analytics overview error:', error); res.status(500).json({ success: false, message: 'Failed to build analytics overview.' }); }
});

router.get('/sales', async (req, res) => {
  const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; const { value, pageSize, offset } = page(req);
  try { const [total] = await query(`SELECT COUNT(*) total FROM sales WHERE business_id = ? AND datetime >= ? AND datetime < ?`, [businessId, from, toExclusive]); const rows = await query(`SELECT id, cashier_name, payment_method, status, subtotal, discount, total_amount, item_count, datetime, transaction_type, delivery_status FROM sales WHERE business_id = ? AND datetime >= ? AND datetime < ? ORDER BY datetime DESC LIMIT ${pageSize} OFFSET ${offset}`, [businessId, from, toExclusive]); res.json({ success: true, data: rows, pagination: { page: value, pageSize, total: total.total }, meta: meta(req) }); } catch (error) { console.error('Analytics sales error:', error); res.status(500).json({ success: false, message: 'Failed to load sales analytics.' }); }
});

router.get('/inventory', async (req, res) => { const { businessId } = req.analytics; const status = String(req.query.status || 'all'); const allowed = new Set(['all', 'low', 'out']); if (!allowed.has(status)) return res.status(400).json({ success: false, message: 'Invalid inventory status.' }); const clause = status === 'low' ? 'AND quantity > 0 AND quantity <= low_stock_threshold' : status === 'out' ? 'AND quantity <= 0' : ''; try { const products = await query(`SELECT id, barcode, name, category, buying_price, selling_price, quantity, low_stock_threshold, updated_at FROM products WHERE business_id = ? ${clause} ORDER BY quantity ASC, name ASC`, [businessId]); const [value] = await query(`SELECT SUM(quantity * buying_price) costValue, SUM(quantity * selling_price) retailValue, SUM(buying_price IS NULL) missingCostCount FROM products WHERE business_id = ?`, [businessId]); res.json({ success: true, data: { products, value }, meta: meta(req) }); } catch (error) { console.error('Analytics inventory error:', error); res.status(500).json({ success: false, message: 'Failed to load inventory analytics.' }); } });

router.get('/customers', async (req, res) => { const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; const { value, pageSize, offset } = page(req); try { const [total] = await query(`SELECT COUNT(*) total FROM customers WHERE business_id = ?`, [businessId]); const [summary] = await query(`SELECT COUNT(*) activeCustomers, SUM(created_at >= ? AND created_at < ?) newCustomers FROM customers WHERE business_id = ? AND is_active = 1`, [from, toExclusive, businessId]); const rows = await query(`SELECT id, customer_code, points_balance, lifetime_points, created_at, is_active FROM customers WHERE business_id = ? ORDER BY created_at DESC LIMIT ${pageSize} OFFSET ${offset}`, [businessId]); res.json({ success: true, data: { summary, customers: rows }, pagination: { page: value, pageSize, total: total.total }, meta: meta(req) }); } catch (error) { console.error('Analytics customers error:', error); res.status(500).json({ success: false, message: 'Failed to load customer analytics.' }); } });

router.get('/operations', async (req, res) => { const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; try { const [attendance] = await query(`SELECT COUNT(*) entries FROM attendance_entries WHERE business_id = ? AND time >= ? AND time < ?`, [businessId, from, toExclusive]); const purchaseOrders = await query(`SELECT order_number, order_date, status, total_amount FROM purchase_orders WHERE business_id = ? AND order_date >= ? AND order_date < ? ORDER BY order_date DESC LIMIT 50`, [businessId, from, toExclusive]); const damageReports = await query(`SELECT product_name, quantity, damage_type, status, reported_at FROM damage_reports WHERE business_id = ? AND reported_at >= ? AND reported_at < ? ORDER BY reported_at DESC LIMIT 50`, [businessId, from, toExclusive]); res.json({ success: true, data: { attendance, purchaseOrders, damageReports }, meta: meta(req) }); } catch (error) { console.error('Analytics operations error:', error); res.status(500).json({ success: false, message: 'Failed to load operations analytics.' }); } });

router.get('/cctv-events', async (req, res) => { const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; const { value, pageSize, offset } = page(req); try { const [total] = await query(`SELECT COUNT(*) total FROM cctv_timestamps WHERE business_id = ? AND \`timestamp\` >= ? AND \`timestamp\` < ?`, [businessId, from, toExclusive]); const rows = await query(`SELECT t.id, t.camera_id, c.name AS camera_name, c.location AS camera_location, t.label, t.description, t.\`timestamp\`, t.created_by FROM cctv_timestamps t INNER JOIN cameras c ON c.id = t.camera_id AND c.business_id = t.business_id WHERE t.business_id = ? AND t.\`timestamp\` >= ? AND t.\`timestamp\` < ? ORDER BY t.\`timestamp\` DESC LIMIT ${pageSize} OFFSET ${offset}`, [businessId, from, toExclusive]); res.json({ success: true, data: rows, pagination: { page: value, pageSize, total: total.total }, meta: meta(req) }); } catch (error) { console.error('Analytics CCTV error:', error); res.status(500).json({ success: false, message: 'Failed to load CCTV events.' }); } });

router.get('/export', async (req, res) => { const report = String(req.query.report || ''); if (!['sales', 'inventory', 'customers', 'operations'].includes(report)) return res.status(400).json({ success: false, message: 'Invalid export report.' }); const { businessId } = req.analytics; const { from, toExclusive } = req.analyticsRange; try { if (report === 'sales') { const rows = await query(`SELECT id, datetime, cashier_name, payment_method, status, subtotal, discount, total_amount FROM sales WHERE business_id = ? AND datetime >= ? AND datetime < ? ORDER BY datetime DESC`, [businessId, from, toExclusive]); return sendCsv(res, `sales-${from}-to-${req.analyticsRange.to}`, ['ID','Datetime','Cashier','Payment','Status','Subtotal','Discount','Total'], rows.map(Object.values)); } if (report === 'inventory') { const rows = await query(`SELECT name, category, quantity, low_stock_threshold, buying_price, selling_price FROM products WHERE business_id = ? ORDER BY name`, [businessId]); return sendCsv(res, `inventory-${from}-to-${req.analyticsRange.to}`, ['Product','Category','Quantity','Threshold','Cost','Retail'], rows.map(Object.values)); } const rows = await query(`SELECT customer_code, points_balance, lifetime_points, created_at, is_active FROM customers WHERE business_id = ? ORDER BY created_at DESC`, [businessId]); return sendCsv(res, `customers-${from}-to-${req.analyticsRange.to}`, ['Customer','Points balance','Lifetime points','Created at','Active'], rows.map(Object.values)); } catch (error) { console.error('Analytics export error:', error); res.status(500).json({ success: false, message: 'Failed to export analytics report.' }); } });

module.exports = router;
module.exports.__test = { tenantScopeFromToken, BUSINESS_ROLES };
