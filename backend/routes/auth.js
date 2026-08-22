const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const {
  randomUUID,
  randomBytes,
  createHash,
} = require('crypto');
const { query, execute } = require('../db');

let nodemailer = null;
try {
  nodemailer = require('nodemailer');
} catch (_) {
  nodemailer = null;
}

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret';
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || '';
const GOOGLE_CALLBACK_URL = process.env.GOOGLE_CALLBACK_URL || '';
const GOOGLE_OAUTH_REDIRECT_URI = process.env.GOOGLE_OAUTH_REDIRECT_URI || '';
const GOOGLE_BACKEND_REDIRECT_URI =
  GOOGLE_CALLBACK_URL || process.env.GOOGLE_BACKEND_REDIRECT_URI || GOOGLE_OAUTH_REDIRECT_URI || '';
const GOOGLE_DEFAULT_REDIRECT_URI =
  GOOGLE_BACKEND_REDIRECT_URI || process.env.GOOGLE_REDIRECT_URI || '';
const GOOGLE_LOCAL_REDIRECT_URI = process.env.GOOGLE_LOCAL_REDIRECT_URI || '';
const OAUTH_STATE_TTL_MS = 5 * 60 * 1000;
const OAUTH_STATE_CLEANUP_INTERVAL_MS = 60 * 1000;
const oauthStateStore = new Map();
const oauthExchangeStore = new Map();
const OAUTH_EXCHANGE_TTL_MS = 2 * 60 * 1000;
const ANALYTICS_ROLES = new Set(['owner', 'admin', 'manager']);
const OWNER_PIN_RESET_TTL_MINUTES = 20;

function getSmtpConfig() {
  const host = process.env.SMTP_HOST || '';
  const port = Number(process.env.SMTP_PORT || 587);
  const user = process.env.SMTP_USER || '';
  const pass = process.env.SMTP_PASS || '';
  const fromEmail = process.env.FROM_EMAIL || user || '';
  return { host, port, user, pass, fromEmail };
}

async function sendOwnerPinResetToken({ to, token }) {
  const config = getSmtpConfig();
  if (!config.host || !config.user || !config.pass || !config.fromEmail) {
    throw new Error('Email service is not configured.');
  }
  if (!nodemailer) {
    throw new Error('nodemailer is not installed.');
  }

  const transporter = nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.port === 465,
    auth: { user: config.user, pass: config.pass },
  });

  await transporter.sendMail({
    from: config.fromEmail,
    to,
    subject: 'Owner PIN reset token',
    text:
      'Your Smart Monitoring System Owner PIN reset token is:\n\n' +
      `${token}\n\n` +
      `This token expires in ${OWNER_PIN_RESET_TTL_MINUTES} minutes and can only be used once. ` +
      'If you did not request this, you can ignore this email.',
  });
}

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

function authError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function googleCallbackUri() {
  return normalizeRedirectUri(
    GOOGLE_BACKEND_REDIRECT_URI || GOOGLE_DEFAULT_REDIRECT_URI || GOOGLE_LOCAL_REDIRECT_URI,
  );
}

function webAnalyticsCallbackUri() {
  const origin = String(process.env.WEB_ANALYTICS_URL || '').trim();
  if (!origin) return '';
  return new URL('/auth/google/callback', origin).toString();
}

function redirectToWebAnalytics(res, params) {
  const callbackUri = webAnalyticsCallbackUri();
  if (!callbackUri) return false;
  const destination = new URL(callbackUri);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '') {
      destination.searchParams.set(key, String(value));
    }
  }
  res.redirect(302, destination.toString());
  return true;
}

function readCookie(req, name) {
  const cookieHeader = req.headers.cookie || '';
  for (const item of cookieHeader.split(';')) {
    const [key, ...parts] = item.trim().split('=');
    if (key === name) return decodeURIComponent(parts.join('='));
  }
  return null;
}

async function findAnalyticsUserByEmail(email) {
  const normalizedEmail = String(email || '').trim().toLowerCase();
  const cancelled = await query(
    'SELECT id FROM cancelled_subscribers WHERE LOWER(email) = ? LIMIT 1',
    [normalizedEmail],
  );
  if (cancelled.length) throw authError(403, 'This subscriber account has been cancelled.');

  const rows = await query(
    'SELECT u.id, u.business_id, u.email, u.role, u.full_name, u.contact_number, b.is_active AS business_is_active FROM users u INNER JOIN businesses b ON b.id = u.business_id WHERE LOWER(u.email) = ? AND u.is_active = 1 AND b.is_active = 1',
    [normalizedEmail],
  );
  const eligible = rows.filter((user) => ANALYTICS_ROLES.has(String(user.role || '').toLowerCase()));
  if (eligible.length !== 1) {
    throw authError(403, 'This Google account is not eligible for Web Analytics.');
  }
  return eligible[0];
}

