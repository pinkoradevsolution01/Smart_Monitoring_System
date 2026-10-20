const express = require('express');
const crypto = require('crypto');
const { query, execute } = require('../db');
const { requireActiveBusiness } = require('../security/business_access');
const { dispatchOwnerActionCompletion } = require('../services/smartplus_owner_notifications');

const router = express.Router();
const FIELDS = [
  'in_app_enabled',
  'email_enabled',
  'low_stock_enabled',
  'sales_enabled',
  'discount_enabled',
  'forecast_enabled',
  'supplier_delivery_enabled',
  'customer_loyalty_enabled',
];
const SETTING_FIELDS = [
  'minimum_severity',
  'quiet_hours_start',
  'quiet_hours_end',
];
const SEVERITIES = new Set(['info', 'warning', 'critical']);
const FEEDBACK_VERDICTS = new Set(['useful', 'ignored', 'inaccurate']);
const writeRateWindows = new Map();
const WRITE_RATE_WINDOW_MS = 5 * 60 * 1000;
const WRITE_RATE_LIMIT = 30;
const ACTION_TYPES = new Set([
  'reorder',
  'price_change_proposal',
  'supplier_message',
  'promotion',
  'staff_follow_up',
]);

function requireOwner(req, res, next) {
  if (req.businessContext?.role !== 'owner') {
    return res.status(403).json({ success: false, message: 'Only the business owner can change SmartPlus notification preferences.' });
  }
  return next();
}

// SmartPlus accepts only structured, allow-listed input. This small
// per-owner/server-process limit protects review and feedback routes from
// rapid scripted writes without using a client-supplied identity.
function limitOwnerWrites(req, res, next) {
  const key = `${req.businessContext?.businessId || ''}:${req.businessContext?.userId || ''}`;
  const now = Date.now();
  const recent = (writeRateWindows.get(key) || []).filter((time) => now - time < WRITE_RATE_WINDOW_MS);
  if (recent.length >= WRITE_RATE_LIMIT) {
    console.warn(JSON.stringify({ event: 'smartplus_rate_limited', businessId: req.businessContext?.businessId, userId: req.businessContext?.userId, timestamp: new Date().toISOString() }));
    return res.status(429).json({ success: false, message: 'Too many SmartPlus write requests. Please wait a few minutes and try again.' });
  }
  recent.push(now);
  writeRateWindows.set(key, recent);
  return next();
}

function preferencesFromRow(row = {}) {
  return {
    ...Object.fromEntries(FIELDS.map((field) => [field, Number(row[field] ?? 1) === 1])),
    minimum_severity: SEVERITIES.has(row.minimum_severity) ? row.minimum_severity : 'info',
    quiet_hours_start: row.quiet_hours_start != null && Number.isInteger(Number(row.quiet_hours_start)) && Number(row.quiet_hours_start) >= 0 && Number(row.quiet_hours_start) <= 23 ? Number(row.quiet_hours_start) : null,
    quiet_hours_end: row.quiet_hours_end != null && Number.isInteger(Number(row.quiet_hours_end)) && Number(row.quiet_hours_end) >= 0 && Number(row.quiet_hours_end) <= 23 ? Number(row.quiet_hours_end) : null,
  };
}

function parseJson(value, fallback = {}) {
  if (value && typeof value === 'object') return value;
  try { return JSON.parse(value || '{}'); } catch (_) { return fallback; }
}

