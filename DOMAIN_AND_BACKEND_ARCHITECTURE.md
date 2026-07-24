# Domain, Backend, and Software Stack Guide

This document summarizes the software stack already used in the Smart Monitoring System and explains the recommended deployment architecture for the website, backend API, and domain.

## 1. Software Stack Already Used In This System

### Frontend Application

- **Flutter** for the cross-platform client
- **Dart** as the application language
- **Material UI** and custom screens for admin, owner, cashier, inventory, and developer workflows
- Supported platforms:
  - Android
  - iOS
  - Windows
  - macOS
  - Linux
  - Web

### Local Data and State

- **SQLite** via `sqflite` and `sqflite_common_ffi`
- **SharedPreferences** for small persisted settings
- **GetIt** for dependency injection
- **ValueNotifier / ChangeNotifier** for state management in parts of the app

### Backend API

- **Node.js**
- **Express**
- **MySQL**
- **JWT** for authentication
- **CORS**
- **dotenv** for environment configuration
- **bcryptjs** for password hashing
- **nodemailer** for email workflows

### Cloud and External Services Already Present

- **Supabase**
  - activation and licensing workflows
  - password reset and OTP-related functions
  - cross-device sync support in some flows
- **Google OAuth / Google Sign-In**
  - owner and developer login flows
  - Google Drive-related backup integration in the client
- **Firebase**
  - referenced in setup and fix documents
  - used in some existing workflows and setup notes
- **Cloud/video and media features**
  - camera
  - video player
  - VLC-based playback
  - barcode scanning
  - PDF generation and printing

### Development and Deployment Helpers

- Windows batch scripts for backend launch and autostart
- PowerShell scripts for setup and migration
- SQL scripts for schema and feature rollout
- Flutter build scripts for desktop and mobile

## 2. What The Current Backend Actually Is

The repository already contains a working backend service in `backend/`.

### Backend entry point

- `backend/app.js`
- Starts an Express API server
- Exposes health checks like `/api/health` and `/api/health/db`
- Mounts routes for:
  - auth
  - developer
  - business
  - license
  - sync
  - CRUD operations

### Backend database layer

- `backend/db.js`
- MySQL-backed persistence
- Reads connection values from `backend/.env`

### Backend runtime requirements

- Node.js 20+ recommended
- MySQL Server 8+ recommended
- A reachable host/port for the API
- Environment variables such as:
  - `PORT`
  - `HOST`
  - `MYSQL_HOST`
  - `MYSQL_PORT`
  - `MYSQL_USER`
  - `MYSQL_PASSWORD`
  - `MYSQL_DATABASE`
  - `JWT_SECRET`

## 3. Is Cloudflare Required?

No. **Cloudflare is not required** for this system.

You only need a registrar and DNS service that can point your domain to the correct target.

### You can use:

- **Vercel** for domain registration and web hosting
- **DigitalOcean** for backend hosting on a Droplet
- **Cloudflare** if you want its DNS, proxy, SSL, or security features
- Any other registrar if it supports the domain you want

### Practical rule

- If you buy the domain through **Vercel**, Vercel can manage the domain and hosting together.
- If you buy the domain elsewhere, you can still point it to Vercel or DigitalOcean using DNS.
- Cloudflare is an option, not a requirement.

## 4. Recommended Architecture For Your Use Case

Since you want:

- a website for web analytics
- a domain name
- a backend for the Smart Monitoring System

the cleanest setup is:

### Option A. Simple Production Setup

- **Domain**: Vercel or another registrar
- **Website**: Vercel
- **Backend API**: DigitalOcean Droplet
- **Database**: MySQL on the Droplet, or another managed MySQL provider

This is a good choice if:

- the website is mostly frontend
- the backend must stay always on
- you want a separate API server for the mobile/desktop app

### Option B. All-in-One DNS With Cloudflare

- **Domain**: any registrar
- **DNS**: Cloudflare
- **Website**: Vercel
- **Backend API**: DigitalOcean Droplet

This is useful if you want:

- extra DNS control
- proxy protection
- easier future migration

But again, this is optional.

## 5. Recommended Backend Architecture

If the backend is required in production, use this structure:

```text
Users / App / Web Analytics Site
        |
        v
Custom Domain
        |
        +----------------------+
        |                      |
        v                      v
Vercel Website            Backend API on Droplet
                              |
                              v
                         MySQL Database
                              |
                              v
                 Optional Supabase / Google / Email APIs
```

### Why this architecture works

- **Vercel** is best for the public website and static or server-rendered frontend pages
- **DigitalOcean Droplet** is better for a persistent Node.js backend process
- **MySQL** keeps the app data in one centralized backend store
- **Supabase** can remain for specific workflows already implemented in the codebase

## 6. When You Do Not Need A Backend

You may not need the Droplet immediately if:

- the website is only a marketing or analytics front-end
- the app is still running locally during development
- you are not exposing live API endpoints to users yet

In that case, you can:

- use **Vercel only** for the website
- keep the backend on your laptop during development
- move the backend to a Droplet later when production is ready

## 7. Recommended Decision

For your current goal, the recommended path is:

1. Use **Vercel** for the website and domain if you want the simplest setup.
2. Use a **DigitalOcean Droplet** if you need a permanent backend API.
3. Skip Cloudflare unless you specifically want its DNS/proxy/security layer.

