const mysql = require('mysql2/promise');

const {
  MYSQL_HOST = 'localhost',
  MYSQL_PORT = '3306',
  MYSQL_USER = 'root',
  MYSQL_PASSWORD = '',
  MYSQL_DATABASE = 'smart_monitoring',
} = process.env;

let pool;

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
