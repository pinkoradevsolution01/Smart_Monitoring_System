const express = require('express');
const { randomUUID } = require('crypto');
const { query } = require('../db');

const router = express.Router();

function toBool(value) {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function normalizeRows(rows) {
  return Array.isArray(rows) ? rows : [];
}

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

    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 19)
      .replace('T', ' ');

    await query(
      `INSERT INTO subscriptions
        (device_id, activation_code, package_name, device_name, activated_at, expires_at, status, created_at)
        VALUES (?, ?, ?, ?, NOW(), ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
          package_name = VALUES(package_name),
          device_name = VALUES(device_name),
          expires_at = VALUES(expires_at),
          status = VALUES(status)`,
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
    const rows = await query(
      'SELECT code, package_name, status, device_id, device_name, assigned_at, notes, used_at, created_at FROM activation_codes WHERE code = ?',
      [code],
    );
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Activation code not found.' });
    }
    return res.json({ success: true, code: rows[0] });
  } catch (error) {
    console.error('License code lookup error:', error);
    return res.status(500).json({ success: false, message: 'Failed to lookup activation code.' });
  }
});

router.get('/codes', async (req, res) => {
  const { status, packageName, includeSubscription } = req.query;
  try {
    const filters = [];
    const params = [];
    if (status) {
      filters.push('status = ?');
      params.push(status);
    }
    if (packageName) {
      filters.push('package_name = ?');
      params.push(packageName);
    }

    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const rows = await query(
      `SELECT code, package_name, status, device_id, device_name, assigned_at, notes, used_at, created_at
       FROM activation_codes ${where}
       ORDER BY created_at DESC`,
      params,
    );

    if (toBool(includeSubscription) && rows.length) {
      const codesList = rows.map((row) => row.code);
      const subscriptionRows = codesList.length
        ? await query(
            'SELECT activation_code, status AS subscription_status, expires_at, activated_at FROM subscriptions WHERE activation_code IN (?)',
            [codesList],
          )
        : [];
      const byCode = new Map(subscriptionRows.map((row) => [row.activation_code, row]));
      const merged = rows.map((row) => ({
        ...row,
        subscription: byCode.get(row.code) || null,
      }));
      return res.json({ success: true, codes: merged });
    }

    return res.json({ success: true, codes: rows });
  } catch (error) {
    console.error('License codes list error:', error);
    return res.status(500).json({ success: false, message: 'Failed to list activation codes.' });
  }
});

router.get('/codes/available', async (req, res) => {
  const { packageName } = req.query;
  try {
    const params = ['unused'];
    let sql =
      'SELECT code, package_name, status, created_at FROM activation_codes WHERE status = ?';
    if (packageName && packageName !== 'All') {
      sql += ' AND package_name = ?';
      params.push(packageName);
    }
    sql += ' ORDER BY created_at DESC';
    const rows = await query(sql, params);
    return res.json({ success: true, codes: rows });
  } catch (error) {
    console.error('License available codes error:', error);
    return res.status(500).json({ success: false, message: 'Failed to load available activation codes.' });
  }
});

// Bulk create activation codes (used by Developer Dashboard Code Generator)
async function bulkImportActivationCodes(req, res) {
  const body = req.body || {};
  const codes = Array.isArray(body.codes) ? body.codes : [];
  if (!codes.length) {
    return res.status(400).json({ success: false, message: 'No codes provided.' });
  }

  const { getConnection } = require('../db');

  let conn;
  try {
    conn = await getConnection();
    await conn.beginTransaction();

    let inserted = 0;
    let skipped = 0;

    for (const entry of codes) {
      const code = String(entry.code || '').trim();
      if (!code) {
        skipped += 1;
        continue;
      }

      const packageName = String(entry.package_name || 'Standard').trim() || 'Standard';
      const status = entry.status === 'used' ? 'used' : 'unused';

      const [result] = await conn.execute(
        'INSERT IGNORE INTO activation_codes (code, package_name, status, created_at) VALUES (?, ?, ?, NOW())',
        [code, packageName, status],
      );

      if (result.affectedRows > 0) {
        inserted += 1;
      } else {
        skipped += 1;
      }
    }

    await conn.commit();
    return res.json({
      success: true,
      inserted,
      skipped,
      requested: codes.length,
    });
  } catch (error) {
    if (conn) {
      try {
        await conn.rollback();
      } catch (e) {
        console.error('Rollback failed:', e);
      }
    }
    console.error('Bulk create activation codes error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create activation codes.' });
  } finally {
    if (conn) conn.release();
  }
}