async function findAnalyticsUserById(userId, businessId) {
  const rows = await query(
    'SELECT u.id, u.business_id, u.email, u.role, u.full_name, u.contact_number, b.is_active AS business_is_active FROM users u INNER JOIN businesses b ON b.id = u.business_id WHERE u.id = ? AND u.business_id = ? AND u.is_active = 1 AND b.is_active = 1 LIMIT 1',
    [userId, businessId],
  );
  if (!rows.length || !ANALYTICS_ROLES.has(String(rows[0].role || '').toLowerCase())) {
    throw authError(403, 'This account is no longer eligible for Web Analytics.');
  }
  const cancelled = await query(
    'SELECT id FROM cancelled_subscribers WHERE LOWER(email) = ? LIMIT 1',
    [String(rows[0].email).toLowerCase()],
  );
  if (cancelled.length) throw authError(403, 'This subscriber account has been cancelled.');
  return rows[0];
}

function issueAnalyticsSession(user) {
  const token = jwt.sign(
    { userId: user.id, email: user.email, role: user.role, businessId: user.business_id },
    JWT_SECRET,
    { expiresIn: '12h' },
  );

  return {
    success: true,
    token,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      businessId: user.business_id,
      fullName: user.full_name,
      contactNumber: user.contact_number || null,
    },
  };
}

function issueAppSession(profile) {
  const token = jwt.sign(
    { userId: profile.sub, email: profile.email, role: 'google_user', name: profile.name || profile.email.split('@')[0] },
    JWT_SECRET,
    { expiresIn: '12h' },
  );
  return { success: true, token, user: { id: profile.sub, email: profile.email, role: 'google_user', fullName: profile.name || profile.email.split('@')[0], avatarUrl: profile.picture || null } };
}

function pruneOauthStateStore() {
  const now = Date.now();
  for (const [state, entry] of oauthStateStore.entries()) {
    if (now - entry.createdAt > OAUTH_STATE_TTL_MS) oauthStateStore.delete(state);
  }
  for (const [codeHash, entry] of oauthExchangeStore.entries()) {
    if (now >= entry.expiresAt) oauthExchangeStore.delete(codeHash);
  }
}

setInterval(pruneOauthStateStore, OAUTH_STATE_CLEANUP_INTERVAL_MS);

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

// Start an owner PIN reset. The response is intentionally generic so the
// endpoint does not reveal whether an email belongs to an owner account.
router.post('/owner-pin-reset/request', async (req, res) => {
  const email = typeof req.body?.email === 'string'
    ? req.body.email.trim().toLowerCase()
    : '';

  if (!email || !email.includes('@')) {
    return res.status(400).json({ success: false, message: 'A valid email is required.' });
  }

  try {
    const cancelledRows = await query(
      'SELECT id FROM cancelled_subscribers WHERE email = ? LIMIT 1',
      [String(email).trim().toLowerCase()],
    );
    if (cancelledRows.length) {
      return res.status(403).json({
        success: false,
        message: 'This subscriber account has been cancelled and cannot be reactivated.',
      });
    }

    const owners = await query(
      `SELECT id, email FROM users
       WHERE email COLLATE utf8mb4_unicode_ci =
             CONVERT(? USING utf8mb4) COLLATE utf8mb4_unicode_ci
         AND role = 'owner' AND is_active = 1
       LIMIT 1`,
      [email],
    );

    if (!owners.length) {
      return res.json({
        success: true,
        message: 'If that email belongs to an owner account, a reset token has been sent.',
      });
    }

    const owner = owners[0];
    const token = randomBytes(32).toString('hex');
    const tokenHash = createHash('sha256').update(token, 'utf8').digest('hex');

    await execute(
      `UPDATE owner_pin_reset_tokens
       SET used_at = NOW()
       WHERE user_id = ? AND used_at IS NULL`,
      [owner.id],
    );
    await execute(
      `INSERT INTO owner_pin_reset_tokens
       (id, user_id, email, token_hash, expires_at)
       VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ${OWNER_PIN_RESET_TTL_MINUTES} MINUTE))`,
      [randomUUID(), owner.id, owner.email, tokenHash],
    );

    try {
      await sendOwnerPinResetToken({ to: owner.email, token });
    } catch (mailError) {
      await execute(
        `UPDATE owner_pin_reset_tokens
         SET used_at = NOW()
         WHERE token_hash = ? AND used_at IS NULL`,
        [tokenHash],
      );
      throw mailError;
    }

    return res.json({
      success: true,
      message: 'If that email belongs to an owner account, a reset token has been sent.',
    });
  } catch (error) {
    console.error('Owner PIN reset request error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to send a reset token right now. Please try again later.',
    });
  }
});

