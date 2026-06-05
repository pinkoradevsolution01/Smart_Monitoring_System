const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../db');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret';
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || '';
const GOOGLE_DEFAULT_REDIRECT_URI = process.env.GOOGLE_REDIRECT_URI || '';

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
    redirect_uri: redirectUri,
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
  if (!email || !password) {
    return res.status(400).json({ success: false, message: 'Email and password are required.' });
  }

  try {
    const rows = await query('SELECT id, email, password_hash, role, full_name FROM users WHERE email = ?', [email]);
    if (!rows.length) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }

    const user = rows[0];
    const passwordMatches = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatches) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
    }

    const token = jwt.sign(
      { userId: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '12h' },
    );

    return res.json({
      success: true,
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        fullName: user.full_name,
      },
    });
  } catch (error) {
    console.error('Auth /login error:', error);
    return res.status(500).json({ success: false, message: 'Login failed due to server error.' });
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
    const resolvedRedirectUri = redirectUri || GOOGLE_DEFAULT_REDIRECT_URI;
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
    return res.status(500).json({ success: false, message: 'Failed to build Google auth URL.' });
  }
});

router.post('/google/exchange', async (req, res) => {
  const { code, redirectUri } = req.body;
  if (!code) {
    return res.status(400).json({ success: false, message: 'Authorization code is required.' });
  }

  try {
    const resolvedRedirectUri = redirectUri || GOOGLE_DEFAULT_REDIRECT_URI;
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
    return res.status(401).json({ success: false, message: 'Google code exchange failed.' });
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
