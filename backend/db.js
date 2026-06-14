const mysql = require('mysql2/promise');

const {
  MYSQL_HOST = 'localhost',
  MYSQL_PORT = '3306',
  MYSQL_USER = 'root',
  MYSQL_PASSWORD = '',
  MYSQL_DATABASE = 'smart_monitoring',
} = process.env;

let pool;

async function ensureUsersTableColumns() {
  const columns = [
    ['contact_number', 'VARCHAR(64) NULL'],
    ['auth_method', "VARCHAR(32) NOT NULL DEFAULT 'password'"],
  ];

  for (const [columnName, columnDefinition] of columns) {
    const [rows] = await pool.execute(
      `SELECT COUNT(*) AS count
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'users'
         AND column_name = ?`,
      [columnName],
    );

    const exists = rows[0]?.count > 0;
    if (!exists) {
      await pool.execute(`ALTER TABLE users ADD COLUMN ${columnName} ${columnDefinition}`);
    }
  }

  await pool.execute(
    "UPDATE users SET auth_method = 'password' WHERE auth_method IS NULL OR auth_method = ''",
  );
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

async function getConnection() {
  if (!pool) {
    throw new Error('Database not initialized. Call initDb() before using getConnection().');
  }
  return await pool.getConnection();
}

module.exports = { initDb, query, getConnection };
