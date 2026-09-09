const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'analytics-integration-test-secret';
process.env.JWT_SECRET = JWT_SECRET;
process.env.JWT_ISSUER = 'smart-monitoring-api';
process.env.JWT_AUDIENCE = 'smart-monitoring-clients';

function signTestSession(claims, overrides = {}) {
  return jwt.sign(claims, JWT_SECRET, {
    algorithm: 'HS256',
    audience: overrides.audience || process.env.JWT_AUDIENCE,
    expiresIn: overrides.expiresIn || '12h',
    issuer: overrides.issuer || process.env.JWT_ISSUER,
  });
}

function loadRouter(routeName, db) {
  const dbPath = require.resolve('../db');
  const routePath = require.resolve(`../routes/${routeName}`);
  const originalDb = require.cache[dbPath];
  const originalRoute = require.cache[routePath];
  require.cache[dbPath] = {
    id: dbPath,
    filename: dbPath,
    loaded: true,
    exports: db,
  };
  delete require.cache[routePath];
  const router = require(`../routes/${routeName}`);

  return {
    router,
    restore() {
      delete require.cache[routePath];
      if (originalRoute) require.cache[routePath] = originalRoute;
      if (originalDb) require.cache[dbPath] = originalDb;
      else delete require.cache[dbPath];
    },
  };
}

