const { query } = require('../db');

const MANAGEMENT_ROLES = new Set(['owner', 'admin', 'manager']);

/**
 * Resolves the business context from a verified session. Client-provided
 * business IDs are deliberately ignored: they are selectors, not authority.
 */
async function requireActiveBusiness(req, res, next) {
  const auth = req.auth;
  if (!auth?.userId || !auth?.businessId) {
    return res.status(401).json({ success: false, message: 'A valid business session is required.' });
  }

  try {
    const rows = await query(
      `SELECT u.id, u.business_id, u.role, u.is_active AS user_active,
              b.is_active AS business_active
       FROM users u INNER JOIN businesses b ON b.id = u.business_id
       WHERE u.id = ? AND u.business_id = ? LIMIT 1`,
      [auth.userId, auth.businessId],
    );
    const user = rows[0];
    const databaseRole = String(user?.role || '').toLowerCase();
    const tokenRole = String(auth.role || '').toLowerCase();
    if (!user || (user.user_active ?? 1) !== 1 || (user.business_active ?? 1) !== 1) {
      return res.status(403).json({ success: false, message: 'The account or business is inactive.' });
    }
    if (!databaseRole || databaseRole !== tokenRole) {
      return res.status(403).json({ success: false, message: 'The signed-in role is no longer authorized.' });
    }

    req.businessContext = { businessId: user.business_id, role: databaseRole, userId: user.id };
    return next();
  } catch (error) {
    console.error('Business access verification error:', error);
    return res.status(500).json({ success: false, message: 'Failed to verify business access.' });
  }
}

function requireManagementRole(req, res, next) {
  if (!MANAGEMENT_ROLES.has(req.businessContext?.role)) {
    return res.status(403).json({ success: false, message: 'Management access is required.' });
  }
  return next();
}

module.exports = { MANAGEMENT_ROLES, requireActiveBusiness, requireManagementRole };
