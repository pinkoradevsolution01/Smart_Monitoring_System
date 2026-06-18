require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initDb, query } = require('./db');
const authRouter = require('./routes/auth');
const businessRouter = require('./routes/business');
const licenseRouter = require('./routes/license');
const syncRouter = require('./routes/sync');
const crudRouter = require('./routes/crud');

const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.use('/api/auth', authRouter);
app.use('/api/business', businessRouter);
app.use('/api/license', licenseRouter);
app.use('/api/sync', syncRouter);
app.use('/api', crudRouter);

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

if (!process.env.GOOGLE_CLIENT_ID || !process.env.GOOGLE_CLIENT_SECRET) {
  console.warn(
    '⚠️ Google OAuth is not fully configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in backend/.env for Developer Dashboard Google sign-in.',
  );
}

if (!process.env.GOOGLE_REDIRECT_URI) {
  console.warn(
    '⚠️ GOOGLE_REDIRECT_URI is not set. Google sign-in will require redirectUri to be passed by the client.',
  );
}

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
