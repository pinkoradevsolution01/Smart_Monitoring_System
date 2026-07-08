const express = require('express');
const { randomUUID } = require('crypto');
const { query, getConnection } = require('../db');

const router = express.Router();

const RESERVED_QUERY_KEYS = new Set([
  'businessId',
  'business_id',
  'limit',
  'offset',
  'orderBy',
  'order_by',
  'orderDirection',
  'order_direction',
  'search',
]);

const RESOURCE_CONFIG = {
  customers: {
    table: 'customers',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'updated_at DESC',
    columns: [
      'id',
      'business_id',
      'customer_code',
      'full_name',
      'phone_number',
      'email',
      'address',
      'points_balance',
      'lifetime_points',
      'barcode_value',
      'created_at',
      'updated_at',
      'is_active',
    ],
    requiredOnCreate: ['full_name'],
    datetimeColumns: ['created_at', 'updated_at'],
    booleanColumns: ['is_active'],
    defaults: {
      points_balance: 0,
      lifetime_points: 0,
      is_active: 1,
    },
    generated(row) {
      if (!row.customer_code) {
        row.customer_code = randomUUID();
      }
      if (!row.barcode_value) {
        const token = row.customer_code.replace(/-/g, '').substring(0, 12).toUpperCase();
        row.barcode_value = `SMS-CUST-${token}`;
      }
    },
  },
  'loyalty-ledger': {
    table: 'loyalty_ledger',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'created_at DESC',
    columns: [
      'id',
      'business_id',
      'customer_id',
      'sale_id',
      'entry_type',
      'points',
      'balance_after',
      'notes',
      'created_at',
    ],
    requiredOnCreate: ['customer_id', 'entry_type', 'points', 'balance_after'],
    datetimeColumns: ['created_at'],
    defaults: {
      notes: null,
    },
  },
  cameras: {
    table: 'cameras',
    pk: 'id',
    businessScoped: true,
    defaultOrder: 'position ASC',
    columns: [
      'id',
      'business_id',
      'name',
      'location',
      'stream_url',
      'type',
      'position',
      'is_active',
      'username',
      'password',
      'created_at',
    ],
    requiredOnCreate: ['name', 'stream_url'],
    datetimeColumns: ['created_at'],
    booleanColumns: ['is_active'],
    defaults: {
      type: 'http',
      position: 0,
      is_active: 1,
    },
  },
  'cctv-timestamps': {
    table: 'cctv_timestamps',
    pk: 'id',
    businessScoped: true,
    defaultOrder: 'timestamp DESC',
    columns: [
      'id',
      'business_id',
      'camera_id',
      'label',
      'description',
      'timestamp',
      'notes',
      'video_path',
      'created_by',
      'created_at',
    ],
    requiredOnCreate: ['camera_id', 'label', 'timestamp'],
    datetimeColumns: ['timestamp', 'created_at'],
  },
  'attendance-entries': {
    table: 'attendance_entries',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'time DESC',
    columns: ['id', 'business_id', 'user_id', 'time', 'type', 'created_at'],
    requiredOnCreate: ['user_id', 'time', 'type'],
    datetimeColumns: ['time', 'created_at'],
  },
  'attendance-leaves': {
    table: 'attendance_leaves',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'date_key DESC',
    columns: ['id', 'business_id', 'user_id', 'date_key', 'payload', 'created_at', 'updated_at'],
    requiredOnCreate: ['user_id', 'date_key', 'payload'],
    datetimeColumns: ['created_at', 'updated_at'],
    jsonColumns: ['payload'],
  },
  'attendance-archive': {
    table: 'attendance_archive',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'date_key DESC',
    columns: ['id', 'business_id', 'user_id', 'date_key', 'entries', 'created_at', 'updated_at'],
    requiredOnCreate: ['user_id', 'date_key', 'entries'],
    datetimeColumns: ['created_at', 'updated_at'],
  },
  'attendance-schedule': {
    table: 'attendance_schedule',
    pk: 'key',
    businessScoped: true,
    defaultOrder: '`key` ASC',
    columns: ['business_id', 'key', 'value', 'updated_at'],
    requiredOnCreate: ['value'],
    datetimeColumns: ['updated_at'],
    defaults: {
      key: 'global',
    },
    jsonColumns: ['value'],
  },
  'restock-records': {
    table: 'restock_records',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'restock_date DESC',
    columns: [
      'id',
      'business_id',
      'product_id',
      'product_name',
      'quantity',
      'supplier_id',
      'supplier_name',
      'delivery_receipt_no',
      'damage_quantity',
      'damage_reason',
      'notes',
      'referenced_by',
      'restock_date',
      'created_at',
    ],
    requiredOnCreate: ['product_id', 'product_name', 'quantity', 'referenced_by'],
    datetimeColumns: ['restock_date', 'created_at'],
    defaults: {
      damage_quantity: 0,
      delivery_receipt_no: '',
      damage_reason: '',
      notes: '',
      supplier_name: null,
      supplier_id: null,
    },
  },
  'purchase-order-items': {
    table: 'purchase_order_items',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'id DESC',
    columns: [
      'id',
      'business_id',
      'order_id',
      'product_id',
      'product_name',
      'quantity',
      'unit_price',
      'total_price',
      'created_at',
    ],
    requiredOnCreate: ['order_id', 'product_id', 'product_name', 'quantity', 'unit_price', 'total_price'],
    datetimeColumns: ['created_at'],
  },
  'activity-logs': {
    table: 'activity_logs',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'created_at DESC',
    columns: ['id', 'business_id', 'type', 'message', 'meta', 'created_at', 'sent'],
    requiredOnCreate: ['type', 'message'],
    datetimeColumns: ['created_at'],
    booleanColumns: ['sent'],
    defaults: {
      sent: 0,
    },
    jsonColumns: ['meta'],
  },
  products: {
    table: 'products',
    pk: 'id',
    businessScoped: true,
    defaultOrder: 'updated_at DESC',
    columns: [
      'id',
      'business_id',
      'barcode',
      'name',
      'category',
      'selling_price',
      'quantity',
      'image_path',
      'low_stock_threshold',
      'shoe_sizes',
      'size_type',
      'created_at',
      'updated_at',
    ],
    requiredOnCreate: ['name'],
    datetimeColumns: ['created_at', 'updated_at'],
    defaults: {
      quantity: 0,
      low_stock_threshold: 5,
    },
    jsonColumns: ['shoe_sizes'],
  },
  suppliers: {
    table: 'suppliers',
    pk: 'id',
    businessScoped: true,
    defaultOrder: 'created_at DESC',
    columns: [
      'id',
      'business_id',
      'name',
      'contact_person',
      'email',
      'phone',
      'address',
      'notes',
      'is_active',
      'created_at',
    ],
    requiredOnCreate: ['name'],
    datetimeColumns: ['created_at'],
    booleanColumns: ['is_active'],
    defaults: {
      is_active: 1,
      notes: '',
    },
  },
  sales: {
    table: 'sales',
    pk: 'id',
    businessScoped: true,
    defaultOrder: 'datetime DESC',
    columns: [
      'id',
      'business_id',
      'cashier_id',
      'cashier_name',
      'customer_name',
      'customer_id',
      'payment_method',
      'status',
      'subtotal',
      'discount',
      'total_amount',
      'amount_paid',
      'change_amount',
      'item_count',
      'datetime',
      'notes',
      'created_at',
    ],
    requiredOnCreate: ['cashier_id', 'cashier_name', 'payment_method', 'datetime'],
    datetimeColumns: ['datetime', 'created_at'],
    defaults: {
      status: 'completed',
      subtotal: 0,
      discount: 0,
      total_amount: 0,
      amount_paid: 0,
      change_amount: 0,
      item_count: 0,
      notes: '',
    },
  },
  'sale-items': {
    table: 'sale_items',
    pk: 'id',
    autoIncrement: true,
    businessScoped: true,
    defaultOrder: 'created_at DESC',
    columns: [
      'id',
      'sale_id',
      'business_id',
      'product_id',
      'product_name',
      'quantity',
      'unit_price',
      'discount',
      'subtotal',
      'created_at',
    ],
    requiredOnCreate: ['sale_id', 'product_id', 'product_name', 'quantity', 'unit_price', 'subtotal'],
    datetimeColumns: ['created_at'],
    defaults: {
      discount: 0,
    },
  },
  'purchase-orders': {
    table: 'purchase_orders',
    pk: 'id',
    businessScoped: true,
    defaultOrder: 'order_date DESC',
    columns: [
      'id',
      'business_id',
      'supplier_id',
      'order_number',
      'order_date',
      'expected_delivery',
      'status',
      'total_amount',
      'notes',
      'created_by',
      'created_at',
    ],
    requiredOnCreate: ['supplier_id', 'order_date'],
    datetimeColumns: ['order_date', 'expected_delivery', 'created_at'],
    defaults: {
      status: 'pending',
      total_amount: 0,
      notes: '',
    },
  },
  'inventory-movements': {
    table: 'inventory_movements',
    pk: 'id',
    businessScoped: true,
    defaultOrder: '`timestamp` DESC',
    columns: [
      'id',
      'business_id',
      'product_id',
      'product_name',
      'movement_type',
      'quantity',
      'reference',
      'notes',
      'performed_by',
      'timestamp',
      'created_at',
    ],
    requiredOnCreate: ['product_id', 'quantity', 'timestamp'],
    datetimeColumns: ['timestamp', 'created_at'],
    defaults: {
      notes: '',
      reference: '',
    },
  },
  'damage-reports': {
    table: 'damage_reports',
    pk: 'id',
    businessScoped: true,
    defaultOrder: 'reported_at DESC',
    columns: [
      'id',
      'business_id',
      'product_id',
      'product_name',
      'quantity',
      'damage_type',
      'description',
      'reported_by',
      'reported_at',
      'status',
      'resolution_notes',
      'created_at',
    ],
    requiredOnCreate: ['product_id', 'product_name', 'quantity', 'reported_by', 'reported_at'],
    datetimeColumns: ['reported_at', 'created_at'],
    defaults: {
      status: 'pending',
      description: '',
      resolution_notes: '',
    },
  },
};

