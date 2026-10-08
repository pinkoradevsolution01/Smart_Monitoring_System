const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'sync-route-test-secret';
process.env.JWT_ISSUER = 'smart-monitoring-api';
process.env.JWT_AUDIENCE = 'smart-monitoring-clients';

function ownerToken() {
  return jwt.sign(
    { userId: 'owner-a', role: 'owner', businessId: 'business-a' },
    process.env.JWT_SECRET,
    {
      algorithm: 'HS256',
      audience: process.env.JWT_AUDIENCE,
      issuer: process.env.JWT_ISSUER,
      expiresIn: '1h',
    },
  );
}

function loadRouter(db) {
  const dbPath = require.resolve('../db');
  const routePath = require.resolve('../routes/sync');
  const sessionPath = require.resolve('../security/session_tokens');
  const previousDb = require.cache[dbPath];
  const previousRoute = require.cache[routePath];
  const previousSession = require.cache[sessionPath];
  delete require.cache[sessionPath];
  require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
  delete require.cache[routePath];
  const router = require('../routes/sync');
  const { attachOptionalSession } = require('../security/session_tokens');

  return {
    router,
    attachOptionalSession,
    restore() {
      delete require.cache[routePath];
      if (previousRoute) require.cache[routePath] = previousRoute;
      if (previousDb) require.cache[dbPath] = previousDb;
      else delete require.cache[dbPath];
      if (previousSession) require.cache[sessionPath] = previousSession;
      else delete require.cache[sessionPath];
    },
  };
}

async function withServer(loaded, run) {
  const app = express();
  app.use(express.json());
  app.use(loaded.attachOptionalSession);
  app.use('/api/sync', loaded.router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
}

test('sync normalizes ISO timestamps and resolves loyalty records using customer_code', async () => {
  const executions = [];
  const connection = {
    async beginTransaction() {},
    async commit() {},
    async rollback() {},
    release() {},
    async execute(sql, params = []) {
      executions.push({ sql, params });
      if (sql.includes('SELECT id FROM customers')) return [[{ id: 42 }], []];
      return [[], []];
    },
  };
  const db = {
    async query(sql) {
      if (sql.includes('FROM users u INNER JOIN businesses b')) {
        return [{ business_id: 'business-a', role: 'owner' }];
      }
      if (sql.includes('SELECT id FROM businesses')) return [{ id: 'business-a' }];
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    async getConnection() {
      return connection;
    },
  };
  const loaded = loadRouter(db);

  try {
    await withServer(loaded, async (base) => {
      const response = await fetch(`${base}/api/sync/push`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${ownerToken()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          businessId: 'business-a',
          loyaltyLedger: [{
            business_id: 'business-a',
            customer_code: 'customer-a',
            client_entry_id: 'ledger-a',
            entry_type: 'earn',
            points: 5,
            balance_after: 5,
            created_at: '2026-10-04T10:42:35.094Z',
          }],
          purchaseOrderItems: [{
            business_id: 'business-a',
            id: 1,
            order_id: 'order-a',
            product_id: 'product-a',
            product_name: 'Product A',
            quantity: 1,
            unit_price: 10,
            total_price: 10,
            created_at: '2026-10-04T10:42:35.094Z',
          }],
        }),
      });

      assert.equal(response.status, 200);
      const loyaltyInsert = executions.find((call) =>
        call.sql.includes('INSERT INTO loyalty_ledger'),
      );
      assert.equal(loyaltyInsert.params[0], 'ledger-a');
      assert.equal(loyaltyInsert.params[2], 42);
      assert.equal(loyaltyInsert.params[8], '2026-10-04 10:42:35');

      const purchaseItemInsert = executions.find((call) =>
        call.sql.includes('INSERT INTO purchase_order_items'),
      );
      assert.equal(purchaseItemInsert.params[8], '2026-10-04 10:42:35');
    });
  } finally {
    loaded.restore();
  }
});
