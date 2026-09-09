const { query } = require('../db');
const { tokenFromRequest, verifySession } = require('./session_tokens');

/**
 * Guards the global developer-administration surface.  Developer operations
 * are deliberately not tenant-scoped, so a normal business owner/admin token
 * must never be accepted here.
 */
async function requireDeveloperSession(req, res, next) {
  const token = tokenFromRequest(req);
  if (!token) {
    return res.status(401).json({ success: false, message: 'Missing authorization token.' });
  }

  let auth;
  try {
    auth = verifySession(token);
  } catch (_) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token.' });
  }

  if (String(auth.role || '').toLowerCase() !== 'developer' || String(auth.userId || '') !== 'primary') {
    return res.status(403).json({ success: false, message: 'Developer access is required.' });
  }

  try {
    const rows = await query(
      'SELECT id, email, is_active FROM developer_accounts WHERE id = ? LIMIT 1',
      ['primary'],
    );
    const account = rows[0];
    if (!account || (account.is_active ?? 1) !== 1) {
      return res.status(403).json({ success: false, message: 'The developer account is inactive.' });
    }

    req.developer = { id: account.id, email: account.email };
    return next();
  } catch (error) {
    console.error('Developer session verification error:', error);
    return res.status(500).json({ success: false, message: 'Failed to verify developer access.' });
  }
}

module.exports = { requireDeveloperSession };
