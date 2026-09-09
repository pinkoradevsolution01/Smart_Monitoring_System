const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'crud-authorization-test-secret';
process.env.JWT_ISSUER = 'smart-monitoring-api';
process.env.JWT_AUDIENCE = 'smart-monitoring-clients';

function token(claims) {
  return jwt.sign(claims, process.env.JWT_SECRET, {
    algorithm: 'HS256', audience: process.env.JWT_AUDIENCE, expiresIn: '12h', issuer: process.env.JWT_ISSUER,
  });
}

function loadCrudRouter(db) {
  const dbPath = require.resolve('../db');
  const accessPath = require.resolve('../security/business_access');
  const routePath = require.resolve('../routes/crud');
  const originals = new Map([[dbPath, require.cache[dbPath]], [accessPath, require.cache[accessPath]], [routePath, require.cache[routePath]]]);
  require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
  delete require.cache[accessPath];
  delete require.cache[routePath];
  const router = require('../routes/crud');
  return {
    router,
    restore() {
      for (const [path, cached] of originals) {
        if (cached) require.cache[path] = cached;
        else delete require.cache[path];
      }
    },
  };
}

async function withServer(router, run) {
  const { attachOptionalSession } = require('../security/session_tokens');
  const app = express();
  app.use(express.json());
  app.use(attachOptionalSession);
  app.use('/api', router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test('generic business CRUD requires a management session and ignores a supplied businessId', async () => {
  const calls = [];
  const db = {
    async query(sql, params = []) {
      calls.push({ sql, params });
      if (sql.includes('FROM users u INNER JOIN businesses b')) {
        return [{ id: 'owner-a', business_id: 'business-a', role: 'owner', user_active: 1, business_active: 1 }];
      }
      if (sql.includes('SELECT * FROM products')) return [];
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    getConnection: async () => { throw new Error('not expected for GET'); },
  };
  const loaded = loadCrudRouter(db);
  const ownerToken = token({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });
  const cashierToken = token({ userId: 'owner-a', role: 'cashier', businessId: 'business-a' });

  try {
    await withServer(loaded.router, async (base) => {
      const missing = await fetch(`${base}/api/products`);
      assert.equal(missing.status, 401);

      const list = await fetch(`${base}/api/products?businessId=business-b`, {
        headers: { Authorization: `Bearer ${ownerToken}` },
      });
      assert.equal(list.status, 200);
      assert.deepEqual((await list.json()).data, []);

      const cashier = await fetch(`${base}/api/products`, {
        headers: { Authorization: `Bearer ${cashierToken}` },
      });
      assert.equal(cashier.status, 403);
    });
    for (const call of calls) assert.equal(call.params.includes('business-b'), false);
  } finally {
    loaded.restore();
  }
});
