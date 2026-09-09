const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'developer-authorization-test-secret';
process.env.JWT_ISSUER = 'smart-monitoring-api';
process.env.JWT_AUDIENCE = 'smart-monitoring-clients';

function session(claims) {
  return jwt.sign(claims, process.env.JWT_SECRET, {
    algorithm: 'HS256',
    audience: process.env.JWT_AUDIENCE,
    expiresIn: '12h',
    issuer: process.env.JWT_ISSUER,
  });
}

function loadRouter(routeName, db) {
  const dbPath = require.resolve('../db');
  const accessPath = require.resolve('../security/developer_access');
  const routePath = require.resolve(`../routes/${routeName}`);
  const originalDb = require.cache[dbPath];
  const originalAccess = require.cache[accessPath];
  const originalRoute = require.cache[routePath];
  require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
  delete require.cache[accessPath];
  delete require.cache[routePath];
  const router = require(`../routes/${routeName}`);
  return {
    router,
    restore() {
      if (originalDb) require.cache[dbPath] = originalDb;
      else delete require.cache[dbPath];
      if (originalAccess) require.cache[accessPath] = originalAccess;
      else delete require.cache[accessPath];
      if (originalRoute) require.cache[routePath] = originalRoute;
      else delete require.cache[routePath];
    },
  };
}

async function withServer(prefix, router, run) {
  const app = express();
  app.use(express.json());
  app.use(prefix, router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

const developerDb = {
  async query(sql) {
    if (sql.includes('FROM developer_accounts WHERE id = ?')) {
      return [{
        id: 'primary', display_name: 'Developer', email: 'dev@example.com',
        password_hash: 'hash', auth_method: 'password', google_sub: null,
        avatar_url: null, is_active: 1, created_at: null, updated_at: null,
      }];
    }
    throw new Error(`Unexpected SQL: ${sql}`);
  },
};

test('developer account routes require an active developer JWT', async () => {
  const loaded = loadRouter('developer', developerDb);
  const owner = session({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });
  const developer = session({ userId: 'primary', role: 'developer' });
  try {
    await withServer('/api/developer', loaded.router, async (base) => {
      const missing = await fetch(`${base}/api/developer/account`);
      assert.equal(missing.status, 401);

      const denied = await fetch(`${base}/api/developer/account`, {
        headers: { Authorization: `Bearer ${owner}` },
      });
      assert.equal(denied.status, 403);

      const allowed = await fetch(`${base}/api/developer/account`, {
        headers: { Authorization: `Bearer ${developer}` },
      });
      assert.equal(allowed.status, 200);

      const unverifiedGoogle = await fetch(`${base}/api/developer/google/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'dev@example.com', googleSub: 'spoofed' }),
      });
      assert.equal(unverifiedGoogle.status, 401);

      const mismatchedGoogle = await fetch(`${base}/api/developer/google/register`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${owner}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'dev@example.com', googleSub: 'spoofed' }),
      });
      assert.equal(mismatchedGoogle.status, 403);
    });
  } finally {
    loaded.restore();
  }
});

test('subscriber purge rejects missing and non-developer sessions before any deletion', async () => {
  const loaded = loadRouter('business', developerDb);
  const owner = session({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });
  try {
    await withServer('/api/business', loaded.router, async (base) => {
      const missing = await fetch(`${base}/api/business/purge?businessId=business-a`, { method: 'DELETE' });
      assert.equal(missing.status, 401);

      const denied = await fetch(`${base}/api/business/purge?businessId=business-a`, {
        method: 'DELETE', headers: { Authorization: `Bearer ${owner}` },
      });
      assert.equal(denied.status, 403);
    });
  } finally {
    loaded.restore();
  }
});
