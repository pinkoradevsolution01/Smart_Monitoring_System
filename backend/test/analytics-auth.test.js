const test = require('node:test');
const assert = require('node:assert/strict');
const analytics = require('../routes/analytics');

test('tenant scope is derived only from the verified JWT claim', () => {
  const token = { userId: 'u-1', role: 'owner', businessId: 'business-a' };
  const tamperedBrowserValues = { businessId: 'business-b', business_id: 'business-b', header: 'business-b' };
  assert.equal(analytics.__test.tenantScopeFromToken(token), 'business-a');
  assert.notEqual(analytics.__test.tenantScopeFromToken(token), tamperedBrowserValues.businessId);
});

test('only permitted business roles pass the analytics role allow-list', () => {
  for (const role of ['owner', 'admin', 'manager']) assert.equal(analytics.__test.BUSINESS_ROLES.has(role), true);
  for (const role of ['cashier', 'staff', 'developer', '']) assert.equal(analytics.__test.BUSINESS_ROLES.has(role), false);
});
