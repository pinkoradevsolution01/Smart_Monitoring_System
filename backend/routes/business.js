const express = require('express');
const { query } = require('../db');
const router = express.Router();

router.post('/init', async (req, res) => {
  const { businessName, ownerEmail, ownerId, existingBusinessId } = req.body;
  if (!businessName || !ownerEmail) {
    return res.status(400).json({ success: false, message: 'Business name and owner email are required.' });
  }

  try {
    if (existingBusinessId) {
      const existing = await query('SELECT id, owner_id FROM businesses WHERE id = ?', [existingBusinessId]);
      if (existing.length) {
        if (ownerId && existing[0].owner_id !== ownerId) {
          await query(
            'UPDATE businesses SET owner_id = ?, name = ?, updated_at = NOW() WHERE id = ?',
            [ownerId, businessName, existingBusinessId],
          );
        }
        if (ownerId) {
          await query(
            'UPDATE users SET business_id = ? WHERE id = ?',
            [existingBusinessId, ownerId],
          );
        }
        return res.json({ success: true, businessId: existingBusinessId });
      }
      return res.status(404).json({ success: false, message: 'Existing business ID not found.' });
    }

    const existing = await query('SELECT id, owner_id FROM businesses WHERE owner_email = ?', [ownerEmail]);
    if (existing.length) {
      if (ownerId && existing[0].owner_id !== ownerId) {
        await query(
          'UPDATE businesses SET owner_id = ?, name = ?, updated_at = NOW() WHERE id = ?',
          [ownerId, businessName, existing[0].id],
        );
      }
      if (ownerId) {
        await query('UPDATE users SET business_id = ? WHERE id = ?', [existing[0].id, ownerId]);
      }
      return res.json({ success: true, businessId: existing[0].id });
    }

    const businessId = `b-${Date.now()}-${Math.random().toString(36).substring(2, 8)}`;
    await query(
      'INSERT INTO businesses (id, name, owner_email, owner_id, is_active, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
      [businessId, businessName, ownerEmail, ownerId || `owner-${Date.now()}`, 1],
    );

    if (ownerId) {
      await query('UPDATE users SET business_id = ? WHERE id = ?', [businessId, ownerId]);
    }

    return res.json({ success: true, businessId });
  } catch (error) {
    console.error('Business init error:', error);
    return res.status(500).json({ success: false, message: 'Failed to initialize business.' });
  }
});

module.exports = router;
