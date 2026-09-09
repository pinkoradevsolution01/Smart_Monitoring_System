const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const express = require('express');
const cors = require('cors');
const os = require('os');
const { initDb, query } = require('./db');
const { attachOptionalSession } = require('./security/session_tokens');
const authRouter = require('./routes/auth');
const developerRouter = require('./routes/developer');
const businessRouter = require('./routes/business');
const licenseRouter = require('./routes/license');
const syncRouter = require('./routes/sync');
const crudRouter = require('./routes/crud');
const analyticsRouter = require('./routes/analytics');

const app = express();
const allowedOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
app.use(cors({
  origin(origin, callback) {
    // Non-browser clients (Flutter/server-to-server) do not send Origin.
    if (!origin || allowedOrigins.includes(origin) || (allowedOrigins.length === 0 && process.env.NODE_ENV !== 'production')) return callback(null, true);
    return callback(new Error('Origin is not permitted by CORS policy.'));
  },
  credentials: true,
}));
app.use(express.json({ limit: '5mb' }));

app.use(attachOptionalSession);

app.use('/api/auth', authRouter);
app.use('/api/developer', developerRouter);
app.use('/api/business', businessRouter);
app.use('/api/license', licenseRouter);
app.use('/api/sync', syncRouter);
app.use('/api/analytics', analyticsRouter);
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
const host = process.env.HOST || '0.0.0.0';

function getLanIps() {
  const interfaces = os.networkInterfaces();
  const ips = [];

  for (const entries of Object.values(interfaces)) {
    for (const entry of entries || []) {
      if (entry && entry.family === 'IPv4' && !entry.internal) {
        ips.push(entry.address);
      }
    }
  }

  return [...new Set(ips)];
}

if (!process.env.GOOGLE_CLIENT_ID || !process.env.GOOGLE_CLIENT_SECRET) {
  console.warn(
    '⚠️ Google OAuth is not fully configured. Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in backend/.env for Developer Dashboard Google sign-in.',
  );
}

if (!process.env.GOOGLE_CALLBACK_URL || !process.env.WEB_ANALYTICS_URL) {
  console.warn('Google Web Analytics OAuth requires GOOGLE_CALLBACK_URL and WEB_ANALYTICS_URL.');
}

initDb()
  .then(() => {
    app.listen(port, host, () => {
      console.log(`Smart Monitoring backend listening on ${host}:${port}`);
      console.log(`Local health check: http://localhost:${port}/api/health`);
      console.log(`Android emulator: http://10.0.2.2:${port}/api`);
      console.log(`Physical device base URL: http://<laptop-ip>:${port}/api`);

      const lanIps = getLanIps();
      if (lanIps.length > 0) {
        console.log('LAN API URLs:');
        for (const ip of lanIps) {
          console.log(`  http://${ip}:${port}/api`);
        }
      } else {
        console.log(
          'No LAN IP detected. If you are using a physical phone, set BACKEND_API_BASE_URL to your laptop IP.',
        );
      }
    });
  })
  .catch((error) => {
    console.error('Failed to initialize MySQL connection:', error);
    process.exit(1);
  });
