const express = require('express');
const crypto = require('crypto');
const { query, execute } = require('../db');
const { requireActiveBusiness } = require('../security/business_access');

const router = express.Router();
const FIELDS = [
  'in_app_enabled',
  'email_enabled',
  'low_stock_enabled',
  'sales_enabled',
  'discount_enabled',
  'forecast_enabled',
  'supplier_delivery_enabled',
];
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

function preferencesFromRow(row = {}) {
  return Object.fromEntries(FIELDS.map((field) => [field, Number(row[field] ?? 1) === 1]));
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

router.use(requireActiveBusiness, requireOwner);

router.get('/preferences', async (req, res) => {
  try {
    const [row] = await query(
      `SELECT ${FIELDS.join(', ')}
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
  try {
    await execute(
      `INSERT INTO smartplus_notification_preferences
        (business_id, ${FIELDS.join(', ')})
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         ${FIELDS.map((field) => `${field} = VALUES(${field})`).join(', ')}`,
      [req.businessContext.businessId, ...values],
    );
    return res.json({ success: true, preferences: preferencesFromRow(input) });
  } catch (error) {
    console.error('SmartPlus preference write error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to save SmartPlus notification preferences.' });
  }
});

router.get('/actions', async (req, res) => {
  try {
    const rows = await query(
      `SELECT * FROM smartplus_action_drafts
        WHERE business_id = ? ORDER BY created_at DESC LIMIT 100`,
      [req.businessContext.businessId],
    );
    return res.json({ success: true, actions: rows.map(actionFromRow) });
  } catch (error) {
    console.error('SmartPlus action list error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to load SmartPlus action drafts.' });
  }
});

router.post('/actions', requireCurrentSubscription, async (req, res) => {
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
    const recheck = await recheckActionData(action, req.businessContext.businessId);
    if (!recheck.ok) return res.status(409).json({ success: false, message: recheck.message });
    const result = `${recheck.message} No sale, cart, discount, payment, stock, price, or supplier record was changed automatically.`;
    await execute(
      `UPDATE smartplus_action_drafts
          SET status = 'executed', executed_at = NOW(), result_message = ?
        WHERE id = ? AND business_id = ? AND status = 'approved'`,
      [result, action.id, req.businessContext.businessId],
    );
    await auditAction({ actionId: action.id, businessId: req.businessContext.businessId, actorId: req.businessContext.userId, eventType: 'owner_executed_manual_handoff', details: { recheck: recheck.message } });
    return res.json({ success: true, message: result, action: actionFromRow(await loadTenantAction(action.id, req.businessContext.businessId)) });
  } catch (error) {
    console.error('SmartPlus action execution error:', error.message);
    return res.status(500).json({ success: false, message: 'Unable to execute SmartPlus action.' });
  }
});

module.exports = router;
