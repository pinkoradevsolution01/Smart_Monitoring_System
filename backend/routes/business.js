const express = require('express');
const jwt = require('jsonwebtoken');
const { query, getConnection } = require('../db');
const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET;

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function issueBusinessSession(user) {
  if (!JWT_SECRET) throw new Error('JWT_SECRET is not configured.');
  return jwt.sign(
    { userId: user.id, email: user.email, role: user.role, businessId: user.business_id },
    JWT_SECRET,
    { expiresIn: '12h' },
  );
}

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

  const normalizedEmail = normalizeEmail(ownerEmail);
  if (!req.auth?.userId || normalizeEmail(req.auth.email) !== normalizedEmail) {
    return res.status(401).json({ success: false, message: 'Sign in as the business owner before initializing sync.' });
  }
  if (ownerId && String(ownerId) !== String(req.auth.userId)) {
    return res.status(403).json({ success: false, message: 'The supplied owner does not match the signed-in owner.' });
  }

  try {
    const cancelledRows = await query(
      'SELECT id FROM cancelled_subscribers WHERE email = ? LIMIT 1',
      [normalizedEmail],
    );
    if (cancelledRows.length) {
      return res.status(403).json({
        success: false,
        message: 'This subscriber account has been cancelled and cannot be reactivated.',
      });
    }

    // A device can retain a business ID from a previous owner. The authenticated
    // owner email is canonical and always wins over cached client state.
    const existing = await query(
      'SELECT id FROM businesses WHERE LOWER(owner_email) = ? LIMIT 1',
      [normalizedEmail],
    );
    let businessId;
    if (existing.length) {
      businessId = existing[0].id;
      if (existingBusinessId && String(existingBusinessId) !== String(businessId)) {
        console.warn(`Ignoring stale business ID ${existingBusinessId} for ${normalizedEmail}.`);
      }
    } else {
      if (existingBusinessId) {
        const requested = await query('SELECT owner_email FROM businesses WHERE id = ? LIMIT 1', [existingBusinessId]);
        if (requested.length && normalizeEmail(requested[0].owner_email) !== normalizedEmail) {
          return res.status(403).json({ success: false, message: 'The requested business does not belong to the signed-in owner.' });
        }
      }

      businessId = existingBusinessId || `b-${Date.now()}-${Math.random().toString(36).substring(2, 8)}`;
      if (!existingBusinessId) {
        await query(
          'INSERT INTO businesses (id, name, owner_email, owner_id, is_active, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
          [businessId, businessName, normalizedEmail, req.auth.userId, 1],
        );
      }
    }

    await query(
      'UPDATE users SET business_id = ? WHERE id = ? AND LOWER(email) = ?',
      [businessId, req.auth.userId, normalizedEmail],
    );
    const users = await query(
      'SELECT id, business_id, email, role FROM users WHERE id = ? AND business_id = ? AND LOWER(email) = ? LIMIT 1',
      [req.auth.userId, businessId, normalizedEmail],
    );
    if (!users.length) {
      return res.status(403).json({ success: false, message: 'The signed-in owner is not assigned to this business.' });
    }

    return res.json({ success: true, businessId, token: issueBusinessSession(users[0]) });
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
        `UPDATE subscription_records
         SET status = 'cancelled',
             notes = CASE
               WHEN notes IS NULL OR notes = '' THEN 'Deactivated via subscriber deactivation'
               ELSE CONCAT(notes, '\nDeactivated via subscriber deactivation')
             END
         WHERE activation_code IN ${clause}`,
        params,
      );

      await connection.execute(
        `UPDATE subscriptions
         SET status = 'cancelled',
             last_checked_at = NOW(),
             notes = CASE
               WHEN notes IS NULL OR notes = '' THEN 'Deactivated via subscriber deactivation'
               ELSE CONCAT(notes, '\nDeactivated via subscriber deactivation')
             END
         WHERE activation_code IN ${clause}`,
        params,
      );
    }

    if (ownerEmail) {
      await connection.execute(
        `INSERT INTO cancelled_subscribers (email, activation_code, reason)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE
           activation_code = COALESCE(VALUES(activation_code), activation_code),
           reason = VALUES(reason),
           cancelled_at = NOW()`,
        [ownerEmail.toLowerCase(), activationCodeList[0] || null, 'Subscriber deactivated by developer'],
      );

      await connection.execute(
        `UPDATE activation_code_requests
         SET status = 'cancelled',
             additional_notes = CASE
               WHEN additional_notes IS NULL OR additional_notes = '' THEN 'Cancelled via subscriber deactivation'
               ELSE CONCAT(additional_notes, '\nCancelled via subscriber deactivation')
             END,
             updated_at = NOW()
         WHERE contact_email = ?`,
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