router.post('/codes', bulkImportActivationCodes);
router.post('/codes/import', bulkImportActivationCodes);

router.post('/codes/:code/assign', async (req, res) => {
  const { code } = req.params;
  try {
    const rows = await query('SELECT code FROM activation_codes WHERE code = ?', [code]);
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Activation code not found.' });
    }

    await query(
      'UPDATE activation_codes SET status = ?, assigned_at = NOW() WHERE code = ?',
      ['assigned', code],
    );

    return res.json({ success: true, message: 'Activation code assigned.' });
  } catch (error) {
    console.error('Assign activation code error:', error);
    return res.status(500).json({ success: false, message: 'Failed to assign activation code.' });
  }
});

router.post('/codes/:code/revoke', async (req, res) => {
  const { code } = req.params;
  const { reason = '' } = req.body || {};
  try {
    const rows = await query('SELECT code FROM activation_codes WHERE code = ?', [code]);
    if (!rows.length) {
      return res.status(404).json({ success: false, message: 'Activation code not found.' });
    }

    await query(
      'UPDATE activation_codes SET status = ?, notes = ? WHERE code = ?',
      ['revoked', `Revoked: ${reason}`.trim(), code],
    );

    await query(
      'UPDATE subscriptions SET status = ?, notes = ? WHERE activation_code = ?',
      ['cancelled', `Cancelled: Code revoked${reason ? ` - ${reason}` : ''}`, code],
    );

    return res.json({ success: true, message: 'Activation code revoked.' });
  } catch (error) {
    console.error('Revoke activation code error:', error);
    return res.status(500).json({ success: false, message: 'Failed to revoke activation code.' });
  }
});

router.post('/requests', async (req, res) => {
  const body = req.body || {};
  const id = body.id || randomUUID();
  try {
    await query(
      `INSERT INTO activation_code_requests
        (id, business_name, package_name, package_price, request_type, contact_email, contact_phone, additional_notes, status, activation_code, requested_at, fulfilled_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())`,
      [
        id,
        body.business_name,
        body.package_name,
        body.package_price,
        body.request_type,
        body.contact_email,
        body.contact_phone,
        body.additional_notes || '',
        body.status || 'pending',
        body.activation_code || null,
        body.requested_at || new Date().toISOString().slice(0, 19).replace('T', ' '),
        body.fulfilled_at || null,
      ],
    );

    return res.json({ success: true, id });
  } catch (error) {
    console.error('Create activation request error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create activation request.' });
  }
});

router.get('/requests', async (req, res) => {
  const { status, activationCode } = req.query;
  try {
    const filters = [];
    const params = [];
    if (status) {
      filters.push('status = ?');
      params.push(status);
    }
    if (activationCode) {
      filters.push('activation_code = ?');
      params.push(activationCode);
    }
    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const rows = await query(
      `SELECT id, business_name, package_name, package_price, request_type, contact_email, contact_phone, additional_notes, status, activation_code, requested_at, fulfilled_at, created_at, updated_at
       FROM activation_code_requests ${where}
       ORDER BY requested_at DESC`,
      params,
    );
    return res.json({ success: true, requests: rows });
  } catch (error) {
    console.error('List activation requests error:', error);
    return res.status(500).json({ success: false, message: 'Failed to list activation requests.' });
  }
});

router.get('/requests/by-code/:code', async (req, res) => {
  const { code } = req.params;
  try {
    const rows = await query(
      `SELECT id, business_name, package_name, package_price, request_type, contact_email, contact_phone, additional_notes, status, activation_code, requested_at, fulfilled_at, created_at, updated_at
       FROM activation_code_requests
       WHERE activation_code = ?
       ORDER BY requested_at DESC
       LIMIT 1`,
      [code],
    );

    if (!rows.length) {
      return res.json({ success: true, request: null });
    }

    return res.json({ success: true, request: rows[0] });
  } catch (error) {
    console.error('Lookup activation request by code error:', error);
    return res.status(500).json({ success: false, message: 'Failed to look up activation request.' });
  }
});