function toSnakeCase(value) {
  return String(value)
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/[-\s]+/g, '_')
    .toLowerCase();
}

function normalizeObjectKeys(input = {}) {
  const output = {};
  for (const [key, value] of Object.entries(input)) {
    output[toSnakeCase(key)] = value;
  }
  return output;
}

function toMySqlDatetime(value) {
  if (value === null || value === undefined || value === '') {
    return value;
  }

  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString().slice(0, 19).replace('T', ' ');
    }
    return value;
  }

  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 19).replace('T', ' ');
  }

  return value;
}

function extractBusinessId(req, payload = {}) {
  return (
    payload.business_id ||
    payload.businessId ||
    req.query.business_id ||
    req.query.businessId ||
    req.headers['x-business-id'] ||
    req.auth?.businessId ||
    req.auth?.business_id ||
    null
  );
}

function applyValueTransforms(config, row) {
  for (const column of config.datetimeColumns || []) {
    if (row[column] !== undefined) {
      row[column] = toMySqlDatetime(row[column]);
    }
  }

  for (const column of config.booleanColumns || []) {
    if (row[column] !== undefined) {
      row[column] = row[column] === true || row[column] === 1 || row[column] === '1' || row[column] === 'true'
        ? 1
        : 0;
    }
  }

  for (const column of config.jsonColumns || []) {
    if (row[column] !== undefined && typeof row[column] === 'object') {
      row[column] = JSON.stringify(row[column]);
    }
  }
}

