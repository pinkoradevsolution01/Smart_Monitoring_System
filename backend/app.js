require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initDb, query } = require('./db');
const authRouter = require('./routes/auth');
const businessRouter = require('./routes/business');
const licenseRouter = require('./routes/license');
const syncRouter = require('./routes/sync');

const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.use('/api/auth', authRouter);
app.use('/api/business', businessRouter);
app.use('/api/license', licenseRouter);
app.use('/api/sync', syncRouter);

app.get('/api/health', (req, res) => {
  return res.json({
    status: 'ok',
    backend: 'Smart Monitoring System',
    timestamp: new Date().toISOString(),
  });
});

app.get('/api/health/db', async (req, res) => {
  try {
    const rows = await query('SELECT 1 AS ok');
    return res.json({
      status: 'ok',
      database: process.env.MYSQL_DATABASE || 'smart_monitoring',
      timestamp: new Date().toISOString(),
      result: rows[0],
    });
  } catch (error) {
    return res.status(500).json({
      status: 'error',
      database: process.env.MYSQL_DATABASE || 'smart_monitoring',
      timestamp: new Date().toISOString(),
      message: error.message,
    });
  }
});

const port = Number(process.env.PORT || 3000);
initDb()
  .then(() => {
    app.listen(port, () => {
      console.log(`Smart Monitoring backend listening on port ${port}`);
    });
  })
  .catch((error) => {
    console.error('Failed to initialize MySQL connection:', error);
    process.exit(1);
  });