router.patch('/requests/:id', async (req, res) => {
  const { id } = req.params;
  const body = req.body || {};
  try {
    const existing = await query('SELECT id FROM activation_code_requests WHERE id = ?', [id]);
    if (!existing.length) {
      return res.status(404).json({ success: false, message: 'Activation request not found.' });
    }

    const fields = [];
    const params = [];
    if (body.status !== undefined) {
      fields.push('status = ?');
      params.push(body.status);
    }
    if (body.activation_code !== undefined) {
      fields.push('activation_code = ?');
      params.push(body.activation_code);
    }
    if (body.fulfilled_at !== undefined) {
      fields.push('fulfilled_at = ?');
      params.push(body.fulfilled_at);
    }
    fields.push('updated_at = NOW()');

    await query(`UPDATE activation_code_requests SET ${fields.join(', ')} WHERE id = ?`, [
      ...params,
      id,
    ]);

    return res.json({ success: true });
  } catch (error) {
    console.error('Update activation request error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update activation request.' });
  }
});

router.post('/subscriptions', async (req, res) => {
  const body = req.body || {};
  const id = body.id || null;
  try {
    await query(
      `INSERT INTO subscriptions
        (device_id, activation_code, package_name, device_name, activated_at, expires_at, status, last_checked_at, notes, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
          device_id = VALUES(device_id),
          package_name = VALUES(package_name),
          device_name = VALUES(device_name),
          activated_at = VALUES(activated_at),
          expires_at = VALUES(expires_at),
          status = VALUES(status),
          last_checked_at = VALUES(last_checked_at),
          notes = VALUES(notes)`,
      [
        body.device_id,
        body.activation_code,
        body.package_name,
        body.device_name,
        body.activated_at,
        body.expires_at,
        body.status || 'active',
        body.last_checked_at || null,
        body.notes || null,
      ],
    );

    return res.json({ success: true, id });
  } catch (error) {
    console.error('Create subscription error:', error);
    return res.status(500).json({ success: false, message: 'Failed to create subscription.' });
  }
});

router.get('/subscriptions', async (req, res) => {
  const { deviceId, activationCode, status } = req.query;
  try {
    const filters = [];
    const params = [];
    if (deviceId) {
      filters.push('device_id = ?');
      params.push(deviceId);
    }
    if (activationCode) {
      filters.push('activation_code = ?');
      params.push(activationCode);
    }
    if (status) {
      filters.push('status = ?');
      params.push(status);
    }
    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const rows = await query(
      `SELECT id, device_id, activation_code, package_name, device_name, activated_at, expires_at, status, last_checked_at, notes, created_at
       FROM subscriptions ${where}
       ORDER BY activated_at DESC`,
      params,
    );
    return res.json({ success: true, subscriptions: rows });
  } catch (error) {
    console.error('List subscriptions error:', error);
    return res.status(500).json({ success: false, message: 'Failed to list subscriptions.' });
  }
});

router.get('/subscription-renewals', async (req, res) => {
  const { subscriptionId } = req.query;
  try {
    const filters = [];
    const params = [];
    if (subscriptionId) {
      filters.push('subscription_id = ?');
      params.push(subscriptionId);
    }
    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const rows = await query(
      `SELECT id, subscription_id, renewed_at, previous_expires_at, new_expires_at, payment_method, payment_amount, transaction_id, notes
       FROM subscription_renewals ${where}
       ORDER BY renewed_at DESC`,
      params,
    );
    return res.json({ success: true, renewals: rows });
  } catch (error) {
    console.error('List subscription renewals error:', error);
    return res.status(500).json({ success: false, message: 'Failed to list subscription renewals.' });
  }
});

router.get('/used-codes', async (req, res) => {
  try {
    const codes = await query(
      `SELECT code, package_name, status, device_id, device_name, assigned_at, notes, used_at, created_at
       FROM activation_codes
       WHERE status = 'used'
       ORDER BY used_at DESC`,
    );

    const subscriptions = codes.length
      ? await query(
          `SELECT activation_code, status AS subscription_status, expires_at, activated_at
           FROM subscriptions
           WHERE activation_code IN (?)`,
          [codes.map((row) => row.code)],
        )
      : [];

    const subscriptionsByCode = new Map(
      normalizeRows(subscriptions).map((row) => [row.activation_code, row]),
    );

    const results = codes.map((row) => ({
      ...row,
      subscription: subscriptionsByCode.get(row.code) || null,
    }));

    return res.json({ success: true, codes: results });
  } catch (error) {
    console.error('List used codes error:', error);
    return res.status(500).json({ success: false, message: 'Failed to list used activation codes.' });
  }
});

module.exports = router;