function actionFromRow(row) {
  return {
    id: row.id,
    actionType: row.action_type,
    title: row.title,
    proposal: parseJson(row.proposal_json),
    evidence: parseJson(row.evidence_json),
    status: row.status,
    createdBy: row.created_by,
    approvedBy: row.approved_by,
    approvedAt: row.approved_at,
    executedAt: row.executed_at,
    resultMessage: row.result_message,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function requireCurrentSubscription(req, res, next) {
  const expiry = req.businessContext?.subscriptionExpiresAt;
  if (expiry && new Date(expiry).getTime() < Date.now()) {
    return res.status(403).json({ success: false, message: 'Your business subscription is expired. Renew it before approving a SmartPlus action.' });
  }
  return next();
}

async function auditAction({ actionId, businessId, actorId, eventType, details = {} }) {
  await execute(
    `INSERT INTO smartplus_action_audit
      (action_id, business_id, actor_id, event_type, details_json)
     VALUES (?, ?, ?, ?, ?)`,
    [actionId, businessId, actorId, eventType, JSON.stringify(details)],
  );
}

async function loadTenantAction(id, businessId) {
  const rows = await query(
    `SELECT * FROM smartplus_action_drafts WHERE id = ? AND business_id = ? LIMIT 1`,
    [id, businessId],
  );
  return rows[0] || null;
}

async function recheckActionData(action, businessId) {
  const proposal = parseJson(action.proposal_json);
  if (action.action_type === 'reorder') {
    const productId = Number(proposal.productId);
    const quantity = Number(proposal.quantity);
    if (!Number.isInteger(productId) || !Number.isInteger(quantity) || quantity <= 0) {
      return { ok: false, message: 'The reorder proposal no longer has a valid product and quantity.' };
    }
    const [product] = await query(
      `SELECT id, name, quantity, low_stock_threshold
         FROM products WHERE business_id = ? AND id = ? LIMIT 1`,
      [businessId, productId],
    );
    if (!product) return { ok: false, message: 'The proposed product no longer exists for this business.' };
    if (Number(product.quantity) > Number(product.low_stock_threshold)) {
      return { ok: false, message: 'The product is no longer at its reorder level; review the current stock before proceeding.' };
    }
    return { ok: true, message: `Reorder rechecked for ${product.name}: current stock ${product.quantity}.` };
  }
  if (action.action_type === 'price_change_proposal' && proposal.productId != null) {
    const [product] = await query(
      `SELECT id FROM products WHERE business_id = ? AND id = ? LIMIT 1`,
      [businessId, Number(proposal.productId)],
    );
    if (!product) return { ok: false, message: 'The proposed product no longer exists for this business.' };
  }
  return { ok: true, message: 'Current tenant, owner session, subscription, and proposal data were rechecked.' };
}

async function recheckApprovedReorder(action, businessId) {
  return require('../services/smartplus_order_checks').checkApprovedReorder(
    query, businessId, action.id, Number(parseJson(action.proposal_json).productId),
  );
}

async function recheckReceivedDelivery(orderNumber, businessId) {
  return require('../services/smartplus_order_checks').checkReceivedDelivery(query, businessId, orderNumber);
}

router.use(requireActiveBusiness, requireOwner);

router.get('/preferences', async (req, res) => {
  try {
    const [row] = await query(
      `SELECT ${[...FIELDS, ...SETTING_FIELDS].join(', ')}
         FROM smartplus_notification_preferences
        WHERE business_id = ? LIMIT 1`,
      [req.businessContext.businessId],
    );
    return res.json({ success: true, preferences: preferencesFromRow(row) });
  } catch (error) {
    console.error('SmartPlus preference read error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load SmartPlus notification preferences.' });
  }
});

router.put('/preferences', async (req, res) => {
  const input = req.body || {};
  const values = [];
  for (const field of FIELDS) {
    if (typeof input[field] !== 'boolean') {
      return res.status(400).json({ success: false, message: `Preference ${field} must be true or false.` });
    }
    values.push(input[field] ? 1 : 0);
  }
  const minimumSeverity = String(input.minimum_severity || '').trim();
  const quietHoursStart = input.quiet_hours_start;
  const quietHoursEnd = input.quiet_hours_end;
  const validHour = (value) => value === null || (Number.isInteger(value) && value >= 0 && value <= 23);
  if (!SEVERITIES.has(minimumSeverity) ||
      !validHour(quietHoursStart) || !validHour(quietHoursEnd) ||
      ((quietHoursStart === null) !== (quietHoursEnd === null))) {
    return res.status(400).json({ success: false, message: 'Provide a valid severity and both quiet-hour values or neither.' });
  }
  try {
    await execute(
      `INSERT INTO smartplus_notification_preferences
        (business_id, ${[...FIELDS, ...SETTING_FIELDS].join(', ')})
       VALUES (${Array(FIELDS.length + SETTING_FIELDS.length + 1).fill('?').join(', ')})
       ON DUPLICATE KEY UPDATE
         ${[...FIELDS, ...SETTING_FIELDS].map((field) => `${field} = VALUES(${field})`).join(', ')}`,
      [req.businessContext.businessId, ...values, minimumSeverity, quietHoursStart, quietHoursEnd],
    );
    return res.json({ success: true, preferences: preferencesFromRow(input) });
  } catch (error) {
    console.error('SmartPlus preference write error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save SmartPlus notification preferences.' });
  }
});