async function withServer(router, prefix, run) {
  const app = express();
  app.use(express.json());
  app.use(prefix, router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  try {
    return await run(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

function analyticsDb(calls) {
  return {
    async query(sql, params = []) {
      calls.push({ sql, params });
      if (sql.includes('FROM users u INNER JOIN businesses b')) {
        assert.deepEqual(params, ['owner-a', 'business-a']);
        return [{ id: 'owner-a', name: 'Business A', user_role: 'owner', user_active: 1, business_active: 1 }];
      }
      if (sql.includes('SUM(subtotal)')) return [{ grossSales: 120, discounts: 5, netSales: 115, transactions: 1, averageOrderValue: 115, itemsSold: 2 }];
      if (sql.includes('COUNT(*) activeCustomers')) return [{ activeCustomers: 4 }];
      if (sql.includes('COUNT(*) lowStockCount')) return [{ lowStockCount: 1 }];
      if (sql.includes('GROUP BY DATE(datetime)')) return [];
      if (sql.includes('GROUP BY payment_method')) return [];
      if (sql.includes('FROM sale_items')) return [];
      if (sql.includes('low_stock_threshold')) return [];
      if (sql.includes('SELECT id, datetime, cashier_name')) {
        assert.deepEqual(params, ['business-a', '2026-08-01', '2026-08-31']);
        return [{ id: '=cmd', datetime: '2026-08-01 10:00:00', cashier_name: 'Owner', payment_method: 'Cash', status: 'completed', subtotal: 100, discount: 0, total_amount: 100 }];
      }
      throw new Error(`Unexpected SQL in analytics test: ${sql}`);
    },
  };
}

test('analytics ignores a browser-supplied businessId and scopes overview and CSV to the JWT tenant', async () => {
  const calls = [];
  const loaded = loadRouter('analytics', analyticsDb(calls));
  const ownerToken = signTestSession({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });

  try {
    await withServer(loaded.router, '/api/analytics', async (base) => {
      const overview = await fetch(`${base}/api/analytics/overview?from=2026-08-01&to=2026-08-30&businessId=business-b`, {
        headers: { Authorization: `Bearer ${ownerToken}` },
      });
      assert.equal(overview.status, 200);
      const overviewBody = await overview.json();
      assert.equal(overviewBody.meta.businessId, 'business-a');
      assert.equal(overviewBody.meta.businessName, 'Business A');

      const csv = await fetch(`${base}/api/analytics/export?report=sales&from=2026-08-01&to=2026-08-30&businessId=business-b`, {
        headers: { Authorization: `Bearer ${ownerToken}` },
      });
      assert.equal(csv.status, 200);
      assert.match(csv.headers.get('content-type') || '', /^text\/csv/);
      assert.match(csv.headers.get('content-disposition') || '', /sales-2026-08-01-to-2026-08-30\.csv/);
      assert.match(await csv.text(), /"'=cmd"/);

      for (const call of calls) assert.equal(call.params.includes('business-b'), false);
    });
  } finally {
    loaded.restore();
  }
});

test('analytics rejects missing tokens and roles outside the analytics allow-list', async () => {
  const calls = [];
  const loaded = loadRouter('analytics', analyticsDb(calls));
  const cashierToken = signTestSession({ userId: 'cashier-a', role: 'cashier', businessId: 'business-a' });
  const wrongAudienceToken = signTestSession(
    { userId: 'owner-a', role: 'owner', businessId: 'business-a' },
    { audience: 'another-api' },
  );

  try {
    await withServer(loaded.router, '/api/analytics', async (base) => {
      const missing = await fetch(`${base}/api/analytics/overview`);
      assert.equal(missing.status, 401);
      const forbidden = await fetch(`${base}/api/analytics/overview`, {
        headers: { Authorization: `Bearer ${cashierToken}` },
      });
      assert.equal(forbidden.status, 403);
      const wrongAudience = await fetch(`${base}/api/analytics/overview`, {
        headers: { Authorization: `Bearer ${wrongAudienceToken}` },
      });
      assert.equal(wrongAudience.status, 401);
      assert.equal(calls.length, 0);
    });
  } finally {
    loaded.restore();
  }
});

test('Google analytics login redirects with a one-time code and exchanges it for a tenant JWT', async () => {
  process.env.GOOGLE_CLIENT_ID = 'google-client-id';
  process.env.GOOGLE_CLIENT_SECRET = 'google-client-secret';
  process.env.GOOGLE_CALLBACK_URL = 'http://127.0.0.1:3000/api/auth/google/callback';
  process.env.WEB_ANALYTICS_URL = 'https://analytics.smartmonitoringsystem.store';

  const db = {
    async query(sql, params = []) {
      if (sql.includes('FROM cancelled_subscribers')) {
        assert.equal(params[0], 'owner@example.com');
        return [];
      }
      if (sql.includes('FROM users u INNER JOIN businesses b')) {
        return [{ id: 'owner-a', business_id: 'business-a', email: 'owner@example.com', role: 'owner', full_name: 'Owner A', contact_number: null, business_is_active: 1 }];
      }
      throw new Error(`Unexpected SQL in Google-login test: ${sql}`);
    },
    async execute(sql, params = []) {
      assert.match(sql, /UPDATE users SET last_login_at/);
      assert.deepEqual(params, ['owner-a', 'business-a']);
      return { affectedRows: 1 };
    },
  };
  const originalFetch = global.fetch;
  global.fetch = async (url, options) => {
    const target = String(url);
    if (target.startsWith('http://127.0.0.1:')) return originalFetch(url, options);
    if (target.startsWith('https://oauth2.googleapis.com/tokeninfo')) {
      return { ok: true, json: async () => ({ email: 'owner@example.com', sub: 'google-owner-a', email_verified: 'true', aud: 'google-client-id', iss: 'https://accounts.google.com' }) };
    }
    if (target.startsWith('https://oauth2.googleapis.com/token')) {
      return { ok: true, json: async () => ({ id_token: 'verified-google-token' }) };
    }
    throw new Error(`Unexpected outgoing request: ${target}`);
  };
  const loaded = loadRouter('auth', db);

  try {
    await withServer(loaded.router, '/api/auth', async (base) => {
      const start = await fetch(`${base}/api/auth/google`, { redirect: 'manual' });
      assert.equal(start.status, 302);
      const googleUrl = new URL(start.headers.get('location'));
      const state = googleUrl.searchParams.get('state');
      assert.ok(state);
      const cookie = start.headers.get('set-cookie');
      assert.match(cookie || '', /smart_monitoring_google_state=/);

      const callback = await fetch(`${base}/api/auth/google/callback?code=google-code&state=${encodeURIComponent(state)}`, {
        redirect: 'manual',
        headers: { Cookie: String(cookie).split(';')[0] },
      });
      assert.equal(callback.status, 302);
      const browserCallback = new URL(callback.headers.get('location'));
      assert.equal(browserCallback.origin, 'https://analytics.smartmonitoringsystem.store');
      assert.equal(browserCallback.pathname, '/auth/google/callback');
      const oneTimeCode = browserCallback.searchParams.get('code');
      assert.ok(oneTimeCode);

      const exchange = await fetch(`${base}/api/auth/google/exchange`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: oneTimeCode }),
      });
      assert.equal(exchange.status, 200);
      const session = await exchange.json();
      const claims = jwt.verify(session.token, JWT_SECRET, {
        algorithms: ['HS256'], audience: process.env.JWT_AUDIENCE, issuer: process.env.JWT_ISSUER,
      });
      assert.equal(claims.userId, 'owner-a');
      assert.equal(claims.role, 'owner');
      assert.equal(claims.businessId, 'business-a');

      const replay = await fetch(`${base}/api/auth/google/exchange`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ code: oneTimeCode }),
      });
      assert.equal(replay.status, 401);
    });
  } finally {
    global.fetch = originalFetch;
    loaded.restore();
  }
});