function buildInsertRow(config, req, payload) {
  const row = {};
  const normalized = normalizeObjectKeys(payload);
  const now = toMySqlDatetime(new Date());

  if (config.businessScoped) {
    const businessId = extractBusinessId(req, normalized);
    if (!businessId) {
      throw Object.assign(new Error('businessId is required.'), { statusCode: 400 });
    }
    row.business_id = businessId;
  }

  if (config.pk) {
    const pkValue = normalized[config.pk];
    if (config.autoIncrement) {
      if (pkValue !== undefined && pkValue !== null && pkValue !== '') {
        row[config.pk] = pkValue;
      }
    } else {
      row[config.pk] = pkValue ?? (config.pk === 'key' ? 'global' : randomUUID());
    }
  }

  for (const column of config.columns) {
    if (column === config.pk || column === 'business_id') {
      continue;
    }

    if (normalized[column] !== undefined) {
      row[column] = normalized[column];
    }
  }

  for (const [column, defaultValue] of Object.entries(config.defaults || {})) {
    if (row[column] === undefined) {
      row[column] = typeof defaultValue === 'function' ? defaultValue(row) : defaultValue;
    }
  }

  if (config.generated) {
    config.generated(row, normalized, req);
  }

  for (const column of config.datetimeColumns || []) {
    if (row[column] === undefined && (column === 'created_at' || column === 'updated_at' || column === 'timestamp')) {
      row[column] = now;
    }
  }

  if (config.requiredOnCreate) {
    for (const column of config.requiredOnCreate) {
      if (row[column] === undefined || row[column] === null || row[column] === '') {
        throw Object.assign(new Error(`${column} is required.`), { statusCode: 400 });
      }
    }
  }

  applyValueTransforms(config, row);
  return row;
}