router.post('/feedback', limitOwnerWrites, async (req, res) => {
  const notificationId = String(req.body?.notificationId || '').trim();
  const verdict = String(req.body?.verdict || '').trim();
  if (!notificationId || notificationId.length > 128 || !FEEDBACK_VERDICTS.has(verdict)) {
    return res.status(400).json({ success: false, message: 'Provide a valid SmartPlus notification and feedback verdict.' });
  }
  try {
    await execute(
      `INSERT INTO smartplus_feedback
        (id, business_id, notification_id, owner_id, verdict)
       VALUES (?, ?, ?, ?, ?)`,
      [crypto.randomUUID(), req.businessContext.businessId, notificationId, req.businessContext.userId, verdict],
    );
    return res.status(201).json({ success: true });
  } catch (error) {
    console.error('SmartPlus feedback write error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to record SmartPlus feedback.' });
  }
});

router.get('/actions', async (req, res) => {
  try {
    const rows = await query(
      `SELECT * FROM smartplus_action_drafts
        WHERE business_id = ? AND status <> 'rejected'
        ORDER BY created_at DESC LIMIT 100`,
      [req.businessContext.businessId],
    );
    return res.json({ success: true, actions: rows.map(actionFromRow) });
  } catch (error) {
    console.error('SmartPlus action list error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load SmartPlus action drafts.' });
  }
});

