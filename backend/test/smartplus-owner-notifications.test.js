const assert = require('node:assert/strict');
const test = require('node:test');

process.env.SMARTPLUS_OWNER_EMAIL_ENABLED = 'true';

const {
  buildSupplierDeliveryRows,
  dispatchOwnerAlert,
  dispatchOwnerActionCompletion,
  dispatchScheduledOwnerAlerts,
  normalizeSuggestions,
  supplierDeliverySuggestions,
} = require('../services/smartplus_owner_notifications');

test('SmartPlus creates owner-safe actionable suggestions only', () => {
  const suggestions = normalizeSuggestions({
    outOfStock: [{ name: 'Milk' }],
    lowStock: [{ name: 'Bread' }],
    discountReview: { count: 2 },
  });
  assert.equal(suggestions.length, 3);
  assert.match(suggestions[0].message, /Milk/);
  assert.match(suggestions[1].message, /Bread/);
  assert.match(suggestions[2].message, /not a fraud finding/);
});

test('SmartPlus supplier delivery suggestions identify the order, timing, impact, and owner action', () => {
  const suggestions = normalizeSuggestions({
    outOfStock: [],
    lowStock: [],
    discountReview: { count: 0 },
    supplierDelivery: [{
      order_number: 'PO-20261016-001',
      supplier_name: 'ABC Supplies',
      ordered_items: 'Milk x12, Bread x6',
      expected_delivery: '2026-10-14',
      overdue_days: 3,
      low_stock_count: 3,
      status: 'approved',
    }],
  });
  assert.equal(suggestions.length, 1);
  assert.match(suggestions[0].title, /overdue/i);
  assert.match(suggestions[0].message, /Rule:/);
  assert.match(suggestions[0].message, /PO-20261016-001/);
  assert.match(suggestions[0].message, /ABC Supplies/);
  assert.match(suggestions[0].message, /3 day\(s\) overdue/);
  assert.match(suggestions[0].message, /3 affected/);
  assert.match(suggestions[0].message, /Confirm delivery status/);
});

test('due-today delivery is an owner email reminder', () => {
  const suggestions = supplierDeliverySuggestions([{
    order_number: 'PO-DUE-TODAY',
    supplier_name: 'ABC Supplies',
    ordered_items: 'Milk x12',
    expected_delivery: '2026-10-21',
    overdue_days: 0,
    status: 'approved',
  }]);
  assert.equal(suggestions.length, 1);
  assert.equal(suggestions[0].title, 'Supplier delivery is due today');
  assert.equal(suggestions[0].level, 'warning');
});

test('received and fully restocked orders do not fall through to overdue emails', () => {
  const received = {
    order_number: 'PO-20261016-4154015', status: 'received',
    expected_delivery: '2026-10-16', overdue_days: 1, missing_inventory: 0,
  };
  const staleCompleted = {
    order_number: 'PO-20261016-6744672', status: 'completed',
    expected_delivery: '2026-10-16', overdue_days: 1, fully_restocked: 1,
  };
  assert.deepEqual(supplierDeliverySuggestions([received, staleCompleted]), []);
  assert.deepEqual(supplierDeliverySuggestions([{ ...received, status: 'cancelled' }]), []);
});

test('future completed orders are not described as overdue or missing deliveries', () => {
  const order = { order_number: 'PO-20261017-4192420', status: 'completed', expected_delivery: '2026-10-18', overdue_days: -1 };
  assert.deepEqual(supplierDeliverySuggestions([order]), []);
  assert.deepEqual(supplierDeliverySuggestions([{ ...order, overdue_days: 0 }]), []);
  assert.deepEqual(supplierDeliverySuggestions([{ ...order, expected_delivery: null, overdue_days: null }]), []);
  const overdue = supplierDeliverySuggestions([{ ...order, overdue_days: 1 }]);
  assert.equal(overdue.length, 1);
  assert.equal(overdue[0].title, 'Delivery awaiting receipt');
});

test('genuine missing-restock and partial-delivery warnings remain visible', () => {
  const alerts = supplierDeliverySuggestions([
    { order_number: 'PO-MISSING', status: 'received', missing_inventory: 1 },
    { order_number: 'PO-PARTIAL', status: 'partial', fully_restocked: 0 },
  ]);
  assert.equal(alerts.length, 2);
  assert.match(alerts[0].title, /not been added/);
  assert.match(alerts[1].title, /partial/i);
});

