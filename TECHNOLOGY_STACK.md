# Technology Stack

Smart Monitoring System is a cross-platform, offline-capable business and monitoring application. Its production stack combines a Flutter client, a Node.js REST API, local SQLite storage, MySQL server storage, and a DigitalOcean-hosted backend. Supabase is not the current cloud platform.

## Production architecture

```text
Flutter apps (Dart: mobile, desktop, web)
  |-- Local/offline data: SQLite
  |-- HTTPS REST API: api.smartmonitoringsystem.store
  |     `-- DigitalOcean Droplet (Ubuntu)
  |            |-- Caddy reverse proxy
  |            |-- Node.js + Express API, managed by PM2
  |            `-- MySQL Server 8+
  `-- External integrations: Google Drive/Google Sign-In, Resend or Gmail SMTP, CCTV streams
```

## Client application

| Area | Technologies used |
| --- | --- |
| Framework and language | Flutter and Dart (SDK constraint `^3.10.0`) |
| Platforms | Android, iOS, web, Windows, macOS, and Linux |
| User interface | Flutter Material and Cupertino widgets; Inter variable font |
| Dependency injection | GetIt |
| State | `ValueNotifier` and `ChangeNotifier` in applicable app modules |
| Local storage | SQLite through `sqflite`; `sqflite_common_ffi` on desktop; `shared_preferences` for settings |
| Networking | `http` and `connectivity_plus` |
| Charts and localization | `fl_chart` and `intl` |
| Reports | `pdf` and `printing` |
| Barcode and QR | `mobile_scanner` and `barcode_widget` |
| Media and CCTV | `camera`, `video_player`, and `flutter_vlc_player` |
| Files | `path_provider`, `file_picker`, `image_picker`, and `share_plus` |
| Device and platform access | `permission_handler`, `local_auth`, `device_info_plus`, `ffi`, and `win32` |

## Backend and database

| Area | Technologies used |
| --- | --- |
| Runtime | Node.js 20+ |
| API framework | Express 4 |
| API style | JSON REST API with CORS controls |
| Database | MySQL Server 8+ |
| Database access | `mysql2` with a promise-based connection pool |
| Authentication | JWT sessions (`jsonwebtoken`, HS256) and `bcryptjs` password hashing |
| Configuration | Environment variables loaded by `dotenv` |
| Email | Resend over HTTPS for production outbound email; `nodemailer` is included in the API dependencies |
| Testing | Node.js built-in test runner (`node --test`) |

The API includes authentication, businesses, licensing, synchronization, analytics, financial-reporting, developer, and CRUD routes.

## Production hosting and operations

| Area | Technologies used |
| --- | --- |
| Cloud host | DigitalOcean Droplet |
| Operating system | Ubuntu 22.04 LTS |
| Process manager | PM2 (`smart-monitoring-backend`) |
| HTTPS and reverse proxy | Caddy |
| Public API domain | `api.smartmonitoringsystem.store` |
| Database location | MySQL runs on the Droplet and is accessed locally by the API |
| Source deployment | Git, with backend dependencies managed by npm |

Caddy forwards `https://api.smartmonitoringsystem.store` to the Express service at `http://127.0.0.1:3000`. PM2 keeps the API process running and provides restart and log management.

## External integrations

| Integration | Technologies used |
| --- | --- |
| Google authentication | Google OAuth and `google_sign_in`; the API performs OAuth token exchange and issues application JWTs |
| Cloud backup | Google Drive v3 through `googleapis` and `googleapis_auth` |
| Email | Resend; Gmail SMTP can be used where configured |
| CCTV | Network/video stream playback with VLC-backed Flutter support |

## Build and development tooling

| Area | Technologies used |
| --- | --- |
| Flutter packages | Pub (`pubspec.yaml` and `pubspec.lock`) |
| Backend packages | npm (`backend/package.json` and `package-lock.json`) |
| Android build | Gradle with Kotlin DSL, Java 17, and the Flutter Gradle plugin |
| Desktop builds | Flutter native runners and CMake for Windows, Linux, and macOS |
| Automation | PowerShell, Batch, Bash, and SQL migration scripts |

## Important source locations

- Flutter application: `lib/`
- Node.js API: `backend/`
- MySQL schema and migrations: `backend/schema.sql`, `backend/migrations/`, and `sql/`
- Production update guide: `DROPLET_BACKEND_RESTART_UPDATE.md`
- Backend environment template: `backend/.env.example`

## Notes

- The current production cloud architecture is DigitalOcean + Ubuntu + Caddy + PM2 + Node.js + MySQL.
- Supabase files and dependencies are retained only for legacy migration or older client workflows; they are not the current cloud platform.
- Keep database credentials, JWT secrets, OAuth credentials, and email keys in server environment variables; never commit them.
