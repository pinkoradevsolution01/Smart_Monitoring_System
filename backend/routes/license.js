const express = require('express');
const { query } = require('../db');
const router = express.Router();

router.post('/activate', async (req, res) => {
  const { code, deviceId, deviceName, packageName } = req.body;
  if (!code || !deviceId || !deviceName) {
    return res.status(400).json({
      success: false,
      message: 'Activation code, deviceId, and deviceName are required.',
    });
  }

  try {
    const rows = await query(
      'SELECT code, package_name, status FROM activation_codes WHERE code = ?',
      [code],
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Activation code not found.' });
    }

    const codeRow = rows[0];
    if (codeRow.status === 'used') {
      return res.status(400).json({ success: false, message: 'This activation code has already been used.' });
    }
    if (codeRow.status === 'revoked') {
      return res.status(400).json({ success: false, message: 'This activation code has been revoked.' });
    }

    await query(
      'UPDATE activation_codes SET status = ?, device_id = ?, device_name = ?, used_at = NOW() WHERE code = ?',
      ['used', deviceId, deviceName, code],
    );

    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 19).replace('T', ' ');
    await query(
      'INSERT INTO subscriptions (device_id, activation_code, package_name, device_name, activated_at, expires_at, status, created_at) VALUES (?, ?, ?, ?, NOW(), ?, ?, NOW())',
      [deviceId, code, packageName || codeRow.package_name || 'Standard', deviceName, expiresAt, 'active'],
    );

    return res.json({
      success: true,
      message: 'Activation successful.',
      packageName: packageName ?? codeRow.package_name,
      expiresAt,
    });
  } catch (error) {
    console.error('License activate error:', error);
    return res.status(500).json({ success: false, message: 'Failed to activate license.' });
  }
});

router.get('/code/:code', async (req, res) => {
  const { code } = req.params;
  try {
    const rows = await query('SELECT code, package_name, status, device_id, device_name, used_at FROM activation_codes WHERE code = ?', [code]);
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Activation code not found.' });
    }
    return res.json({ success: true, code: rows[0] });
  } catch (error) {
    console.error('License code lookup error:', error);
    return res.status(500).json({ success: false, message: 'Failed to lookup activation code.' });
  }
});

module.exports = router;