test('old received orders without a legacy receipt link do not remain critical forever', () => {
  const alerts = supplierDeliverySuggestions([{
    order_number: 'PO-HISTORICAL-RECEIPT',
    status: 'received',
    missing_inventory: 1,
    receipt_age_days: 21,
  }]);
  assert.deepEqual(alerts, []);
});

test('delivery analysis matches restocks once in memory instead of correlated SQL scans', () => {
  const rows = buildSupplierDeliveryRows(
    [{
      order_id: 7,
      order_number: 'PO-FAST-7',
      status: 'received',
      order_date: '2026-10-14',
      expected_delivery: '2026-10-16',
      supplier_name: 'ABC Supplies',
      product_id: 3,
      product_name: 'Milk',
      quantity: 5,
      received_quantity: 5,
      product_quantity: 2,
      low_stock_threshold: 5,
    }],
    [{ product_id: 3, quantity: 5, referenced_by: 'Received PO-FAST-7' }],
    new Date('2026-10-17T04:00:00.000Z'),
  );
  assert.equal(rows.length, 1);
  assert.equal(rows[0].missing_inventory, 0);
  assert.equal(rows[0].fully_restocked, 1);
  assert.equal(rows[0].low_stock_count, 1);
  assert.deepEqual(supplierDeliverySuggestions(rows), []);
});

test('duplicate synced order lines and legacy restock references do not create false critical alerts', () => {
  const line = {
    order_id: 9,
    order_number: 'PO-LEGACY-9',
    status: 'received',
    order_date: '2026-10-01',
    expected_delivery: '2026-10-02',
    product_id: 4,
    product_name: 'Mouse',
    quantity: 15,
    received_quantity: 15,
  };
  const rows = buildSupplierDeliveryRows(
    [line, { ...line }, { ...line }],
    [{
      product_id: 4,
      quantity: 15,
      referenced_by: 'Restocked from purchase order',
      restock_date: '2026-10-03',
    }],
    new Date('2026-10-10T04:00:00.000Z'),
  );
  assert.equal(rows.length, 1);
  assert.equal(rows[0].ordered_items, 'Mouse x15');
  assert.equal(rows[0].missing_inventory, 0);
  assert.equal(rows[0].fully_restocked, 1);
  assert.deepEqual(supplierDeliverySuggestions(rows), []);
});

test('overdue supplier emails are limited to day one and every third day', () => {
  const base = {
    order_number: 'PO-CADENCE-1',
    status: 'approved',
    expected_delivery: '2026-10-01',
    fully_restocked: 0,
  };
  assert.equal(supplierDeliverySuggestions([{ ...base, overdue_days: 1 }]).length, 1);
  assert.equal(supplierDeliverySuggestions([{ ...base, overdue_days: 2 }]).length, 0);
  assert.equal(supplierDeliverySuggestions([{ ...base, overdue_days: 3 }]).length, 1);
});