## 8. Short Answer

- **Cloudflare is not required**
- **Vercel can handle the website and domain**
- **DigitalOcean Droplet is useful for the backend API**
- **MySQL is still needed for backend data storage**

## 9. Flutter Run And Build Commands

Use these commands after the production API is available at:

```text
https://api.smartmonitoringsystem.store/api
```

### Run On Windows

```bash
flutter run -d windows --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

### Build Windows Release

```bash
flutter build windows --release --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

### Run On Android

```bash
flutter run -d android --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```
```bash
flutter run -d 10HF2HFM1Y0003Q --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

### Build Android APK

```bash
flutter build apk --release --dart-define=BACKEND_API_BASE_URL=https://api.smartmonitoringsystem.store/api --dart-define=OAUTH_REDIRECT_URI=https://api.smartmonitoringsystem.store/api/auth/google/callback --dart-define=GOOGLE_WEB_CLIENT_ID=961390569053-ol7mutt2h2bp7eb0608041aeh824btcm.apps.googleusercontent.com
```

## 10. Files In This Repo That Support This Architecture

- [`backend/app.js`](backend/app.js)
- [`backend/package.json`](backend/package.json)
- [`backend/README.md`](backend/README.md)
- [`pubspec.yaml`](pubspec.yaml)
- [`SYSTEM_DOCUMENTATION.md`](SYSTEM_DOCUMENTATION.md)
- [`SYSTEM_ARCHITECTURE.md`](SYSTEM_ARCHITECTURE.md)

## 11. Recent Backend and Domain Features

The production backend now includes the following flows in addition to the
original CRUD and synchronization endpoints.

### Owner PIN/password reset token flow

Owner PIN reset authorization is handled by the Node.js API and email service:

1. The client submits an owner email to `POST /api/auth/owner-pin-reset/request`.
2. The backend returns a generic response so the endpoint does not reveal
   whether an email belongs to an owner account.
3. For an active owner, the backend creates a cryptographically random token,
   stores only its SHA-256 hash in `owner_pin_reset_tokens`, and sends the raw
   token through SMTP using Nodemailer.
4. Tokens expire after 20 minutes. Any previous unused token for the owner is
   invalidated before a new token is created.
5. The client submits the email, token, and new four-digit PIN to
   `POST /api/auth/owner-pin-reset/verify`.
6. The backend validates the token hash, owner account, expiry, and unused
   state, then atomically marks the token as used. The client persists the new
   local PIN only after successful authorization.

Required email environment variables are `SMTP_HOST`, `SMTP_PORT`,
`SMTP_USER`, `SMTP_PASS`, and `FROM_EMAIL`. The flow is implemented in
`backend/routes/auth.js` and uses the `owner_pin_reset_tokens` table defined in
`backend/schema.sql`.

### Google OAuth token exchange

Google login uses a short-lived authorization code. The backend exchanges that
code exactly once at `GET /api/auth/google/callback` or
`POST /api/auth/google/exchange`, verifies the returned Google ID token, and
issues the application JWT. The configured Google client credentials and
redirect URI must belong to the same OAuth client. A stale, reused, or
refreshed callback URL can produce Google's `invalid_grant` response.

### One-Time License and SaaS subscription modes

Package activation supports two entitlement models:

- **One-Time License**: the selected package is stored as
  `subscription_mode = one_time_license`; the subscription has no expiry and
  Settings displays perpetual access.
- **SaaS Monthly Subscription**: the selected package is stored as an active
  subscription with a 30-day expiry, monthly pricing, and renewal handling.

Premium and Enterprise packages use a negative product limit to represent
unlimited products. Product-limit checks treat negative limits as unlimited;
Basic and Standard retain their finite limits. The backend also records the
license type and subscription expiry in the activation flow.

### Persistent subscriber cancellation

Subscriber deactivation is a status-preserving CRUD operation:

- `subscriptions.status` is set to `cancelled`.
- `subscription_records.status` is set to `cancelled`.
- The cancelled email is recorded in `cancelled_subscribers` so it cannot
  register or log in again through Google or password authentication.
- Activation requests are retained and marked cancelled rather than deleted.
- Subscription renewal rows are removed while the subscription history remains.
- Developer Subscribers and Subscription Records display the cancelled status.
- Cancelled records are not considered active during synchronization.

The migration `sql/subscription_cancellation_and_perpetual_license.sql` makes
subscription expiry nullable for perpetual licenses and backfills historical
subscription records. It must be applied once to an existing MySQL database.

### Safe synchronization after deactivation

The client can still have queued data after a business is deactivated. Before
processing `POST /api/sync/push`, the backend verifies that the referenced
business still exists. If it has been intentionally purged, the API returns a
successful skipped response instead of inserting orphaned child rows. This
prevents foreign-key errors in attendance schedules and other business-owned
tables and avoids recreating access for a cancelled subscriber.

### Operational deployment sequence

After backend or schema changes are pushed to GitHub:

```bash
cd /root/Smart_Monitoring_System
git pull --ff-only origin main
mysql -u YOUR_MYSQL_USER -p smart_monitoring < sql/subscription_cancellation_and_perpetual_license.sql
pm2 restart smart-monitoring-backend
pm2 save
```

Verify the service with `pm2 status`, `pm2 logs smart-monitoring-backend`, and
`https://api.smartmonitoringsystem.store/api/health`.
