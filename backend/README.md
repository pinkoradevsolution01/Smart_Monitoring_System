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
- The `schema.sql` file defines the core tables for activation codes, subscriptions, businesses, products, sales, suppliers, inventory movements, and damage reports.
