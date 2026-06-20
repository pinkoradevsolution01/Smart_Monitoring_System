const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { randomUUID } = require('crypto');
const { query } = require('../db');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret';
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || '';
const GOOGLE_DEFAULT_REDIRECT_URI = process.env.GOOGLE_REDIRECT_URI || '';

function normalizeRedirectUri(value) {
  return String(value || '')
    .trim()
    .replace(/[\\]+$/g, '');
}

function resolveBusinessId(req, body = {}) {
  return (
    body.businessId ||
    body.business_id ||
    req.query.businessId ||
    req.query.business_id ||
    req.auth?.businessId ||
    req.auth?.business_id ||
    null
  );
}

async function fetchUserById(id, businessId = null) {
  if (businessId) {
    const scopedRows = await query(
      'SELECT id, business_id, email, password_hash, role, full_name, contact_number, auth_method, is_active, created_at, updated_at, last_login_at FROM users WHERE id = ? AND business_id = ? LIMIT 1',
      [id, businessId],
    );
    if (scopedRows.length) {
      return scopedRows[0];
    }
  }

  const rows = await query(
    'SELECT id, business_id, email, password_hash, role, full_name, contact_number, auth_method, is_active, created_at, updated_at, last_login_at FROM users WHERE id = ? LIMIT 1',
    [id],
  );
  return rows[0] || null;
}

async function verifyGoogleIdToken(idToken) {
  const url = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error('Invalid Google ID token');
  }

  const profile = await response.json();
  if (!profile.email || !profile.sub) {
    throw new Error('Invalid Google profile payload');
  }

  if (profile.email_verified !== 'true' && profile.email_verified !== true) {
    throw new Error('Google email is not verified');
  }

  return profile;
}

function buildGoogleAuthUrl(redirectUri, state) {
  if (!GOOGLE_CLIENT_ID) {
    throw new Error('GOOGLE_CLIENT_ID is not configured');
  }

  const params = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: redirectUri,
    response_type: 'code',
    scope: 'openid email profile',
    access_type: 'offline',
    prompt: 'select_account',
  });

  if (state) {
    params.set('state', state);
  }

  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

