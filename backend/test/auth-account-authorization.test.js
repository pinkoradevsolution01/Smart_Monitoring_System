const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'auth-account-authorization-test-secret';
process.env.JWT_ISSUER = 'smart-monitoring-api';
process.env.JWT_AUDIENCE = 'smart-monitoring-clients';

function session(claims) {
  return jwt.sign(claims, process.env.JWT_SECRET, {
    algorithm: 'HS256', audience: process.env.JWT_AUDIENCE, expiresIn: '12h', issuer: process.env.JWT_ISSUER,
  });
}

function loadAuthRouter(db) {
  const dbPath = require.resolve('../db');
  const routePath = require.resolve('../routes/auth');
  const originalDb = require.cache[dbPath];
  const originalRoute = require.cache[routePath];
  require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
  delete require.cache[routePath];
  const router = require('../routes/auth');
  return {
    router,
    restore() {
      if (originalDb) require.cache[dbPath] = originalDb;
      else delete require.cache[dbPath];
      if (originalRoute) require.cache[routePath] = originalRoute;
      else delete require.cache[routePath];
    },
  };
}

async function withServer(router, run) {
  const app = express();
  app.use(express.json());
  app.use('/api/auth', router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test('account management rejects unauthenticated and non-management users without trusting a supplied businessId', async () => {
  const calls = [];
  const db = {
    async query(sql, params = []) {
      calls.push({ sql, params });
      if (sql.includes('FROM users u INNER JOIN businesses b')) {
        const role = params[0] === 'cashier-a' ? 'cashier' : 'owner';
        return [{ id: params[0], business_id: 'business-a', role, user_active: 1, business_active: 1 }];
      }
      if (sql.includes('FROM users WHERE id = ? AND business_id = ?')) return [];
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };
  const loaded = loadAuthRouter(db);
  const owner = session({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });
  const cashier = session({ userId: 'cashier-a', role: 'cashier', businessId: 'business-a' });

  try {
    await withServer(loaded.router, async (base) => {
      const missing = await fetch(`${base}/api/auth/users/user-b`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: '{}' });
      assert.equal(missing.status, 401);

      const denied = await fetch(`${base}/api/auth/users/user-b`, {
        method: 'PATCH', headers: { Authorization: `Bearer ${cashier}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ businessId: 'business-b', fullName: 'Attempt' }),
      });
      assert.equal(denied.status, 403);

      const otherTenant = await fetch(`${base}/api/auth/users/user-b`, {
        method: 'PATCH', headers: { Authorization: `Bearer ${owner}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ businessId: 'business-b', fullName: 'Attempt' }),
      });
      assert.equal(otherTenant.status, 404);
    });
    for (const call of calls) assert.equal(call.params.includes('business-b'), false);
  } finally {
    loaded.restore();
  }
});
