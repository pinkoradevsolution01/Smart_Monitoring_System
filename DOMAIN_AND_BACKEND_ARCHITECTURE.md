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
