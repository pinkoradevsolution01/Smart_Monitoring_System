# Droplet Backend Restart And Update Guide

This guide explains how to update, restart, and verify the Smart Monitoring System backend on the DigitalOcean Droplet.

## Code-Only Backend Fixes

For fixes that only change backend source files, such as the CCTV restore fix:

- Update/redeploy the backend code and restart the PM2 process.
- Do not change `backend/.env` unless environment variables were changed explicitly.
- Rebuild/restart the Flutter app when the fix also changes client-side Dart code.

The complete command sequence is provided in Section 13 below.

## 1. SSH Into The Droplet

```bash
ssh root@152.42.185.35
```

## 2. Go To The Project

```bash
cd /root/Smart_Monitoring_System
```

## 3. Pull Latest Code

```bash
git pull origin main
```

If Git says there are local changes, review them first:

```bash
git status
```

Do not reset or discard local changes unless you are sure they are not needed.

## 4. Install Backend Dependencies

Run this after pulling changes that modify `backend/package.json` or `backend/package-lock.json`.

```bash
cd /root/Smart_Monitoring_System/backend
npm install
```

## 5. Check Backend Environment

```bash
cd /root/Smart_Monitoring_System/backend
grep -n "MYSQL\|GOOGLE\|PORT\|HOST" .env
```

Important production values:

```env
PORT=3000
HOST=0.0.0.0
MYSQL_HOST=127.0.0.1
MYSQL_DATABASE=smart_monitoring
GOOGLE_BACKEND_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback
GOOGLE_OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback
GOOGLE_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback
```

## 6. Restart MySQL

Use the MySQL service name first:

```bash
sudo systemctl restart mysql
```

If the server uses `mysqld` instead:

```bash
sudo systemctl restart mysqld
```

Check status:

```bash
sudo systemctl status mysql
```

## 7. Restart Backend With PM2

```bash
cd /root/Smart_Monitoring_System/backend
pm2 restart smart-monitoring-backend --update-env
```

Check PM2 status:

```bash
pm2 status
```

Save the PM2 process list:

```bash
pm2 save
```

## 8. Check Logs

Show recent backend logs:

```bash
pm2 logs smart-monitoring-backend --lines 80
```

Exit the logs view with:

```text
Ctrl+C
```

Common healthy logs:

```text
Connected to MySQL database smart_monitoring at 127.0.0.1:3306
Smart Monitoring backend listening on 0.0.0.0:3000
```

## 9. Verify Local Backend

From the Droplet:

```bash
curl http://localhost:3000/api/health
```

Check database health:

```bash
curl http://localhost:3000/api/health/db
```

## 10. Verify Public HTTPS Backend

```bash
curl https://api.smartmonitoringsystem.store/api/health
```

Check public database health:

```bash
curl https://api.smartmonitoringsystem.store/api/health/db
```

Expected health response:

```json
{
  "status": "ok",
  "backend": "Smart Monitoring System"
}
```

## 11. Verify Google OAuth URL

```bash
curl "https://api.smartmonitoringsystem.store/api/auth/google/url?redirectUri=https://api.smartmonitoringsystem.store/api/auth/google/callback&state=test123"
```

The response should include:

```text
"success":true
"authUrl":"https://accounts.google.com/o/oauth2/v2/auth?..."
"response_type=code"
```

## 12. Restart Caddy Reverse Proxy

Use this if HTTPS or the domain proxy is not responding.

Validate config:

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

Reload Caddy:

```bash
sudo systemctl reload caddy
```

Restart Caddy:

```bash
sudo systemctl restart caddy
```

Check Caddy status:

```bash
sudo systemctl status caddy
```

Current Caddy reverse proxy should route:

```text
https://api.smartmonitoringsystem.store -> http://127.0.0.1:3000
```

## 13. Full Update Command Sequence

Use this for a normal backend update:

```bash
cd /root/Smart_Monitoring_System
git pull origin main
cd backend
npm install
sudo systemctl restart mysql || sudo systemctl restart mysqld
pm2 restart smart-monitoring-backend --update-env
pm2 status
curl https://api.smartmonitoringsystem.store/api/health
curl https://api.smartmonitoringsystem.store/api/health/db
```

## 14. Troubleshooting

If backend is offline:

```bash
pm2 status
pm2 logs smart-monitoring-backend --lines 80
```

If MySQL is not connected:

```bash
sudo systemctl status mysql
curl http://localhost:3000/api/health/db
```

If HTTPS fails:

```bash
sudo systemctl status caddy
sudo caddy validate --config /etc/caddy/Caddyfile
curl http://localhost:3000/api/health
curl https://api.smartmonitoringsystem.store/api/health
```

If Google OAuth fails:

```bash
grep -n "GOOGLE" /root/Smart_Monitoring_System/backend/.env
curl "https://api.smartmonitoringsystem.store/api/auth/google/url?redirectUri=https://api.smartmonitoringsystem.store/api/auth/google/callback&state=test123"
```

Confirm Google Cloud Console has this exact Authorized redirect URI:

```text
https://api.smartmonitoringsystem.store/api/auth/google/callback
```
