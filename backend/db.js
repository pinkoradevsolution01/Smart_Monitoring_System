const mysql = require('mysql2/promise');

const {
  MYSQL_HOST = 'localhost',
  MYSQL_PORT = '3306',
  MYSQL_USER = 'root',
  MYSQL_PASSWORD = '',
  MYSQL_DATABASE = 'smart_monitoring',
} = process.env;

let pool;

async function columnExists(tableName, columnName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM information_schema.columns
     WHERE table_schema = DATABASE()
       AND table_name = ?
       AND column_name = ?`,
    [tableName, columnName],
  );
  return (rows[0]?.count || 0) > 0;
}

async function constraintExists(tableName, constraintName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM information_schema.table_constraints
     WHERE table_schema = DATABASE()
       AND table_name = ?
       AND constraint_name = ?`,
    [tableName, constraintName],
  );
  return (rows[0]?.count || 0) > 0;
}

async function uniqueIndexExists(tableName, indexName) {
  const [rows] = await pool.execute(
    `SELECT COUNT(*) AS count
     FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name = ?
       AND index_name = ?
       AND non_unique = 0`,
    [tableName, indexName],
  );
  return (rows[0]?.count || 0) > 0;
}

async function getUniqueIndexes(tableName) {
  const [rows] = await pool.execute(
    `SELECT index_name, GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns_csv
     FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name = ?
       AND non_unique = 0
     GROUP BY index_name`,
    [tableName],
  );
  return rows;
}

async function ensureColumn(tableName, columnName, definition) {
  if (!(await columnExists(tableName, columnName))) {
    await pool.execute(`ALTER TABLE ${tableName} ADD COLUMN ${columnName} ${definition}`);
  }
}

async function ensureUsersTableColumns() {
  await ensureColumn('users', 'business_id', 'VARCHAR(64) NULL');
  await ensureColumn('users', 'contact_number', 'VARCHAR(64) NULL');
  await ensureColumn('users', 'auth_method', "VARCHAR(32) NOT NULL DEFAULT 'password'");
  await ensureColumn('users', 'full_name', "VARCHAR(255) NOT NULL DEFAULT ''");
  await ensureColumn('users', 'is_active', 'TINYINT(1) NOT NULL DEFAULT 1');
  await ensureColumn('users', 'last_login_at', 'DATETIME NULL');
  await ensureColumn('users', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

  await pool.execute("UPDATE users SET auth_method = 'password' WHERE auth_method IS NULL OR auth_method = ''");

  const uniqueIndexes = await getUniqueIndexes('users');
  for (const index of uniqueIndexes) {
    if (index.index_name === 'uq_users_business_email') {
      continue;
    }
    if (String(index.columns_csv || '') === 'email') {
      await pool.execute(`ALTER TABLE users DROP INDEX ${index.index_name}`);
    }
  }

  if (!(await uniqueIndexExists('users', 'uq_users_business_email'))) {
    await pool.execute('ALTER TABLE users ADD UNIQUE KEY uq_users_business_email (business_id, email)');
  }

  if (!(await constraintExists('users', 'fk_users_business'))) {
    await pool.execute(
      'ALTER TABLE users ADD CONSTRAINT fk_users_business FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE ON UPDATE CASCADE',
    );
  }
}

async function ensureSalesAndCustomerRelations() {
  await ensureColumn('sales', 'customer_id', 'BIGINT NULL');
  await ensureColumn('damage_reports', 'product_id', 'VARCHAR(64) NULL');
  await ensureColumn('customers', 'business_id', 'VARCHAR(64) NULL');

  const customerIndexes = await getUniqueIndexes('customers');
  for (const index of customerIndexes) {
    if (index.index_name === 'uq_customers_business_code' || index.index_name === 'uq_customers_business_barcode') {
      continue;
    }
    if (String(index.columns_csv || '') === 'customer_code') {
      await pool.execute(`ALTER TABLE customers DROP INDEX ${index.index_name}`);
    }
    if (String(index.columns_csv || '') === 'barcode_value') {
      await pool.execute(`ALTER TABLE customers DROP INDEX ${index.index_name}`);
    }
  }

  if (!(await uniqueIndexExists('customers', 'uq_customers_business_code'))) {
    await pool.execute(
      'ALTER TABLE customers ADD UNIQUE KEY uq_customers_business_code (business_id, customer_code)',
    );
  }

  if (!(await uniqueIndexExists('customers', 'uq_customers_business_barcode'))) {
    await pool.execute(
      'ALTER TABLE customers ADD UNIQUE KEY uq_customers_business_barcode (business_id, barcode_value)',
    );
  }

  if (!(await constraintExists('sales', 'fk_sales_customer'))) {
    await pool.execute(
      'ALTER TABLE sales ADD CONSTRAINT fk_sales_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL ON UPDATE CASCADE',
    );
  }

  if (!(await constraintExists('damage_reports', 'fk_damage_reports_product'))) {
    await pool.execute(
      'ALTER TABLE damage_reports ADD CONSTRAINT fk_damage_reports_product FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT ON UPDATE CASCADE',
    );
  }

  if (!(await constraintExists('sales', 'fk_sales_cashier'))) {
    await pool.execute(
      'ALTER TABLE sales ADD CONSTRAINT fk_sales_cashier FOREIGN KEY (cashier_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE',
    );
  }
}

async function ensureActivationCodeColumns() {
  await ensureColumn('activation_codes', 'assigned_at', 'DATETIME NULL');
  await ensureColumn('activation_codes', 'email_sent_at', 'DATETIME NULL');
  await ensureColumn('activation_codes', 'expires_at', 'DATETIME NULL');
  await ensureColumn('activation_codes', 'notes', 'TEXT NULL');
  await ensureColumn('activation_codes', 'used_at', 'DATETIME NULL');
  await ensureColumn('activation_codes', 'created_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP');
}

async function initDb() {
  pool = mysql.createPool({
    host: MYSQL_HOST,
    port: Number(MYSQL_PORT),
    user: MYSQL_USER,
    password: MYSQL_PASSWORD,
    database: MYSQL_DATABASE,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    dateStrings: true,
  });

  const connection = await pool.getConnection();
  await connection.ping();
  await ensureUsersTableColumns();
  await ensureSalesAndCustomerRelations();
  await ensureActivationCodeColumns();
  connection.release();

  console.log(`✅ Connected to MySQL database ${MYSQL_DATABASE} at ${MYSQL_HOST}:${MYSQL_PORT}`);
  return pool;
}

async function query(sql, params = []) {
  if (!pool) {
    throw new Error('Database not initialized. Call initDb() before using query().');
  }

  const [rows] = await pool.execute(sql, params);
  return rows;
}

async function execute(sql, params = []) {
  if (!pool) {
    throw new Error('Database not initialized. Call initDb() before using execute().');
  }

  return await pool.execute(sql, params);
}

async function getConnection() {
  if (!pool) {
    throw new Error('Database not initialized. Call initDb() before using getConnection().');
  }
  return await pool.getConnection();
}

module.exports = { initDb, query, execute, getConnection };