// Verify and consume an owner PIN reset token exactly once.
router.post('/owner-pin-reset/verify', async (req, res) => {
  const email = typeof req.body?.email === 'string'
    ? req.body.email.trim().toLowerCase()
    : '';
  const token = typeof req.body?.token === 'string' ? req.body.token.trim() : '';
  const newPin = typeof req.body?.newPin === 'string' ? req.body.newPin.trim() : '';

  if (!email || !email.includes('@') || !/^[a-f0-9]{64}$/i.test(token) || !/^\d{4}$/.test(newPin)) {
    return res.status(400).json({ success: false, message: 'Invalid reset details.' });
  }

  try {
    const tokenHash = createHash('sha256').update(token, 'utf8').digest('hex');
    const candidates = await query(
      `SELECT t.id, t.user_id
       FROM owner_pin_reset_tokens t
       INNER JOIN users u ON
         CONVERT(u.id USING utf8mb4) COLLATE utf8mb4_unicode_ci =
         CONVERT(t.user_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
       WHERE t.email COLLATE utf8mb4_unicode_ci =
             CONVERT(? USING utf8mb4) COLLATE utf8mb4_unicode_ci
         AND t.token_hash = ?
         AND t.used_at IS NULL
         AND t.expires_at > NOW()
         AND u.role = 'owner'
         AND u.is_active = 1
       LIMIT 1`,
      [email, tokenHash],
    );

    if (!candidates.length) {
      return res.status(400).json({
        success: false,
        message: 'This reset token is invalid, expired, or already used.',
      });
    }

    const result = await execute(
      `UPDATE owner_pin_reset_tokens
       SET used_at = NOW()
       WHERE id = ? AND used_at IS NULL AND expires_at > NOW()`,
      [candidates[0].id],
    );

    if (result[0].affectedRows !== 1) {
      return res.status(400).json({
        success: false,
        message: 'This reset token is invalid, expired, or already used.',
      });
    }

    const pinHash = await bcrypt.hash(newPin, 10);
    await execute(
      'UPDATE users SET pin_hash = ? WHERE id = ?',
      [pinHash, candidates[0].user_id],
    );

    // The token is temporary authorization; the hashed PIN is permanent until
    // the owner completes another reset.
    return res.json({ success: true, message: 'Owner PIN reset authorized.' });
  } catch (error) {
    console.error('Owner PIN reset verification error:', error);
    return res.status(500).json({ success: false, message: 'PIN reset failed.' });
  }
});

