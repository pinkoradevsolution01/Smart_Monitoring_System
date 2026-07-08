const express = require('express');
const { query, getConnection } = require('../db');
const router = express.Router();

function buildInClause(values) {
  const items = Array.isArray(values)
    ? values.filter((value) => value !== null && value !== undefined && String(value).trim() !== '')
    : [];

  if (!items.length) {
    return { clause: '(NULL)', params: [] };
  }

  return {
    clause: `(${items.map(() => '?').join(', ')})`,
    params: items,
  };
}

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

router.delete('/purge', async (req, res) => {
  const ownerEmail = String(req.query.ownerEmail || req.body?.ownerEmail || '').trim();
  const ownerId = String(req.query.ownerId || req.body?.ownerId || '').trim();
  const businessId = String(req.query.businessId || req.body?.businessId || '').trim();
  const deviceId = String(req.query.deviceId || req.body?.deviceId || '').trim();
  const activationCode = String(req.query.activationCode || req.body?.activationCode || '').trim();

  if (!ownerEmail && !ownerId && !businessId && !deviceId && !activationCode) {
    return res.status(400).json({
      success: false,
      message: 'ownerEmail, ownerId, businessId, deviceId, or activationCode is required.',
    });
  }

  const connection = await getConnection();
  try {
    await connection.beginTransaction();

    let resolvedBusinessId = businessId || null;
    let resolvedOwnerId = ownerId || null;

    if (!resolvedBusinessId && ownerEmail) {
      const [businessRows] = await connection.execute(
        'SELECT id, owner_id FROM businesses WHERE owner_email = ? LIMIT 1',
        [ownerEmail],
      );

      if (businessRows.length) {
        resolvedBusinessId = businessRows[0].id;
        resolvedOwnerId = resolvedOwnerId || businessRows[0].owner_id || null;
      }
    }

    const activationCodes = new Set();

    if (ownerEmail) {
      const [requestRows] = await connection.execute(
        'SELECT activation_code FROM activation_code_requests WHERE contact_email = ? AND activation_code IS NOT NULL',
        [ownerEmail],
      );

      for (const row of requestRows) {
        if (row.activation_code) {
          activationCodes.add(row.activation_code);
        }
      }
    }

    if (activationCode) {
      activationCodes.add(activationCode);
    }

    if (deviceId) {
      const [subscriptionRows] = await connection.execute(
        'SELECT activation_code FROM subscriptions WHERE device_id = ?',
        [deviceId],
      );

      for (const row of subscriptionRows) {
        if (row.activation_code) {
          activationCodes.add(row.activation_code);
        }
      }
    }

    const activationCodeList = Array.from(activationCodes);
    if (activationCodeList.length) {
      const { clause, params } = buildInClause(activationCodeList);

      await connection.execute(
        `DELETE sr
         FROM subscription_renewals sr
         INNER JOIN subscriptions s ON s.id = sr.subscription_id
         WHERE s.activation_code IN ${clause}`,
        params,
      );

      await connection.execute(
        `DELETE FROM subscription_records WHERE activation_code IN ${clause}`,
        params,
      );

      await connection.execute(
        `DELETE FROM subscriptions WHERE activation_code IN ${clause}`,
        params,
      );

      await connection.execute(
        `DELETE FROM activation_codes WHERE code IN ${clause}`,
        params,
      );
    }

    if (ownerEmail) {
      await connection.execute(
        'DELETE FROM activation_code_requests WHERE contact_email = ?',
        [ownerEmail],
      );
    }

    if (resolvedBusinessId) {
      await connection.execute('DELETE FROM businesses WHERE id = ?', [resolvedBusinessId]);
    } else if (resolvedOwnerId) {
      await connection.execute('DELETE FROM users WHERE id = ?', [resolvedOwnerId]);
    }

    await connection.commit();
    return res.json({ success: true, message: 'Subscriber data purged successfully.' });
  } catch (error) {
    try {
      await connection.rollback();
    } catch (rollbackError) {
      console.error('Purge rollback failed:', rollbackError);
    }

    console.error('Business purge error:', error);
    return res.status(500).json({ success: false, message: 'Failed to purge subscriber data.' });
  } finally {
    connection.release();
  }
});

module.exports = router;
