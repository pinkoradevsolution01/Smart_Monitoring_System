#!/usr/bin/env node
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const { initDb, getConnection } = require('../db');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const TABLES = [
  'activation_codes',
  'activation_code_requests',
  'email_otps',
  'developer_notification_settings',
  'subscriptions',
  'subscription_records',
  'subscription_renewals',
  'businesses',
  'products',
  'sales',
  'sale_items',
  'purchase_orders',
  'inventory_movements',
  'damage_reports',
  'suppliers',
  'cameras',
  'cctv_timestamps',
];

function normalizeValue(value) {
  if (value === undefined || value === null) {
    return null;
  }

  if (typeof value === 'object') {
    return JSON.stringify(value);
  }

  return value;
}

async function insertRows(connection, table, rows) {
  if (!rows.length) {
    console.log(`  - No rows to import for ${table}`);
    return;
  }

  const columns = Object.keys(rows[0]);
  const columnList = columns.map((column) => `\`${column}\``).join(', ');
  const placeholderRow = `(${columns.map(() => '?').join(', ')})`;
  const sql = `INSERT INTO \`${table}\` (${columnList}) VALUES ${placeholderRow}`;

  for (let offset = 0; offset < rows.length; offset += 100) {
    const batch = rows.slice(offset, offset + 100);
    for (const row of batch) {
      const values = columns.map((column) => normalizeValue(row[column]));
      await connection.execute(sql, values);
    }
  }
}

async function runMigration() {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment. Add them to backend/.env or export them before running.'
    );
  }

  console.log('🔁 Starting one-time Supabase → MySQL migration');
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
    global: { headers: { 'X-Client-Info': 'supabase-migration-script' } },
  });

  await initDb();
  const connection = await getConnection();

  try {
    await connection.query('SET FOREIGN_KEY_CHECKS = 0');

    for (const table of TABLES) {
      console.log(`\nMigrating table: ${table}`);
      const { data, error } = await supabase.from(table).select('*');

      if (error) {
        throw new Error(`Supabase fetch failed for ${table}: ${error.message}`);
      }

      console.log(`  - Read ${data.length} rows from Supabase`);
      await connection.query(`TRUNCATE TABLE \`${table}\``);
      await insertRows(connection, table, data);
      console.log(`  - Imported ${data.length} rows into MySQL`);
    }

    console.log('\n✅ Supabase migration completed successfully.');
    console.log('Tip: verify your MySQL tables and then remove the service role key from your environment.');
  } finally {
    await connection.query('SET FOREIGN_KEY_CHECKS = 1');
    connection.release();
  }
}

runMigration().catch((error) => {
  console.error('Migration failed:', error.message || error);
  process.exit(1);
});