async function exchangeGoogleCode(code, redirectUri) {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    throw new Error('Google OAuth client is not configured');
  }

  const body = new URLSearchParams({
    code,
    client_id: GOOGLE_CLIENT_ID,
    client_secret: GOOGLE_CLIENT_SECRET,
    redirect_uri: normalizeRedirectUri(redirectUri),
    grant_type: 'authorization_code',
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body.toString(),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Google token exchange failed: ${details}`);
  }

  return await response.json();
}

function issueAppSession(profile) {
  const token = jwt.sign(
    {
      userId: profile.sub,
      email: profile.email,
      role: 'google_user',
      name: profile.name || profile.email.split('@')[0],
    },
    JWT_SECRET,
    { expiresIn: '12h' },
  );

  return {
    success: true,
    token,
    user: {
      id: profile.sub,
      email: profile.email,
      role: 'google_user',
      fullName: profile.name || profile.email.split('@')[0],
      avatarUrl: profile.picture || null,
    },
  };
}

router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const businessId = resolveBusinessId(req, req.body || {});
  if (!email || !password) {
    return res.status(400).json({ success: false, message: 'Email and password are required.' });
  }

  try {
    const rows = businessId
      ? await query(
          'SELECT id, business_id, email, password_hash, role, full_name, contact_number, auth_method, is_active FROM users WHERE business_id = ? AND email = ? LIMIT 1',
          [businessId, email],
        )
      : await query(
          'SELECT id, business_id, email, password_hash, role, full_name, contact_number, auth_method, is_active FROM users WHERE email = ?',
          [email],
        );

    if (!rows.length) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }

    if (!businessId && rows.length > 1) {
      return res.status(409).json({
        success: false,
        message: 'Multiple accounts use this email. Please provide a businessId.',
      });
    }

    const user = rows[0];
    if ((user.is_active ?? 1) !== 1) {
      return res.status(403).json({ success: false, message: 'User account is inactive.' });
    }

    const passwordMatches = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatches) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }

    await query(
      'UPDATE users SET last_login_at = NOW() WHERE id = ?',
      [user.id],
    );

    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role, businessId: user.business_id || null },
      JWT_SECRET,
      { expiresIn: '12h' },
    );

    return res.json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        businessId: user.business_id || null,
        role: user.role,
        fullName: user.full_name,
        contactNumber: user.contact_number || null,
        authMethod: user.auth_method || 'password',
      },
    });
  } catch (error) {
    console.error('Auth /login error:', error);
    return res.status(500).json({ success: false, message: 'Login failed due to server error.' });
  }
});

router.post('/google/register-owner', async (req, res) => {
  const { id, email, fullName, avatarUrl, contactNumber } = req.body || {};
  const businessId = resolveBusinessId(req, req.body || {});
  const normalizedEmail = typeof email === 'string' ? email.trim() : '';

  if (!normalizedEmail) {
    return res.status(400).json({ success: false, message: 'Email is required.' });
  }

  try {
    const existingRows = businessId
      ? await query(
          'SELECT id, business_id, email, role, full_name, contact_number, auth_method FROM users WHERE business_id = ? AND email = ? LIMIT 1',
          [businessId, normalizedEmail],
        )
      : await query(
          'SELECT id, business_id, email, role, full_name, contact_number, auth_method FROM users WHERE email = ?',
          [normalizedEmail],
        );

    if (!businessId && existingRows.length > 1) {
      return res.status(409).json({
        success: false,
        message: 'Multiple accounts already use this email. Please provide a businessId.',
      });
    }

    let userRow;
    let created = false;

    if (existingRows.length) {
      userRow = existingRows[0];
      await query(
        'UPDATE users SET full_name = ?, role = ?, contact_number = ?, auth_method = ?, business_id = COALESCE(?, business_id) WHERE id = ?',
        [
          fullName || userRow.full_name || normalizedEmail.split('@')[0],
          'owner',
          contactNumber || null,
          'google',
          businessId,
          userRow.id,
        ],
      );
    } else {
      const placeholderHash = await bcrypt.hash(randomUUID(), 10);
      const userId = id || randomUUID();
      await query(
        'INSERT INTO users (id, business_id, email, password_hash, role, full_name, contact_number, auth_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          userId,
          businessId,
          normalizedEmail,
          placeholderHash,
          'owner',
          fullName || normalizedEmail.split('@')[0],
          contactNumber || null,
          'google',
        ],
      );

      const insertedRows = await query(
        'SELECT id, business_id, email, role, full_name, contact_number, auth_method, created_at FROM users WHERE id = ? LIMIT 1',
        [userId],
      );
      userRow = insertedRows[0];
      created = true;
    }

    return res.json({
      success: true,
      created,
      user: {
        id: userRow.id,
        email: userRow.email,
        businessId: userRow.business_id || businessId || null,
        role: 'owner',
        fullName: userRow.full_name || fullName || normalizedEmail.split('@')[0],
        contactNumber: userRow.contact_number || contactNumber || null,
        avatarUrl: avatarUrl || null,
        authMethod: userRow.auth_method || 'google',
      },
      googleUserId: id || null,
    });
  } catch (error) {
    console.error('Auth /google/register-owner error:', error);
    return res.status(500).json({ success: false, message: 'Failed to register owner account.' });
  }
});

router.patch('/users/:id', async (req, res) => {
  const { id } = req.params;
  const { fullName, email, contactNumber, role } = req.body || {};
  const businessId = resolveBusinessId(req, req.body || {});
  const normalizedEmail = typeof email === 'string' ? email.trim() : '';

  try {
    const existing = await fetchUserById(id, businessId);

    if (!existing) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    if (normalizedEmail && normalizedEmail !== existing.email) {
      const duplicate = businessId
        ? await query(
            'SELECT id FROM users WHERE business_id = ? AND email = ? AND id <> ? LIMIT 1',
            [businessId, normalizedEmail, id],
          )
        : await query(
            'SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1',
            [normalizedEmail, id],
          );
      if (duplicate.length) {
        return res.status(409).json({ success: false, message: 'Email already in use.' });
      }
    }

    await query(
      `UPDATE users
       SET full_name = ?, email = ?, contact_number = ?, role = ?
       WHERE id = ?`,
      [
        fullName || existing.full_name || existing.email.split('@')[0],
        normalizedEmail || existing.email,
        contactNumber !== undefined ? contactNumber : existing.contact_number || null,
        role || existing.role,
        id,
      ],
    );

    const updated = await fetchUserById(id, businessId);
    return res.json({
      success: true,
      user: {
        id: updated.id,
        email: updated.email,
        businessId: updated.business_id || null,
        role: updated.role,
        fullName: updated.full_name,
        contactNumber: updated.contact_number || null,
        authMethod: updated.auth_method || 'password',
        createdAt: updated.created_at,
      },
    });
  } catch (error) {
    console.error('Auth /users/:id update error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update user.' });
  }
});

router.patch('/users/:id/password', async (req, res) => {
  const { id } = req.params;
  const { currentPassword, newPassword } = req.body || {};
  const businessId = resolveBusinessId(req, req.body || {});

  if (!newPassword || newPassword.length < 6) {
    return res.status(400).json({ success: false, message: 'New password must be at least 6 characters.' });
  }

  try {
    const existing = await fetchUserById(id, businessId);

    if (!existing) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    const isGoogleAccount = (existing.auth_method || '').toLowerCase() === 'google';

    if (!isGoogleAccount) {
      if (!currentPassword) {
        return res.status(400).json({ success: false, message: 'Current password is required.' });
      }

      const passwordMatches = await bcrypt.compare(currentPassword, existing.password_hash);
      if (!passwordMatches) {
        return res.status(401).json({ success: false, message: 'Current password is incorrect.' });
      }
    }

    const newHash = await bcrypt.hash(newPassword, 10);
    await query(
      'UPDATE users SET password_hash = ?, auth_method = ? WHERE id = ?',
      [newHash, 'password', id],
    );

    return res.json({
      success: true,
      user: {
        id: existing.id,
        email: existing.email,
        businessId: existing.business_id || null,
      },
    });
  } catch (error) {
    console.error('Auth /users/:id/password update error:', error);
    return res.status(500).json({ success: false, message: 'Failed to update password.' });
  }
});

router.delete('/users/:id', async (req, res) => {
  const { id } = req.params;
  const businessId = resolveBusinessId(req, req.body || {});

  try {
    const existing = await fetchUserById(id, businessId);
    if (!existing) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    if (businessId) {
      await query('DELETE FROM users WHERE id = ? AND business_id = ?', [id, businessId]);
    } else {
      await query('DELETE FROM users WHERE id = ?', [id]);
    }
    return res.json({ success: true });
  } catch (error) {
    console.error('Auth /users/:id delete error:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete user.' });
  }
});

router.post('/google', async (req, res) => {
  const { idToken } = req.body;
  if (!idToken) {
    return res.status(400).json({ success: false, message: 'Google ID token is required.' });
  }

  try {
    const profile = await verifyGoogleIdToken(idToken);
    return res.json(issueAppSession(profile));
  } catch (error) {
    console.error('Auth /google error:', error);
    return res.status(401).json({ success: false, message: 'Google sign-in failed.' });
  }
});

router.get('/google/url', async (req, res) => {
  const { redirectUri, state } = req.query;
  try {
    const resolvedRedirectUri = normalizeRedirectUri(
      redirectUri || GOOGLE_DEFAULT_REDIRECT_URI,
    );
    if (!resolvedRedirectUri) {
      return res.status(400).json({ success: false, message: 'Redirect URI is required.' });
    }

    return res.json({
      success: true,
      authUrl: buildGoogleAuthUrl(resolvedRedirectUri, state),
      redirectUri: resolvedRedirectUri,
    });
  } catch (error) {
    console.error('Auth /google/url error:', error);
    return res.status(500).json({
      success: false,
      message: `Failed to build Google auth URL: ${error.message}`,
    });
  }
});

router.post('/google/exchange', async (req, res) => {
  const { code, redirectUri } = req.body;
  if (!code) {
    return res.status(400).json({ success: false, message: 'Authorization code is required.' });
  }

  try {
    const resolvedRedirectUri = normalizeRedirectUri(
      redirectUri || GOOGLE_DEFAULT_REDIRECT_URI,
    );
    if (!resolvedRedirectUri) {
      return res.status(400).json({ success: false, message: 'Redirect URI is required.' });
    }

    const tokenResponse = await exchangeGoogleCode(code, resolvedRedirectUri);
    const idToken = tokenResponse.id_token;
    if (!idToken) {
      return res.status(401).json({ success: false, message: 'Google did not return an ID token.' });
    }

    const profile = await verifyGoogleIdToken(idToken);
    return res.json(issueAppSession(profile));
  } catch (error) {
    console.error('Auth /google/exchange error:', error);
    return res.status(401).json({
      success: false,
      message: `Google code exchange failed: ${error.message}`,
    });
  }
});

router.post('/logout', async (_req, res) => {
  return res.json({ success: true });
});

function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.substring(7) : null;
  if (!token) {
    return res.status(401).json({ success: false, message: 'Missing authorization token.' });
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token.' });
  }
}

router.get('/me', verifyToken, async (req, res) => {
  const user = req.user;
  return res.json({ success: true, user });
});

module.exports = router;
