const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || '';
const JWT_ISSUER = process.env.JWT_ISSUER || 'smart-monitoring-api';
const JWT_AUDIENCE = process.env.JWT_AUDIENCE || 'smart-monitoring-clients';
const JWT_ALGORITHM = 'HS256';

function configuredSecret() {
  if (!JWT_SECRET) {
    throw new Error('JWT_SECRET is not configured.');
  }
  return JWT_SECRET;
}

function signSession(claims, { expiresIn = '12h' } = {}) {
  return jwt.sign(claims, configuredSecret(), {
    algorithm: JWT_ALGORITHM,
    audience: JWT_AUDIENCE,
    expiresIn,
    issuer: JWT_ISSUER,
  });
}

function verifySession(token) {
  return jwt.verify(token, configuredSecret(), {
    algorithms: [JWT_ALGORITHM],
    audience: JWT_AUDIENCE,
    issuer: JWT_ISSUER,
  });
}

function tokenFromRequest(req) {
  return String(req.headers.authorization || '').match(/^Bearer\s+(.+)$/i)?.[1] || null;
}

function attachOptionalSession(req, _res, next) {
  const token = tokenFromRequest(req);
  if (!token) return next();

  try {
    req.auth = verifySession(token);
  } catch (_) {
    req.auth = null;
  }
  return next();
}

module.exports = {
  JWT_AUDIENCE,
  JWT_ISSUER,
  attachOptionalSession,
  signSession,
  tokenFromRequest,
  verifySession,
};