function buildUpdateRow(config, payload) {
  const normalized = normalizeObjectKeys(payload);
  const row = {};

  for (const column of config.columns) {
    if (column === config.pk || column === 'business_id' || column === 'created_at') {
      continue;
    }
    if (normalized[column] !== undefined) {
      row[column] = normalized[column];
    }
  }

  if (config.datetimeColumns?.includes('updated_at') && row.updated_at === undefined) {
    row.updated_at = toMySqlDatetime(new Date());
  }

  applyValueTransforms(config, row);
  return row;
}

function buildWhereClause(config, req, payload = {}, { includePrimaryKey = false } = {}) {
  const normalized = normalizeObjectKeys({
    ...req.query,
    ...payload,
  });
  const clauses = [];
  const params = [];
  const primaryKeyColumn = config.pk === 'key' ? '`key`' : config.pk;

  if (config.businessScoped) {
    const businessId = extractBusinessId(req, normalized);
    if (!businessId) {
      throw Object.assign(new Error('businessId is required.'), { statusCode: 400 });
    }
    clauses.push('business_id = ?');
    params.push(businessId);
  }

  if (includePrimaryKey && config.pk && normalized[config.pk] !== undefined) {
    clauses.push(`${primaryKeyColumn} = ?`);
    params.push(normalized[config.pk]);
  }

  for (const [key, value] of Object.entries(normalized)) {
    if (RESERVED_QUERY_KEYS.has(key) || value === undefined || value === null || value === '') {
      continue;
    }
    if (!config.columns.includes(key)) {
      continue;
    }
    if (key === config.pk || key === 'business_id') {
      continue;
    }
    clauses.push(`${key === 'key' ? '`key`' : key} = ?`);
    params.push(value);
  }

  return {
    where: clauses.length ? `WHERE ${clauses.join(' AND ')}` : '',
    params,
    normalized,
  };
}

function pickOrderBy(config, normalizedQuery) {
  const requested = normalizedQuery.order_by || normalizedQuery.orderby || normalizedQuery.orderBy;
  const direction = String(normalizedQuery.order_direction || normalizedQuery.orderDirection || 'DESC').toUpperCase() === 'ASC'
    ? 'ASC'
    : 'DESC';

  if (requested && config.columns.includes(toSnakeCase(requested))) {
    const column = toSnakeCase(requested);
    return `${column === 'key' ? '`key`' : column} ${direction}`;
  }

  return config.defaultOrder;
}

async function fetchById(config, req, id) {
  const whereParts = [];
  const params = [];
  const primaryKeyColumn = config.pk === 'key' ? '`key`' : config.pk;

  if (config.businessScoped) {
    const businessId = extractBusinessId(req);
    if (!businessId) {
      throw Object.assign(new Error('businessId is required.'), { statusCode: 400 });
    }
    whereParts.push('business_id = ?');
    params.push(businessId);
  }

  whereParts.push(`${primaryKeyColumn} = ?`);
  params.push(id);

  const rows = await query(
    `SELECT * FROM ${config.table} WHERE ${whereParts.join(' AND ')} LIMIT 1`,
    params,
  );
  return rows[0] || null;
}

