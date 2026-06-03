const express = require('express');
const { query } = require('../db');
const router = express.Router();

router.post('/init', async (req, res) => {
  const { businessName, ownerEmail, existingBusinessId } = req.body;
  if (!businessName || !ownerEmail) {
    return res.status(400).json({ success: false, message: 'Business name and owner email are required.' });
  }

  try {
    if (existingBusinessId) {
      const existing = await query('SELECT id FROM businesses WHERE id = ?', [existingBusinessId]);
      if (existing.length) {
        return res.json({ success: true, businessId: existingBusinessId });
      }
      return res.status(404).json({ success: false, message: 'Existing business ID not found.' });
    }

    const existing = await query('SELECT id FROM businesses WHERE owner_email = ?', [ownerEmail]);
    if (existing.length) {
      return res.json({ success: true, businessId: existing[0].id });
    }

    const businessId = `b-${Date.now()}-${Math.random().toString(36).substring(2, 8)}`;
    await query(
      'INSERT INTO businesses (id, name, owner_email, owner_id, is_active, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
      [businessId, businessName, ownerEmail, `owner-${Date.now()}`, 1],
    );

    return res.json({ success: true, businessId });
  } catch (error) {
    console.error('Business init error:', error);
    return res.status(500).json({ success: false, message: 'Failed to initialize business.' });
  }
});

module.exports = router;
