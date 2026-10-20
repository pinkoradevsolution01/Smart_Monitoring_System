const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const express = require('express');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'smartplus-dismiss-test-secret';
process.env.JWT_ISSUER = 'smart-monitoring-api';
process.env.JWT_AUDIENCE = 'smart-monitoring-clients';

function token(claims) {
  return jwt.sign(claims, process.env.JWT_SECRET, {
    algorithm: 'HS256',
    audience: process.env.JWT_AUDIENCE,
    expiresIn: '12h',
    issuer: process.env.JWT_ISSUER,
  });
}

function loadRouter(db) {
  const dbPath = require.resolve('../db');
  const accessPath = require.resolve('../security/business_access');
  const routePath = require.resolve('../routes/smartplus');
  const originals = new Map([
    [dbPath, require.cache[dbPath]],
    [accessPath, require.cache[accessPath]],
    [routePath, require.cache[routePath]],
  ]);
  require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
  delete require.cache[accessPath];
  delete require.cache[routePath];
  const router = require('../routes/smartplus');
  return {
    router,
    restore() {
      for (const [file, entry] of originals) {
        if (entry) require.cache[file] = entry;
        else delete require.cache[file];
      }
    },
  };
}

async function withServer(router, run) {
  const { attachOptionalSession } = require('../security/session_tokens');
  const app = express();
  app.use(express.json());
  app.use(attachOptionalSession);
  app.use('/api/smartplus', router);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test('only the owner can dismiss their tenant SmartPlus task, preserving an audit record', async () => {
  const calls = [];
  let status = 'draft';
  const db = {
    async query(sql, params = []) {
      calls.push({ type: 'query', sql, params });
      if (sql.includes('FROM users u INNER JOIN businesses b')) {
        const isCashier = params[0] === 'cashier-a';
        return [{
          id: params[0], business_id: 'business-a',
          role: isCashier ? 'cashier' : 'owner',
          user_active: 1, business_active: 1,
          subscription_package: 'Premium', subscription_expires_at: null,
        }];
      }
      if (sql.includes('FROM smartplus_action_drafts WHERE id = ?')) {
        if (params[0] !== 'draft-a' || params[1] !== 'business-a') return [];
        return [{
          id: 'draft-a', business_id: 'business-a', action_type: 'reorder',
          title: 'Reorder proposal', proposal_json: '{}', evidence_json: '{}',
          status, created_by: 'owner-a', approved_by: null, approved_at: null,
          executed_at: null, result_message: null, created_at: '2026-10-21 08:00:00',
          updated_at: '2026-10-21 08:00:00',
        }];
      }
      if (sql.includes('WHERE business_id = ? AND status <>')) return [];
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    async execute(sql, params = []) {
      calls.push({ type: 'execute', sql, params });
      if (sql.includes('UPDATE smartplus_action_drafts')) status = 'rejected';
      return [{ affectedRows: 1 }];
    },
  };
  const loaded = loadRouter(db);
  const owner = token({ userId: 'owner-a', role: 'owner', businessId: 'business-a' });
  const cashier = token({ userId: 'cashier-a', role: 'cashier', businessId: 'business-a' });
  try {
    await withServer(loaded.router, async (base) => {
      assert.equal((await fetch(`${base}/api/smartplus/actions/draft-a/dismiss`, { method: 'POST' })).status, 401);
      assert.equal((await fetch(`${base}/api/smartplus/actions/draft-a/dismiss`, {
        method: 'POST', headers: { Authorization: `Bearer ${cashier}` },
      })).status, 403);

      const dismissed = await fetch(`${base}/api/smartplus/actions/draft-a/dismiss?businessId=business-b`, {
        method: 'POST', headers: { Authorization: `Bearer ${owner}` },
      });
      assert.equal(dismissed.status, 200);
      assert.equal((await dismissed.json()).action.status, 'rejected');
    });
    const update = calls.find((call) => call.type === 'execute' && call.sql.includes('UPDATE smartplus_action_drafts'));
    const audit = calls.find((call) => call.type === 'execute' && call.sql.includes('smartplus_action_audit'));
    assert.ok(update);
    assert.ok(audit);
    assert.equal(update.params.includes('business-b'), false);
    assert.equal(update.params.includes('business-a'), true);
  } finally {
    loaded.restore();
  }
});
