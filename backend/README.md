# Smart Monitoring System Backend

This backend provides a Node.js REST API for the Smart Monitoring System, replacing Supabase with a MySQL-backed API.

## Features

- License activation via `POST /api/license/activate`
- Business onboarding via `POST /api/business/init`
- Data sync push/pull via `POST /api/sync/push` and `GET /api/sync/pull`
- Basic authentication via `POST /api/auth/login`

## Setup
 
1. Copy `.env.example` to `.env`.
2. Configure MySQL credentials and JWT secret.
3. Create the database and tables:
   - `mysql -u root -p < backend/schema.sql`
4. Install dependencies:
   - `cd backend && npm install`
5. Start the server:
   - `npm start`

## API Endpoints

- `GET /api/health`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/business/init`
- `POST /api/license/activate`
- `GET /api/license/code/:code`
- `POST /api/sync/push`
- `GET /api/sync/pull?businessId=<id>`

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
