const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'financial-reports-test-secret';
process.env.JWT_ISSUER = 'smart-monitoring-api';
process.env.JWT_AUDIENCE = 'smart-monitoring-clients';

function token(claims, overrides = {}) {
  return jwt.sign(claims, process.env.JWT_SECRET, {
    algorithm: 'HS256',
    audience: overrides.audience || process.env.JWT_AUDIENCE,
    issuer: overrides.issuer || process.env.JWT_ISSUER,
    expiresIn: '12h',
  });
}

function loadRouter(db) {
  const dbPath = require.resolve('../db');
  const accessPath = require.resolve('../security/business_access');
  const routePath = require.resolve('../routes/financial_reports');
  const original = new Map([
    [dbPath, require.cache[dbPath]],
    [accessPath, require.cache[accessPath]],
    [routePath, require.cache[routePath]],
  ]);
  require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
  delete require.cache[accessPath];
  delete require.cache[routePath];
  const router = require('../routes/financial_reports');
  return {
    router,
    restore() {
      for (const [file, entry] of original) {
        if (entry) require.cache[file] = entry;
        else delete require.cache[file];
      }
    },
  };
}

async function withServer(router, run) {
  const { attachOptionalSession } = require('../security/session_tokens');
  const app = express();
  app.use(attachOptionalSession);
  app.use('/api/financial-reports', router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

function database(calls, subscriptionPackage = 'Standard') {
  return {
    async query(sql, params = []) {
      calls.push({ sql, params });
      if (sql.includes('FROM users u INNER JOIN businesses b')) {
        return [{
          id: 'owner-a', business_id: 'business-a', role: 'owner', user_active: 1,
          business_active: 1, subscription_package: subscriptionPackage, subscription_expires_at: null,
        }];
      }
      if (sql.includes("status = 'cancelled'")) return [{ cancelled_transactions: 0, cancelled_amount: 0 }];
      if (sql.includes('SUM(subtotal)')) return [{ gross_sales: 120, discounts: 5, net_sales: 115, completed_transactions: 1 }];
      if (sql.includes('GROUP BY payment_method')) return [{ payment_method: 'Cash', transactions: 1, total: 115 }];
      if (sql.includes('FROM expenses') && sql.includes('GROUP BY category')) return [{ category: 'Utilities', total: 20 }];
      if (sql.includes('FROM expenses')) return [{ operating_expenses: 20, input_tax: 2 }];
      if (sql.includes('FROM sale_items')) return [{ estimated_cogs: 50 }];
      if (sql.includes('SELECT id, datetime')) return [{ id: '=spreadsheet-formula', datetime: '2026-09-01 10:00:00', reference_code: 'OR-1', cashier_name: 'Owner', customer_name: 'Customer', payment_method: 'Cash', subtotal: 120, discount: 5, total_amount: 115 }];
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };
}

test('financial reports derive the tenant only from the verified JWT and protect CSV cells', async () => {
  const calls = [];
  const loaded = loadRouter(database(calls));
  const owner = token({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });
  try {
    await withServer(loaded.router, async (base) => {
      const summary = await fetch(`${base}/api/financial-reports/summary?from=2026-09-01&to=2026-09-01&businessId=business-b`, {
        headers: { Authorization: `Bearer ${owner}` },
      });
      assert.equal(summary.status, 200);
      const body = await summary.json();
      assert.equal(body.data.zReading.netSales, 115);
      assert.equal(body.data.profitAnalysis.estimatedProfit, 45);

      const csv = await fetch(`${base}/api/financial-reports/export?from=2026-09-01&to=2026-09-01&businessId=business-b`, {
        headers: { Authorization: `Bearer ${owner}` },
      });
      assert.equal(csv.status, 200);
      assert.match(csv.headers.get('content-type') || '', /^text\/csv/);
      assert.match(await csv.text(), /'=spreadsheet-formula/);
    });
    for (const call of calls) assert.equal(call.params.includes('business-b'), false);
  } finally {
    loaded.restore();
  }
});

test('financial reports reject missing tokens, non-management roles, and Basic subscriptions', async () => {
  const owner = token({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });
  const cashier = token({ userId: 'owner-a', role: 'cashier', businessId: 'business-a' });
  const standard = loadRouter(database([]));
  try {
    await withServer(standard.router, async (base) => {
      assert.equal((await fetch(`${base}/api/financial-reports/summary`)).status, 401);
      assert.equal((await fetch(`${base}/api/financial-reports/summary`, { headers: { Authorization: `Bearer ${cashier}` } })).status, 403);
    });
  } finally {
    standard.restore();
  }

  const basic = loadRouter(database([], 'Basic'));
  try {
    await withServer(basic.router, async (base) => {
      const response = await fetch(`${base}/api/financial-reports/summary`, { headers: { Authorization: `Bearer ${owner}` } });
      assert.equal(response.status, 403);
      assert.match((await response.json()).message, /Standard, Premium, or Enterprise/);
    });
  } finally {
    basic.restore();
  }
});