test('owner email is skipped when only received orders remain', async () => {
  const dbQuery = async (sql) => {
    if (sql.includes('FROM businesses')) return [{ id: 'business-a', name: 'Store A', owner_email: 'owner@example.com' }];
    if (sql.includes('smartplus_notification_preferences')) return [];
    if (sql.includes('FROM purchase_orders po')) {
      assert.doesNotMatch(sql, /INSTR\(/);
      return [{
        order_id: 1, order_number: 'PO-20261016-4154015', status: 'received',
        order_date: '2026-10-15', expected_delivery: '2026-10-16',
        product_id: 1, product_name: 'Milk', quantity: 5, received_quantity: 5,
        product_quantity: 10, low_stock_threshold: 5,
      }];
    }
    if (sql.includes('FROM restock_records')) return [{ product_id: 1, quantity: 5, referenced_by: 'PO-20261016-4154015' }];
    if (sql.includes('discount / subtotal')) return [{ count: 0 }];
    return [];
  };
  let sent = false;
  const result = await dispatchOwnerAlert('business-a', {
    query: dbQuery,
    execute: async () => { throw new Error('No alert should be queued'); },
    sendEmail: async () => { sent = true; },
  });
  assert.equal(result.skipped, 'no_important_suggestions');
  assert.equal(sent, false);
});

test('SmartPlus emails only the database owner for a new important alert and deduplicates repeats', async () => {
  const calls = [];
  const emails = [];
  const dbQuery = async (sql, params = []) => {
    calls.push({ sql, params });
    if (sql.includes('FROM businesses')) {
      return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
    }
    if (sql.includes('smartplus_notification_preferences')) return [];
    if (sql.includes('quantity <= 0')) return [{ name: 'Milk', quantity: 0 }];
    if (sql.includes('low_stock_threshold')) return [{ name: 'Bread', quantity: 2, low_stock_threshold: 5 }];
    if (sql.includes('discount / subtotal')) return [{ count: 0 }];
    if (sql.includes('FROM purchase_orders po')) return [];
    if (sql.includes('FROM restock_records')) return [];
    throw new Error(`Unexpected query: ${sql}`);
  };
  let inserts = 0;
  const dbExecute = async (sql, params = []) => {
    calls.push({ sql, params });
    if (sql.includes('INSERT IGNORE')) {
      inserts += 1;
      return [{ affectedRows: inserts === 1 ? 1 : 0 }];
    }
    if (sql.includes("SET status = 'pending'")) return [{ affectedRows: 0 }];
    if (sql.includes('UPDATE smartplus_email_deliveries')) return [{ affectedRows: 1 }];
    throw new Error(`Unexpected execute: ${sql}`);
  };
  const send = async (message) => {
    emails.push(message);
    return 'resend-message-id';
  };

  const first = await dispatchOwnerAlert('business-a', {
    query: dbQuery,
    execute: dbExecute,
    sendEmail: send,
  });
  const second = await dispatchOwnerAlert('business-a', {
    query: dbQuery,
    execute: dbExecute,
    sendEmail: send,
  });

  assert.equal(first.sent, true);
  assert.equal(second.skipped, 'already_sent_or_retry_pending');
  assert.equal(emails.length, 1);
  assert.equal(emails[0].to, 'owner-a@example.com');
  assert.match(emails[0].text, /Milk/);
  assert.match(emails[0].text, /Bread/);
  assert.match(emails[0].html, /Owner review required/);
  assert.match(emails[0].html, /SMART MONITORING SYSTEM/);
  for (const call of calls) assert.equal(call.params.includes('business-b'), false);
});

test('scheduled SmartPlus alerts evaluate active businesses only', async () => {
  const queried = [];
  const result = await dispatchScheduledOwnerAlerts({
    query: async (sql, params = []) => {
      queried.push({ sql, params });
      if (sql === 'SELECT id FROM businesses WHERE is_active = 1') {
        return [{ id: 'business-a' }];
      }
      if (sql.includes('FROM businesses')) {
        return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
      }
      if (sql.includes('smartplus_notification_preferences')) return [{ email_enabled: 0 }];
      throw new Error(`Unexpected query: ${sql}`);
    },
  });
  assert.equal(result.processed, 1);
  assert.equal(result.failed, 0);
  assert.equal(queried.some((call) => call.params.includes('business-b')), false);
});

test('concurrent owner-alert triggers share one tenant evaluation', async () => {
  let businessQueries = 0;
  let releaseBusiness;
  const businessGate = new Promise((resolve) => { releaseBusiness = resolve; });
  const dependencies = {
    query: async (sql) => {
      if (sql.includes('FROM businesses')) {
        businessQueries += 1;
        await businessGate;
        return [{ id: 'business-concurrent', name: 'Store', owner_email: 'owner@example.com' }];
      }
      if (sql.includes('smartplus_notification_preferences')) return [{ email_enabled: 0 }];
      throw new Error(`Unexpected query: ${sql}`);
    },
  };

  const first = dispatchOwnerAlert('business-concurrent', dependencies);
  const second = dispatchOwnerAlert('business-concurrent', dependencies);
  releaseBusiness();
  const [firstResult, secondResult] = await Promise.all([first, second]);

  assert.equal(businessQueries, 1);
  assert.equal(firstResult.skipped, 'email_disabled_by_owner');
  assert.equal(secondResult.skipped, 'email_disabled_by_owner');
});

test('SmartPlus sends one professional completion email only to the database owner', async () => {
  const emails = [];
  let reserved = false;
  const dependencies = {
    query: async (sql) => {
      if (sql.includes('FROM businesses')) {
        return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
      }
      if (sql.includes('smartplus_notification_preferences')) return [];
      throw new Error(`Unexpected query: ${sql}`);
    },
    execute: async (sql) => {
      if (sql.includes('INSERT IGNORE')) {
        if (reserved) return [{ affectedRows: 0 }];
        reserved = true;
        return [{ affectedRows: 1 }];
      }
      if (sql.includes("SET status = 'pending'")) return [{ affectedRows: 0 }];
      if (sql.includes('UPDATE smartplus_email_deliveries')) return [{ affectedRows: 1 }];
      throw new Error(`Unexpected execute: ${sql}`);
    },
    sendEmail: async (message) => {
      emails.push(message);
      return 'resend-completion-id';
    },
  };
  const action = {
    id: 'action-a',
    title: 'Owner follow-up: Check a discount',
    executedAt: '2026-10-17T04:00:00.000Z',
    resultMessage: 'The owner marked the guided follow-up complete.',
  };

  const first = await dispatchOwnerActionCompletion('business-a', action, dependencies);
  const second = await dispatchOwnerActionCompletion('business-a', action, dependencies);

  assert.equal(first.sent, true);
  assert.equal(second.skipped, 'already_sent_or_retry_pending');
  assert.equal(emails.length, 1);
  assert.equal(emails[0].to, 'owner-a@example.com');
  assert.match(emails[0].subject, /task completed/i);
  assert.match(emails[0].html, /COMPLETED/);
  assert.match(emails[0].html, /Owner follow-up/);
});

test('SmartPlus retries a failed important alert once it is due, without duplicating a sent alert', async () => {
  let insertCalls = 0;
  let sendCalls = 0;
  const dependencies = {
    query: async (sql) => {
      if (sql.includes('FROM businesses')) {
        return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
      }
      if (sql.includes('smartplus_notification_preferences')) return [];
      if (sql.includes('quantity <= 0')) return [{ name: 'Milk', quantity: 0 }];
      if (sql.includes('low_stock_threshold')) return [];
      if (sql.includes('discount / subtotal')) return [{ count: 0 }];
      if (sql.includes('FROM purchase_orders po')) return [];
      if (sql.includes('FROM restock_records')) return [];
      throw new Error(`Unexpected query: ${sql}`);
    },
    execute: async (sql) => {
      if (sql.includes('INSERT IGNORE')) {
        insertCalls += 1;
        return [{ affectedRows: insertCalls === 1 ? 1 : 0 }];
      }
      if (sql.includes("SET status = 'pending'")) {
        // The second call represents a due failed record. The third finds
        // the record already sent and cannot reserve it again.
        return [{ affectedRows: insertCalls === 2 ? 1 : 0 }];
      }
      if (sql.includes('UPDATE smartplus_email_deliveries')) return [{ affectedRows: 1 }];
      throw new Error(`Unexpected execute: ${sql}`);
    },
    sendEmail: async () => {
      sendCalls += 1;
      if (sendCalls === 1) throw new Error('Temporary Resend outage');
      return 'resend-retry-id';
    },
  };

  await assert.rejects(
    dispatchOwnerAlert('business-a', dependencies),
    /Temporary Resend outage/,
  );
  const retry = await dispatchOwnerAlert('business-a', dependencies);
  const duplicate = await dispatchOwnerAlert('business-a', dependencies);

  assert.equal(retry.sent, true);
  assert.equal(retry.retried, true);
  assert.equal(duplicate.skipped, 'already_sent_or_retry_pending');
  assert.equal(sendCalls, 2);
});

test('SmartPlus retries a failed task-completion email without repeating the task', async () => {
  let insertCalls = 0;
  let sendCalls = 0;
  const dependencies = {
    query: async (sql) => {
      if (sql.includes('FROM businesses')) {
        return [{ id: 'business-a', name: 'Store A', owner_email: 'owner-a@example.com' }];
      }
      if (sql.includes('smartplus_notification_preferences')) return [];
      throw new Error(`Unexpected query: ${sql}`);
    },
    execute: async (sql) => {
      if (sql.includes('INSERT IGNORE')) {
        insertCalls += 1;
        return [{ affectedRows: insertCalls === 1 ? 1 : 0 }];
      }
      if (sql.includes("SET status = 'pending'")) return [{ affectedRows: insertCalls === 2 ? 1 : 0 }];
      if (sql.includes('UPDATE smartplus_email_deliveries')) return [{ affectedRows: 1 }];
      throw new Error(`Unexpected execute: ${sql}`);
    },
    sendEmail: async () => {
      sendCalls += 1;
      if (sendCalls === 1) throw new Error('Temporary Resend outage');
      return 'resend-completion-retry-id';
    },
  };
  const action = { id: 'action-a', title: 'Record received stock' };

  await assert.rejects(
    dispatchOwnerActionCompletion('business-a', action, dependencies),
    /Temporary Resend outage/,
  );
  const retry = await dispatchOwnerActionCompletion('business-a', action, dependencies);

  assert.equal(retry.sent, true);
  assert.equal(retry.retried, true);
  assert.equal(sendCalls, 2);
});