router.post('/actions', limitOwnerWrites, requireCurrentSubscription, async (req, res) => {
  const input = req.body || {};
  const actionType = String(input.actionType || '').trim();
  const title = String(input.title || '').trim();
  const proposal = input.proposal;
  const evidence = input.evidence;
  if (!ACTION_TYPES.has(actionType) || !title || title.length > 255 || !proposal || typeof proposal !== 'object' || !evidence || typeof evidence !== 'object') {
    return res.status(400).json({ success: false, message: 'Provide a supported action type, title, proposal, and evidence.' });
  }
  const proposalJson = JSON.stringify(proposal);
  const evidenceJson = JSON.stringify(evidence);
  if (proposalJson.length > 100000 || evidenceJson.length > 100000) {
    return res.status(400).json({ success: false, message: 'The SmartPlus action evidence is too large.' });
  }
  const id = crypto.randomUUID();
  try {
    await execute(
      `INSERT INTO smartplus_action_drafts
        (id, business_id, action_type, title, proposal_json, evidence_json, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, req.businessContext.businessId, actionType, title, proposalJson, evidenceJson, req.businessContext.userId],
    );
    await auditAction({
      actionId: id,
      businessId: req.businessContext.businessId,
      actorId: req.businessContext.userId,
      eventType: 'draft_created',
      details: { actionType, title, evidence },
    });
    const row = await loadTenantAction(id, req.businessContext.businessId);
    return res.status(201).json({ success: true, action: actionFromRow(row) });
  } catch (error) {
    console.error('SmartPlus action draft error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save SmartPlus action draft.' });
  }
});

router.get('/actions/:id/audit', async (req, res) => {
  try {
    const action = await loadTenantAction(req.params.id, req.businessContext.businessId);
    if (!action) return res.status(404).json({ success: false, message: 'SmartPlus action draft not found.' });
    const entries = await query(
      `SELECT event_type, details_json, created_at FROM smartplus_action_audit
        WHERE action_id = ? AND business_id = ? ORDER BY created_at ASC`,
      [action.id, req.businessContext.businessId],
    );
    return res.json({ success: true, audit: entries.map((entry) => ({ ...entry, details: parseJson(entry.details_json) })) });
  } catch (error) {
    console.error('SmartPlus action audit read error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load SmartPlus action audit trail.' });
  }
});

// Removing an item from the active queue is not a physical delete. Retaining
// it as rejected preserves the owner decision and audit trail, while avoiding
// any change to supplier orders, inventory, sales, prices, or payments.
router.post('/actions/:id/dismiss', limitOwnerWrites, async (req, res) => {
  try {
    const action = await loadTenantAction(
      req.params.id,
      req.businessContext.businessId,
    );
    if (!action) {
      return res.status(404).json({
        success: false,
        message: 'SmartPlus action draft not found.',
      });
    }

    const dismissibleStatuses = new Set(['draft', 'pending', 'approved']);
    if (!dismissibleStatuses.has(action.status)) {
      return res.status(409).json({
        success: false,
        message: 'Only an incomplete SmartPlus review can be removed.',
      });
    }

    const result =
      'Removed from the active Action Review Center by the owner. No business record was changed.';
    await execute(
      `UPDATE smartplus_action_drafts
          SET status = 'rejected', result_message = ?
        WHERE id = ? AND business_id = ?
          AND status IN ('draft', 'pending', 'approved')`,
      [result, action.id, req.businessContext.businessId],
    );
    await auditAction({
      actionId: action.id,
      businessId: req.businessContext.businessId,
      actorId: req.businessContext.userId,
      eventType: 'owner_dismissed',
      details: { previousStatus: action.status },
    });
    return res.json({
      success: true,
      message: result,
      action: actionFromRow(
        await loadTenantAction(action.id, req.businessContext.businessId),
      ),
    });
  } catch (error) {
    console.error('SmartPlus action dismissal error:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Unable to remove the SmartPlus action from review.',
    });
  }
});

router.post('/actions/:id/approve', requireCurrentSubscription, async (req, res) => {
  try {
    const action = await loadTenantAction(req.params.id, req.businessContext.businessId);
    if (!action) return res.status(404).json({ success: false, message: 'SmartPlus action draft not found.' });
    if (action.status !== 'draft') return res.status(409).json({ success: false, message: 'Only a draft action can be approved.' });
    const recheck = await recheckActionData(action, req.businessContext.businessId);
    if (!recheck.ok) return res.status(409).json({ success: false, message: recheck.message });
    await execute(
      `UPDATE smartplus_action_drafts
          SET status = 'approved', approved_by = ?, approved_at = NOW(), result_message = ?
        WHERE id = ? AND business_id = ? AND status = 'draft'`,
      [req.businessContext.userId, recheck.message, action.id, req.businessContext.businessId],
    );
    await auditAction({ actionId: action.id, businessId: req.businessContext.businessId, actorId: req.businessContext.userId, eventType: 'owner_approved', details: { recheck: recheck.message } });
    return res.json({ success: true, message: 'Action approved. SmartPlus has not changed business data.', action: actionFromRow(await loadTenantAction(action.id, req.businessContext.businessId)) });
  } catch (error) {
    console.error('SmartPlus action approval error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to approve SmartPlus action.' });
  }
});

router.post('/actions/:id/execute', requireCurrentSubscription, async (req, res) => {
  try {
    const action = await loadTenantAction(req.params.id, req.businessContext.businessId);
    if (!action) return res.status(404).json({ success: false, message: 'SmartPlus action draft not found.' });
    if (action.status !== 'approved') return res.status(409).json({ success: false, message: 'Only an owner-approved action can be executed.' });
    const receivingOrderNumber = parseJson(action.proposal_json).receivingOrderNumber;
    const recheck = receivingOrderNumber != null
      ? await recheckReceivedDelivery(receivingOrderNumber, req.businessContext.businessId)
      : action.action_type === 'reorder'
      ? await recheckApprovedReorder(action, req.businessContext.businessId)
      : await recheckActionData(action, req.businessContext.businessId);
    if (!recheck.ok) return res.status(409).json({ success: false, message: recheck.message });
    const result = `${recheck.message} The owner marked the guided follow-up complete. SmartPlus did not change any business record automatically.`;
    await execute(
      `UPDATE smartplus_action_drafts
          SET status = 'executed', executed_at = NOW(), result_message = ?
        WHERE id = ? AND business_id = ? AND status = 'approved'`,
      [result, action.id, req.businessContext.businessId],
    );
    await auditAction({ actionId: action.id, businessId: req.businessContext.businessId, actorId: req.businessContext.userId, eventType: 'owner_executed_manual_handoff', details: { recheck: recheck.message } });
    const completedAction = actionFromRow(
      await loadTenantAction(action.id, req.businessContext.businessId),
    );
    // Never let email delivery alter the completion result. The action is
    // already tenant-scoped, owner-authorized, and recorded before delivery.
    void dispatchOwnerActionCompletion(
      req.businessContext.businessId,
      completedAction,
    ).catch((emailError) => {
      console.error('SmartPlus action-completion email error:', emailError.message);
    });
    return res.json({ success: true, message: result, action: completedAction });
  } catch (error) {
    console.error('SmartPlus action execution error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to execute SmartPlus action.' });
  }
});

module.exports = router;
