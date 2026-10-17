const test = require('node:test');
const assert = require('node:assert/strict');
const { checkApprovedReorder, checkReceivedDelivery } = require('../services/smartplus_order_checks');

test('reorder requires an approved linked order for this business and product', async () => {
  const query = async (sql, params) => {
    assert.deepEqual(params, ['business-a', '[SmartPlus action:draft-1]', 42]);
    assert.match(sql, /po\.business_id = \?/);
    assert.match(sql, /po\.status IN \('approved', 'completed', 'partial', 'received'\)/);
    assert.match(sql, /pi\.business_id = po\.business_id/);
    return [];
  };
  assert.equal((await checkApprovedReorder(query, 'business-a', 'draft-1', 42)).ok, false);
  assert.equal((await checkApprovedReorder(async () => [{ order_number: 'PO-1' }], 'business-a', 'draft-1', 42)).ok, true);
  assert.equal((await checkApprovedReorder(query, 'business-a', 'draft-1', 0)).ok, false);
});

test('receiving remains incomplete without full receipt and linked restock', async () => {
  const query = async (sql, params) => {
    assert.deepEqual(params, ['business-a', 'PO-1']);
    assert.match(sql, /po\.status = 'received'/);
    assert.match(sql, /pi\.received_quantity < pi\.quantity/);
    assert.match(sql, /rr\.business_id = po\.business_id/);
    assert.match(sql, /rr\.referenced_by = CONCAT/);
    return [];
  };
  assert.equal((await checkReceivedDelivery(query, 'business-a', 'PO-1')).ok, false);
  assert.equal((await checkReceivedDelivery(async () => [{ order_number: 'PO-1' }], 'business-a', 'PO-1')).ok, true);
  assert.equal((await checkReceivedDelivery(query, 'business-a', '')).ok, false);
});
