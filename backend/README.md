# Smart Monitoring System Backend

This backend provides a Node.js REST API for the Smart Monitoring System, replacing Supabase with a MySQL-backed API.

## Features

- License activation via `POST /api/license/activate`
- Business onboarding via `POST /api/business/init`
- Data sync push/pull via `POST /api/sync/push` and `GET /api/sync/pull`
- CRUD endpoints for business data via `/api/customers`, `/api/cameras`, `/api/restock-records`, and related resources
- Basic authentication via `POST /api/auth/login`
- Google owner registration via `POST /api/auth/google/register-owner`
- Owner profile updates via `PATCH /api/auth/users/:id`
- Owner password changes via `PATCH /api/auth/users/:id/password`
- Owner deletion via `DELETE /api/auth/users/:id`

## Setup
 
1. Copy `.env.example` to `.env`.
2. Configure MySQL credentials and JWT secret in `backend/.env`.
   - If MySQL is already installed on this laptop, you can skip any install step and just point the backend at the existing server.
   - For a local XAMPP setup on this laptop, set `MYSQL_HOST=localhost`.
   - For a physical Android/iPhone device on the same Wi-Fi, make sure the Node server binds to `0.0.0.0` so it accepts LAN connections.
3. Create the database and tables:
   - `mysql -u root -p < backend/schema.sql`
4. Install dependencies:
   - `cd backend && npm install`
5. Start the server:
   - `cd backend && npm start`
   - Or run `start_backend.bat` from the repo root to start local XAMPP MySQL first, then launch the backend.

## Deploy To DigitalOcean

If you want this backend to run on a DigitalOcean droplet instead of your laptop, the easiest setup is:

1. Create a **Basic Droplet** with **Ubuntu 22.04 LTS**.
2. Pick the nearest region to your users, such as **Singapore**.
3. Add your **SSH key** during setup, or set a strong root password if you are just testing.
4. SSH into the droplet after it finishes provisioning.
5. Install the backend runtime and database tools on the droplet:
   - Node.js 20+
   - MySQL Server 8+
   - `git`
6. Clone this repository onto the droplet.
7. Create `backend/.env` on the droplet and point it at the droplet's MySQL instance:
   - `PORT=3000`
   - `HOST=0.0.0.0`
   - `MYSQL_HOST=127.0.0.1`
   - `MYSQL_PORT=3306`
   - `MYSQL_USER=<your-mysql-user>`
   - `MYSQL_PASSWORD=<your-mysql-password>`
   - `MYSQL_DATABASE=smart_monitoring`
   - `JWT_SECRET=<a-long-random-secret>`
8. Import the schema into MySQL:
   - `mysql -u root -p smart_monitoring < backend/schema.sql`
9. Start the backend:
   - `cd backend && npm install`
   - `npm start`
10. Keep it running with a process manager such as `pm2` or a `systemd` service.
11. Open port `3000` in the droplet firewall, or put Nginx in front of the Node.js app if you want HTTPS and a clean public URL.

After that, your Flutter app should point to the droplet API base URL, for example:

- `http://<your-droplet-ip>:3000/api`
- or `https://api.yourdomain.com/api` if you add a domain and reverse proxy later.

## Verify

- `GET /api/health` checks whether the backend is running.
- `GET /api/health/db` checks whether the backend can query MySQL.
- For a phone on the same network, set the Flutter app's base URL to
  `http://192.168.1.9:3000/api`.
- For the Android emulator, use `http://10.0.2.2:3000/api`.
- If the phone still gets `Connection refused`, confirm Windows Firewall allows inbound TCP port `3000` and that the backend process is not bound to `localhost` only.

Example:

```bash
curl http://localhost:3000/api/health/db
```

## API Endpoints

- `GET /api/health`
- `GET /api/health/db`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/google/register-owner`
- `PATCH /api/auth/users/:id`
- `PATCH /api/auth/users/:id/password`
- `DELETE /api/auth/users/:id`
- `POST /api/business/init`
- `POST /api/license/activate`
- `GET /api/license/code/:code`
- `POST /api/license/codes/import`
- `POST /api/sync/push`
- `GET /api/sync/pull?businessId=<id>`
- `GET /api/customers?businessId=<id>`
- `POST /api/customers`
- `PATCH /api/customers/:id`
- `DELETE /api/customers/:id`
- `GET /api/loyalty-ledger?businessId=<id>`
- `GET /api/cameras?businessId=<id>`
- `GET /api/cctv-timestamps?businessId=<id>`
- `GET /api/attendance-entries?businessId=<id>`
- `GET /api/attendance-leaves?businessId=<id>`
- `GET /api/attendance-schedule?businessId=<id>`
- `GET /api/restock-records?businessId=<id>`
- `GET /api/purchase-order-items?businessId=<id>`
- `GET /api/activity-logs?businessId=<id>`
- `GET /api/products?businessId=<id>`
- `GET /api/suppliers?businessId=<id>`
- `GET /api/sales?businessId=<id>`
- `GET /api/sale-items?businessId=<id>`
- `GET /api/purchase-orders?businessId=<id>`
- `GET /api/inventory-movements?businessId=<id>`
- `GET /api/damage-reports?businessId=<id>`

## Notes

- This backend is intentionally simple and designed as a starting point for migrating from Supabase to a Node.js/MySQL architecture.
- The `schema.sql` file now mirrors the Supabase/Postgres tables used by the app, including:
  - `activation_codes`
  - `activation_code_requests`
  - `email_otps`
  - `developer_notification_settings`
  - `subscriptions`
  - `subscription_records`
  - `subscription_renewals`
  - `businesses`
  - `products`
  - `sales`
  - `sale_items`
  - `purchase_orders`
  - `inventory_movements`
  - `damage_reports`
  - `suppliers`
  - `cameras`
  - `cctv_timestamps`
- The `users` table includes `contact_number` and `auth_method` for owner profile and Google/password account tracking.
- Imported activation codes should start as `unused`; the backend flips them to `used` when a customer activates a code.
- Business-scoped CRUD endpoints require `businessId` on reads and writes so records stay isolated per tenant.

## Migrating From Supabase

If your current production data is still in Supabase/Postgres:

1. Create the MySQL schema with `backend/schema.sql`.
2. Add `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to `backend/.env`.
3. Run the one-time migration script:
   - `cd backend && npm install`
   - `npm run migrate:supabase`
4. Verify the imported tables in MySQL and confirm data integrity.
5. Point the app and backend to the MySQL API for all cloud reads and writes.

Notes:

- MySQL does not provide Supabase Row Level Security, so authorization has to move into the backend API layer.
- The frontend still contains some direct Supabase calls for cloud features. Those will need to be routed through the backend before a full cutover.
- Migrate the remaining Supabase auth/OAuth flow into backend endpoints rather than keeping OAuth logic in the client.
