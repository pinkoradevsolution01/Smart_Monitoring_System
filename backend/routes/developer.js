const bcrypt = require('bcryptjs');
const express = require('express');
const { query } = require('../db');

const router = express.Router();

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function sanitizeAccount(row) {
  if (!row) return null;
  return {
    id: row.id,
    displayName: row.display_name,
    email: row.email,
    authMethod: row.auth_method,
    googleSub: row.google_sub || null,
    avatarUrl: row.avatar_url || null,
    isActive: (row.is_active ?? 1) === 1,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function getDeveloperAccount() {
  const rows = await query(
    'SELECT id, display_name, email, password_hash, auth_method, google_sub, avatar_url, is_active, created_at, updated_at FROM developer_accounts WHERE id = ? LIMIT 1',
    ['primary'],
  );
  return rows[0] || null;
}

router.get('/account', async (_req, res) => {
  try {
    const account = await getDeveloperAccount();
    return res.json({ success: true, account: sanitizeAccount(account) });
  } catch (error) {
    console.error('Developer /account GET error:', error);
    return res.status(500).json({ success: false, message: 'Failed to load developer account.' });
  }
});

router.put('/account', async (req, res) => {
  const {
    displayName,
    email,
    password,
    authMethod,
    googleSub,
    avatarUrl,
  } = req.body || {};

  const normalizedEmail = normalizeEmail(email);
  const normalizedDisplayName = String(displayName || '').trim() || 'Developer';
  const resolvedAuthMethod = String(authMethod || 'password').trim().toLowerCase() === 'google'
    ? 'google'
    : 'password';

  if (!normalizedEmail) {
    return res.status(400).json({ success: false, message: 'Email is required.' });
  }

  try {
    const existing = await getDeveloperAccount();
    const passwordHash = password
      ? await bcrypt.hash(String(password), 10)
      : existing?.password_hash || null;

    if (resolvedAuthMethod === 'password' && !passwordHash) {
      return res.status(400).json({
        success: false,
        message: 'Password is required and must be at least 6 characters.',
      });
    }

    if (existing) {
      await query(
        `UPDATE developer_accounts
         SET display_name = ?,
             email = ?,
             password_hash = COALESCE(?, password_hash),
             auth_method = ?,
             google_sub = ?,
             avatar_url = ?,
             updated_at = NOW()
         WHERE id = ?`,
        [
          normalizedDisplayName,
          normalizedEmail,
          passwordHash,
          resolvedAuthMethod,
          resolvedAuthMethod === 'google' ? (googleSub || null) : null,
          avatarUrl || null,
          existing.id,
        ],
      );
    } else {
      await query(
        `INSERT INTO developer_accounts
          (id, display_name, email, password_hash, auth_method, google_sub, avatar_url, is_active)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1)`,
        [
          'primary',
          normalizedDisplayName,
          normalizedEmail,
          passwordHash,
          resolvedAuthMethod,
          resolvedAuthMethod === 'google' ? (googleSub || null) : null,
          avatarUrl || null,
        ],
      );
    }

    const updated = await getDeveloperAccount();
    return res.json({ success: true, account: sanitizeAccount(updated) });
  } catch (error) {
    console.error('Developer /account PUT error:', error);
    return res.status(500).json({ success: false, message: 'Failed to save developer account.' });
  }
});

router.post('/login', async (req, res) => {
  const username = String(req.body?.username || req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');

  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Username and password are required.' });
  }

  try {
    const account = await getDeveloperAccount();
    if (!account || (account.is_active ?? 1) !== 1) {
      return res.status(401).json({ success: false, message: 'Developer account is not configured.' });
    }

    const accountEmail = normalizeEmail(account.email);
    const accountName = normalizeEmail(account.display_name);
    const matchesIdentity = username === accountEmail || username === accountName;
    const passwordMatches = account.password_hash
      ? await bcrypt.compare(password, account.password_hash)
      : false;

    if (!matchesIdentity || !passwordMatches) {
      return res.status(401).json({ success: false, message: 'Invalid developer credentials.' });
    }

    await query(
      'UPDATE developer_accounts SET updated_at = NOW() WHERE id = ?',
      [account.id],
    );

    return res.json({
      success: true,
      account: sanitizeAccount(account),
    });
  } catch (error) {
    console.error('Developer /login error:', error);
    return res.status(500).json({ success: false, message: 'Developer login failed.' });
  }
});

router.post('/google/login', async (req, res) => {
  const {
    email,
    name,
    googleSub,
    avatarUrl,
  } = req.body || {};

  const normalizedEmail = normalizeEmail(email);
  if (!normalizedEmail || !googleSub) {
    return res.status(400).json({ success: false, message: 'Google profile information is required.' });
  }

  try {
    const account = await getDeveloperAccount();
    if (!account || (account.is_active ?? 1) !== 1) {
      return res.status(401).json({ success: false, message: 'Developer account is not configured.' });
    }

    const accountEmail = normalizeEmail(account.email);
    const matches = normalizedEmail === accountEmail || String(account.google_sub || '') === String(googleSub);
    if (!matches) {
      return res.status(401).json({ success: false, message: 'This Google account is not registered as the developer account.' });
    }

    await query(
      `UPDATE developer_accounts
       SET display_name = COALESCE(?, display_name),
           email = ?,
           auth_method = 'google',
           google_sub = ?,
           avatar_url = ?,
           updated_at = NOW()
       WHERE id = ?`,
      [
        name || account.display_name,
        normalizedEmail,
        googleSub,
        avatarUrl || null,
        account.id,
      ],
    );

    const updated = await getDeveloperAccount();
    return res.json({ success: true, account: sanitizeAccount(updated) });
  } catch (error) {
    console.error('Developer /google/login error:', error);
    return res.status(500).json({ success: false, message: 'Google developer sign-in failed.' });
  }
});

module.exports = router;