function registerCrudRoutes(resourceName, config) {
  router.get(`/${resourceName}`, async (req, res) => {
    try {
      const { where, params, normalized } = buildWhereClause(config, req);
      const orderBy = pickOrderBy(config, normalized);
      const limit = Math.min(Math.max(parseInt(normalized.limit, 10) || 200, 1), 1000);
      const offset = Math.max(parseInt(normalized.offset, 10) || 0, 0);

      const rows = await query(
        `SELECT * FROM ${config.table} ${where} ORDER BY ${orderBy} LIMIT ? OFFSET ?`,
        [...params, limit, offset],
      );

      return res.json({ success: true, data: rows });
    } catch (error) {
      const status = error.statusCode || 500;
      return res.status(status).json({
        success: false,
        message: error.message || `Failed to list ${resourceName}.`,
      });
    }
  });

  router.get(`/${resourceName}/:id`, async (req, res) => {
    try {
      const row = await fetchById(config, req, req.params.id);
      if (!row) {
        return res.status(404).json({ success: false, message: `${resourceName} record not found.` });
      }

      return res.json({ success: true, data: row });
    } catch (error) {
      const status = error.statusCode || 500;
      return res.status(status).json({
        success: false,
        message: error.message || `Failed to load ${resourceName} record.`,
      });
    }
  });

  router.post(`/${resourceName}`, async (req, res) => {
    const connection = await getConnection();
    try {
      const row = buildInsertRow(config, req, req.body || {});
      const columns = Object.keys(row);
      const placeholders = columns.map(() => '?').join(', ');
      const values = columns.map((column) => row[column]);

      const [result] = await connection.execute(
        `INSERT INTO ${config.table} (${columns.map((column) => (column === 'key' ? '`key`' : column)).join(', ')})
         VALUES (${placeholders})`,
        values,
      );

      let insertedId = row[config.pk];
      if (config.autoIncrement) {
        insertedId = result.insertId;
      }

      const created = await fetchById(config, req, insertedId);
      return res.status(201).json({
        success: true,
        data: created || { ...row, [config.pk]: insertedId },
      });
    } catch (error) {
      const status = error.statusCode || 500;
      return res.status(status).json({
        success: false,
        message: error.message || `Failed to create ${resourceName} record.`,
      });
    } finally {
      connection.release();
    }
  });

  router.patch(`/${resourceName}/:id`, async (req, res) => {
    const connection = await getConnection();
    try {
      const existing = await fetchById(config, req, req.params.id);
      if (!existing) {
        return res.status(404).json({ success: false, message: `${resourceName} record not found.` });
      }

      const row = buildUpdateRow(config, req.body || {});
      const columns = Object.keys(row);
      if (!columns.length) {
        return res.status(400).json({ success: false, message: 'No fields provided for update.' });
      }

      const primaryKeyColumn = config.pk === 'key' ? '`key`' : config.pk;
      const setClause = columns.map((column) => `${column === 'key' ? '`key`' : column} = ?`).join(', ');
      const values = columns.map((column) => row[column]);
      const businessId = config.businessScoped ? extractBusinessId(req) : null;
      if (config.businessScoped && !businessId) {
        throw Object.assign(new Error('businessId is required.'), { statusCode: 400 });
      }
      const where = `${config.businessScoped ? 'business_id = ? AND ' : ''}${primaryKeyColumn} = ?`;
      const executeParams = config.businessScoped
        ? [...values, businessId, req.params.id]
        : [...values, req.params.id];

      await connection.execute(
        `UPDATE ${config.table} SET ${setClause} WHERE ${where}`,
        executeParams,
      );

      const updated = await fetchById(config, req, req.params.id);
      return res.json({ success: true, data: updated });
    } catch (error) {
      const status = error.statusCode || 500;
      return res.status(status).json({
        success: false,
        message: error.message || `Failed to update ${resourceName} record.`,
      });
    } finally {
      connection.release();
    }
  });

  router.delete(`/${resourceName}/:id`, async (req, res) => {
    const connection = await getConnection();
    try {
      const existing = await fetchById(config, req, req.params.id);
      if (!existing) {
        return res.status(404).json({ success: false, message: `${resourceName} record not found.` });
      }

      if (config.businessScoped) {
        const businessId = extractBusinessId(req);
        if (!businessId) {
          throw Object.assign(new Error('businessId is required.'), { statusCode: 400 });
        }
        await connection.execute(
          `DELETE FROM ${config.table} WHERE business_id = ? AND ${config.pk === 'key' ? '`key`' : config.pk} = ?`,
          [businessId, req.params.id],
        );
      } else {
        await connection.execute(
          `DELETE FROM ${config.table} WHERE ${config.pk === 'key' ? '`key`' : config.pk} = ?`,
          [req.params.id],
        );
      }

      return res.json({ success: true });
    } catch (error) {
      const status = error.statusCode || 500;
      return res.status(status).json({
        success: false,
        message: error.message || `Failed to delete ${resourceName} record.`,
      });
    } finally {
      connection.release();
    }
  });
}

for (const [resourceName, config] of Object.entries(RESOURCE_CONFIG)) {
  registerCrudRoutes(resourceName, config);
}

module.exports = router;
