# Droplet MySQL Commands

This guide contains common MySQL commands for checking and managing the Smart Monitoring System database on the DigitalOcean Droplet.

## 1. Connect To The Droplet

From your local machine:

```bash
ssh root@152.42.185.35
```

## 2. Go To The Backend Folder

```bash
cd /root/Smart_Monitoring_System/backend
```

## 3. Check Backend Database Settings

```bash
grep -n "MYSQL" .env
```

Expected values:

```env
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=pinkoradev01
MYSQL_DATABASE=smart_monitoring
```

## 4. Login To MySQL

Using the backend database user:

```bash
mysql -u pinkoradev01 -p smart_monitoring
```

Then enter the MySQL password from `backend/.env`.

If that does not work, try root:

```bash
mysql -u root -p
```

Then select the database:

```sql
USE smart_monitoring;
```

## 5. Basic Database Commands

Show all databases:

```sql
SHOW DATABASES;
```

Use the Smart Monitoring database:

```sql
USE smart_monitoring;
```

Show all tables:

```sql
SHOW TABLES;
```

Describe a table structure:

```sql
DESCRIBE users;
```

Show the current selected database:

```sql
SELECT DATABASE();
```

Exit MySQL:

```sql
EXIT;
```

## 6. Check Common Tables

Users:

```sql
SELECT id, email, role, full_name, is_active, created_at FROM users;
```

Businesses:

```sql
SELECT * FROM businesses;
```

Subscriptions:

```sql
SELECT * FROM subscriptions;
```

Subscription records:

```sql
SELECT * FROM subscription_records;
```

Activation codes:

```sql
SELECT code, status, email, used_at, expires_at FROM activation_codes ORDER BY created_at DESC LIMIT 20;
```

Products:

```sql
SELECT id, business_id, name, price, quantity FROM products LIMIT 20;
```

Sales:

```sql
SELECT id, business_id, total, payment_method, created_at FROM sales ORDER BY created_at DESC LIMIT 20;
```

## 7. Count Records

Count users:

```sql
SELECT COUNT(*) AS total_users FROM users;
```

Count subscriptions:

```sql
SELECT COUNT(*) AS total_subscriptions FROM subscriptions;
```

Count businesses:

```sql
SELECT COUNT(*) AS total_businesses FROM businesses;
```

Count products:

```sql
SELECT COUNT(*) AS total_products FROM products;
```

## 8. Search Records

Find a user by email:

```sql
SELECT id, email, role, full_name, is_active FROM users WHERE email = 'jaybe.gubot01@gmail.com';
```

Find activation code:

```sql
SELECT * FROM activation_codes WHERE code = 'PASTE_CODE_HERE';
```

Find records by business:

```sql
SELECT * FROM users WHERE business_id = 'PASTE_BUSINESS_ID_HERE';
```

## 9. Quick One-Line Commands From Linux Shell

Show tables without entering MySQL shell:

```bash
mysql -u pinkoradev01 -p -e "USE smart_monitoring; SHOW TABLES;"
```

Count users:

```bash
mysql -u pinkoradev01 -p -e "USE smart_monitoring; SELECT COUNT(*) AS total_users FROM users;"
```

Check backend health:

```bash
curl https://api.smartmonitoringsystem.store/api/health
```

Check database health through backend:

```bash
curl https://api.smartmonitoringsystem.store/api/health/db
```

## 10. Backup Database

Create a SQL backup:

```bash
mysqldump -u pinkoradev01 -p smart_monitoring > smart_monitoring_backup.sql
```

Create a timestamped backup:

```bash
mysqldump -u pinkoradev01 -p smart_monitoring > smart_monitoring_$(date +%Y%m%d_%H%M%S).sql
```

## 11. Restore Database

Restore from a backup file:

```bash
mysql -u pinkoradev01 -p smart_monitoring < smart_monitoring_backup.sql
```

Use restore carefully because it can overwrite existing data depending on the SQL file contents.

## 12. Restart Services

Restart MySQL:

```bash
sudo systemctl restart mysql
```

If the service name is different:

```bash
sudo systemctl restart mysqld
```

Restart backend:

```bash
pm2 restart smart-monitoring-backend --update-env
```

Check backend logs:

```bash
pm2 logs smart-monitoring-backend --lines 80
```

Check backend status:

```bash
pm2 status
```

## 13. Safety Notes

- Run `SELECT` commands first before using `UPDATE` or `DELETE`.
- Create a backup before changing production data.
- Do not share `.env` publicly because it contains database and Google credentials.
- Prefer backend API actions for normal app workflows, and use direct MySQL only for inspection, backup, restore, or emergency fixes.

