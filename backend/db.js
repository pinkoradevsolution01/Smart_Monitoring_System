const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

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
  await ensureColumn('users', 'pin_hash', 'VARCHAR(255) NULL');
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
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS attendance_archive (
      id BIGINT AUTO_INCREMENT PRIMARY KEY,
      business_id VARCHAR(64) NOT NULL,
      user_id VARCHAR(64) NOT NULL,
      date_key VARCHAR(16) NOT NULL,
      entries LONGTEXT NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      KEY idx_attendance_archive_business (business_id),
      KEY idx_attendance_archive_user (user_id),
      UNIQUE KEY uq_attendance_archive_business_user_date (business_id, user_id, date_key)
    ) ENGINE=InnoDB
  `);

  await ensureColumn('sales', 'customer_id', 'BIGINT NULL');
  await ensureColumn('damage_reports', 'product_id', 'VARCHAR(64) NULL');
  await ensureColumn('customers', 'business_id', 'VARCHAR(64) NULL');
  await ensureColumn('products', 'description', 'TEXT NULL');
  await ensureColumn('products', 'buying_price', 'DECIMAL(12, 2) NOT NULL DEFAULT 0.00');
  await ensureColumn('sales', 'reference_code', 'VARCHAR(255) NULL');
  await ensureColumn('sales', 'image_path', 'TEXT NULL');
  await ensureColumn('sales', 'cancelled_reason', 'TEXT NULL');
  await ensureColumn('sales', 'cancelled_by', 'VARCHAR(255) NULL');
  await ensureColumn('sales', 'cancelled_at', 'DATETIME NULL');
  await ensureColumn('sales', 'transaction_type', "VARCHAR(32) NOT NULL DEFAULT 'pos'");
  await ensureColumn('sales', 'reservation_fee', 'DECIMAL(12, 2) NULL');
  await ensureColumn('sales', 'courier', 'VARCHAR(255) NULL');
  await ensureColumn('sales', 'delivery_status', 'VARCHAR(64) NULL');
  await ensureColumn('sales', 'loyalty_points_earned', 'INT NOT NULL DEFAULT 0');
  await ensureColumn('sales', 'loyalty_points_redeemed', 'INT NOT NULL DEFAULT 0');
  await ensureColumn('sales', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
  await ensureColumn('sale_items', 'shoe_size', 'VARCHAR(32) NULL');
  await ensureColumn('attendance_archive', 'business_id', 'VARCHAR(64) NOT NULL');
  await ensureColumn('attendance_archive', 'user_id', 'VARCHAR(64) NOT NULL');
  await ensureColumn('attendance_archive', 'date_key', 'VARCHAR(16) NOT NULL');
  await ensureColumn('attendance_archive', 'entries', 'LONGTEXT NOT NULL');
  await ensureColumn('attendance_archive', 'created_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP');
  await ensureColumn('attendance_archive', 'updated_at', 'DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

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

  if (!(await uniqueIndexExists('attendance_archive', 'uq_attendance_archive_business_user_date'))) {
    await pool.execute(
      'ALTER TABLE attendance_archive ADD UNIQUE KEY uq_attendance_archive_business_user_date (business_id, user_id, date_key)',
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

async function ensureDeveloperAccountsTable() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS developer_accounts (
      id VARCHAR(32) PRIMARY KEY,
      display_name VARCHAR(255) NOT NULL,
      email VARCHAR(255) NOT NULL,
      password_hash VARCHAR(255) NULL,
      auth_method VARCHAR(32) NOT NULL DEFAULT 'password',
      google_sub VARCHAR(255) NULL,
      avatar_url TEXT,
      is_active TINYINT(1) NOT NULL DEFAULT 1,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB
  `);

  const [rows] = await pool.execute(
    'SELECT id FROM developer_accounts WHERE id = ? LIMIT 1',
    ['primary'],
  );

  if (!rows.length) {
    const passwordHash = await bcrypt.hash('dev123', 10);
    await pool.execute(
      `INSERT INTO developer_accounts
        (id, display_name, email, password_hash, auth_method, google_sub, avatar_url, is_active)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        'primary',
        'Developer',
        'developer@smartmonitoring.com',
        passwordHash,
        'password',
        null,
        null,
        1,
      ],
    );
  }
}

async function ensureOwnerPinResetTokensTable() {
  await pool.execute(`
    CREATE TABLE IF NOT EXISTS owner_pin_reset_tokens (
      id CHAR(36) NOT NULL PRIMARY KEY,
      user_id VARCHAR(64) NOT NULL,
      email VARCHAR(255) NOT NULL,
      token_hash CHAR(64) NOT NULL,
      expires_at DATETIME NOT NULL,
      used_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      KEY idx_owner_pin_reset_user (user_id),
      KEY idx_owner_pin_reset_email (email),
      KEY idx_owner_pin_reset_token (token_hash),
      KEY idx_owner_pin_reset_expiry (expires_at)
    ) ENGINE=InnoDB
  `);
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
  await ensureDeveloperAccountsTable();
  await ensureOwnerPinResetTokensTable();
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