// Verify the permanent Owner PIN stored in MySQL. Reset tokens are only
// temporary authorization; they never determine the PIN's lifetime.
router.post('/owner-pin/verify', async (req, res) => {
  const email = typeof req.body?.email === 'string'
    ? req.body.email.trim().toLowerCase()
    : '';
  const pin = typeof req.body?.pin === 'string' ? req.body.pin.trim() : '';

  if (!email || !email.includes('@') || !/^\d{4}$/.test(pin)) {
    return res.status(400).json({ success: false, message: 'Invalid PIN details.' });
  }

  try {
    const owners = await query(
      `SELECT pin_hash FROM users
       WHERE email COLLATE utf8mb4_unicode_ci = CONVERT(? USING utf8mb4) COLLATE utf8mb4_unicode_ci
         AND role = 'owner' AND is_active = 1 LIMIT 1`,
      [email],
    );
    const valid = owners.length && owners[0].pin_hash
      ? await bcrypt.compare(pin, owners[0].pin_hash)
      : false;
    if (!valid) {
      return res.status(401).json({ success: false, message: 'Invalid PIN.' });
    }
    return res.json({ success: true });
  } catch (error) {
    console.error('Owner PIN verification error:', error);
    return res.status(500).json({ success: false, message: 'PIN verification failed.' });
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
    const cancelledRows = await query(
      'SELECT id FROM cancelled_subscribers WHERE email = ? LIMIT 1',
      [normalizedEmail.toLowerCase()],
    );
    if (cancelledRows.length) {
      return res.status(403).json({
        success: false,
        message: 'This subscriber account has been cancelled and cannot be reactivated.',
      });
    }

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
  const { fullName, email, contactNumber, role, isActive } = req.body || {};
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
       SET full_name = ?, email = ?, contact_number = ?, role = ?, is_active = COALESCE(?, is_active)
       WHERE id = ?`,
      [
        fullName || existing.full_name || existing.email.split('@')[0],
        normalizedEmail || existing.email,
        contactNumber !== undefined ? contactNumber : existing.contact_number || null,
        role || existing.role,
        typeof isActive === 'boolean' ? (isActive ? 1 : 0) : null,
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
      await query('UPDATE users SET is_active = 0 WHERE id = ? AND business_id = ?', [id, businessId]);
    } else {
      await query('UPDATE users SET is_active = 0 WHERE id = ?', [id]);
    }

    return res.json({
      success: true,
      message: 'User deactivated successfully.',
    });
  } catch (error) {
    console.error('Auth /users/:id delete error:', error);
    return res.status(500).json({ success: false, message: 'Failed to deactivate user.' });
  }
});

router.post('/google', async (req, res) => {
  const { idToken } = req.body;
  if (!idToken) return res.status(400).json({ success: false, message: 'Google ID token is required.' });
  try { return res.json(issueAppSession(await verifyGoogleIdToken(idToken))); }
  catch (error) { console.error('Auth /google error:', error); return res.status(401).json({ success: false, message: 'Google sign-in failed.' }); }
});

router.get('/google/url', async (req, res) => {
  const { redirectUri, state } = req.query;
  try {
    const resolvedRedirectUri = normalizeRedirectUri(redirectUri || GOOGLE_DEFAULT_REDIRECT_URI || GOOGLE_LOCAL_REDIRECT_URI);
    if (!resolvedRedirectUri) return res.status(400).json({ success: false, message: 'Redirect URI is required.' });
    return res.json({ success: true, authUrl: buildGoogleAuthUrl(resolvedRedirectUri, state), redirectUri: resolvedRedirectUri });
  } catch (error) {
    console.error('Auth /google/url error:', error);
    return res.status(500).json({ success: false, message: 'Failed to build Google auth URL: ' + error.message });
  }
});

// Reserved for Web Analytics. Existing Smart Monitoring clients use /google/url,
// /google/status, or POST /google and retain their original behavior.
router.get('/google', (req, res) => {
  const redirectUri = googleCallbackUri();
  if (!redirectUri || !webAnalyticsCallbackUri()) return res.status(500).json({ success: false, message: 'Google OAuth is not configured for Web Analytics.' });
  try {
    const state = randomBytes(32).toString('base64url');
    oauthStateStore.set(state, { createdAt: Date.now(), flow: 'web-analytics' });
    res.cookie('smart_monitoring_google_state', state, { httpOnly: true, secure: redirectUri.startsWith('https://'), sameSite: 'lax', maxAge: OAUTH_STATE_TTL_MS, path: '/api/auth/google' });
    return res.redirect(302, buildGoogleAuthUrl(redirectUri, state));
  } catch (error) {
    console.error('Auth /google start error:', error);
    return res.status(500).json({ success: false, message: 'Unable to start Google sign-in.' });
  }
});

router.get('/google/status', async (req, res) => {
  const state = req.query.state?.toString();
  if (!state) return res.status(400).json({ success: false, message: 'OAuth state is required.' });
  const entry = oauthStateStore.get(state);
  if (!entry || entry.flow === 'web-analytics') return res.json({ success: false, status: 'pending' });
  oauthStateStore.delete(state);
  return res.json({ success: true, status: 'complete', token: entry.token, user: entry.user });
});

router.get('/google/callback', async (req, res) => {
  const { code, state, error: providerError } = req.query;
  const stateEntry = typeof state === 'string' ? oauthStateStore.get(state) : null;
  const isWebAnalytics = stateEntry?.flow === 'web-analytics';
  if (isWebAnalytics) {
    const fail = (status, message) => {
      res.clearCookie('smart_monitoring_google_state', { path: '/api/auth/google' });
      if (redirectToWebAnalytics(res, { error: 'google_sign_in_failed', error_description: message })) return;
      return res.status(status).send(message);
    };
    if (providerError) return fail(401, 'Google sign-in was cancelled or denied.');
    if (!code || !state || typeof state !== 'string') return fail(400, 'Invalid Google sign-in response.');
    const stateCookie = readCookie(req, 'smart_monitoring_google_state');
    oauthStateStore.delete(state);
    res.clearCookie('smart_monitoring_google_state', { path: '/api/auth/google' });
    if (stateCookie !== state) return fail(400, 'Google sign-in session is invalid or expired.');
    try {
      const redirectUri = googleCallbackUri();
      if (!redirectUri) throw authError(500, 'Google callback URL is not configured.');
      const tokenResponse = await exchangeGoogleCode(String(code), redirectUri);
      if (!tokenResponse.id_token) throw authError(401, 'Google did not return an ID token.');
      const user = await findAnalyticsUserByEmail((await verifyGoogleIdToken(tokenResponse.id_token)).email);
      await execute('UPDATE users SET last_login_at = NOW() WHERE id = ? AND business_id = ?', [user.id, user.business_id]);
      const exchangeCode = randomBytes(32).toString('base64url');
      oauthExchangeStore.set(createHash('sha256').update(exchangeCode).digest('hex'), { userId: user.id, businessId: user.business_id, expiresAt: Date.now() + OAUTH_EXCHANGE_TTL_MS });
      if (redirectToWebAnalytics(res, { code: exchangeCode })) return;
      return res.status(500).send('Web Analytics callback URL is not configured.');
    } catch (error) {
      console.error('Auth /google/callback (analytics) error:', error);
      return fail(error.status || 500, error.message || 'Google sign-in failed.');
    }
  }
  // Legacy Smart Monitoring callback: preserve the original polling flow.
  if (providerError) return res.status(401).send('Google login was cancelled or denied.');
  if (!code) return res.status(400).send('Missing authorization code.');
  try {
    const redirectUri = googleCallbackUri();
    if (!redirectUri) return res.status(400).send('Redirect URI is not configured.');
    const tokenResponse = await exchangeGoogleCode(String(code), redirectUri);
    if (!tokenResponse.id_token) return res.status(401).send('Google did not return an ID token.');
    const authResponse = issueAppSession(await verifyGoogleIdToken(tokenResponse.id_token));
    if (state && typeof state === 'string') oauthStateStore.set(state, { ...authResponse, createdAt: Date.now(), flow: 'smart-monitoring' });
    return res.send('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Authentication Successful</title></head><body style="font-family: Arial, sans-serif; text-align: center; padding: 40px;"><h1>Authentication Successful</h1><p>You may now return to the app.</p></body></html>');
  } catch (error) {
    console.error('Auth /google/callback (legacy) error:', error);
    return res.status(500).send('Google login failed. Please try again.');
  }
});

router.post('/google/exchange', async (req, res) => {
  const { code, redirectUri } = req.body || {};
  if (!code) return res.status(400).json({ success: false, message: 'Authorization code is required.' });
  if (redirectUri) {
    try {
      const resolvedRedirectUri = normalizeRedirectUri(redirectUri || GOOGLE_BACKEND_REDIRECT_URI || GOOGLE_DEFAULT_REDIRECT_URI);
      const tokenResponse = await exchangeGoogleCode(code, resolvedRedirectUri);
      if (!tokenResponse.id_token) return res.status(401).json({ success: false, message: 'Google did not return an ID token.' });
      return res.json(issueAppSession(await verifyGoogleIdToken(tokenResponse.id_token)));
    } catch (error) {
      console.error('Auth /google/exchange (legacy) error:', error);
      return res.status(401).json({ success: false, message: 'Google code exchange failed: ' + error.message });
    }
  }
  const exchangeCode = String(code).trim();
  const codeHash = createHash('sha256').update(exchangeCode).digest('hex');
  const entry = oauthExchangeStore.get(codeHash);
  oauthExchangeStore.delete(codeHash);
  if (!entry || Date.now() >= entry.expiresAt) return res.status(401).json({ success: false, message: 'Authorization code is invalid, expired, or already used.' });
  try { return res.json(issueAnalyticsSession(await findAnalyticsUserById(entry.userId, entry.businessId))); }
  catch (error) {
    console.error('Auth /google/exchange (analytics) error:', error);
    return res.status(error.status || 500).json({ success: false, message: error.message || 'Google sign-in could not be completed.' });
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
