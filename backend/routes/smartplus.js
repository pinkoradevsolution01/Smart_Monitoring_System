const express = require('express');
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
];

function requireOwner(req, res, next) {
  if (req.businessContext?.role !== 'owner') {
    return res.status(403).json({ success: false, message: 'Only the business owner can change SmartPlus notification preferences.' });
  }
  return next();
}

function preferencesFromRow(row = {}) {
  return Object.fromEntries(FIELDS.map((field) => [field, Number(row[field] ?? 1) === 1]));
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

module.exports = router;
