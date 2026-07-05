# Smart Monitoring System Documentation

## Overview

Smart Monitoring System is a cross-platform Flutter application with a Node.js/MySQL backend and Supabase integration for licensing, password reset, and cloud-related workflows. It is designed for retail and monitoring operations, combining point-of-sale, inventory control, customer management, CCTV monitoring, attendance, payroll, subscription licensing, and multi-device sync in one system.

The app runs on:

- Windows
- Android
- iOS
- macOS
- Linux
- Web

The codebase is organized so that business data can work locally first, while selected services can sync to a shared backend or cloud services when configured.

## Core Goals

- Run daily store operations from one app.
- Separate responsibilities by role.
- Support offline-first local workflows.
- Keep business data isolated by `businessId`.
- Enforce licensing and subscription access.
- Allow cloud sync and backup/restore where enabled.
- Support monitoring, delivery, and reporting workflows.

## System Architecture

The system has three major layers:

1. Flutter front end
2. Node.js backend API
3. Database and cloud services

### Flutter Front End

The Flutter app provides:

- Role-based dashboards
- Shared screens for login, settings, inventory, manuals, and licensing
- POS and cashier interfaces
- Owner, admin, manager, inventory, sales, delivery, and developer screens
- CCTV viewing and timestamp tools
- Customer, supplier, attendance, payroll, and reporting screens

Key app infrastructure:

- `GetIt` for dependency injection
- `sqflite` and `sqflite_common_ffi` for local storage
- `shared_preferences` for settings such as theme, locale, and motion preferences
- `app_links` for handling deep links and recovery/password reset callbacks
- `supabase_flutter` for selected authentication and reset flows

### Node.js Backend

The backend provides a REST API for:

- Authentication
- Business initialization
- License activation
- Cloud sync push/pull
- CRUD access for business-scoped entities
- Developer account management

The backend uses:

- `express`
- `mysql2/promise`
- `bcryptjs`
- `jsonwebtoken`
- `cors`

### Database and Cloud Services

The system supports:

- Local SQLite storage for app-side data
- MySQL for the Node backend
- Supabase for selected auth and activation workflows
- Google OAuth for owner and developer login flows
- Gmail/SMTP for email delivery
- Google Drive for backup workflows

## User Roles

The system is built around role-based access.

### Admin

Admin users manage the system configuration and user base. Typical capabilities include:

- Admin dashboard access
- User management
- Product management
- Attendance management
- Payroll
- Reports
- System settings

### Owner

The owner role has business-wide access, including:

- Sales reports
- Inventory oversight
- CCTV monitoring
- Backup and restore
- Customer management
- Loyalty rewards
- Supplier management
- Delivery and POS-related workflows
- Account management

### Manager

The manager role focuses on operations oversight:

- Sales reports and analytics
- POS access
- Inventory oversight
- Supplier management
- CCTV access where allowed by package
- Backup and restore where allowed by package
- Attendance tracking

### Cashier

Cashiers handle checkout and transaction workflows:

- POS
- Cart management
- Receipt preview and printing
- E-wallet transfer flow
- Price checking
- Attendance clock-in/out

### Sales Promoter

Sales promoters are focused on customer-facing selling:

- POS access
- Price checker
- Delivery order workflows
- Attendance clock-in/out

### Inventory Clerk

Inventory clerks manage stock-related tasks:

- Inventory screening
- Product updates
- Supplier coordination
- Delivery processing
- Restock and stock movement workflows
- Attendance clock-in/out

### Delivery Receiver

Delivery receivers handle incoming stock and delivery verification:

- Receive deliveries
- Verify items
- Update delivery status
- Coordinate with suppliers
- Attendance clock-in/out

### Developer

The developer role manages subscriptions and activation infrastructure:

- Activation code generation
- Activation requests
- Code revocation
- Subscriber management
- Subscription records
- Developer account management
- Activity logs
- Supabase connection test

## Main Modules and Features

## 1. Authentication and Access Control

The system supports multiple sign-in and access paths:

- Standard login
- Admin login
- Owner login
- Developer login
- Google-based owner registration and login flows
- Developer Google sign-in flows
- License and trial validation
- Trial lock screen when access expires
- Deep-link password reset handling

Related screens and services:

- `lib/screens/auth/login_screen.dart`
- `lib/screens/shared/developer_auth_screen.dart`
- `lib/screens/shared/trial_locked_screen.dart`
- `lib/screens/shared/license_test_screen.dart`
- `lib/services/license_service.dart`
- `lib/services/google_auth_service.dart`
- `lib/services/password_reset_service.dart`
- `lib/services/otp_service.dart`
- `lib/services/windows_auth_service.dart`

## 2. Business Onboarding

Business onboarding allows the system to initialize a tenant/business record and attach owner data to it.

Included features:

- Business registration
- Owner registration
- Business initialization from the backend
- Business-scoped data separation

Related files:

- `lib/screens/admin/business_registration_screen.dart`
- `lib/screens/shared/owner_registration_screen.dart`
- `backend/routes/business.js`

## 3. Point of Sale

The POS module covers the core checkout workflow.

Features include:

- Product browsing
- Search
- Cart management
- Quantity adjustment
- Checkout
- Discount handling
- Receipt preview
- Printing
- E-wallet transfer support
- Delivery-oriented sales flow

Related screens and widgets:

- `lib/screens/cashier/cashier_pos.dart`
- `lib/screens/owner/delivery_pos.dart`
- `lib/screens/cashier/ewallet_transfer_screen.dart`
- `lib/screens/cashier/ewallet_receipt_preview_screen.dart`
- `lib/screens/shared/receipt_preview_screen.dart`
- `lib/screens/cashier/widgets/cart_sheet.dart`
- `lib/screens/owner/widgets/delivery_cart_sheet.dart`
- `lib/services/pos_service.dart`
- `lib/utils/receipt_generator.dart`
- `lib/utils/print_settings.dart`

## 4. Inventory Management

Inventory is one of the main system pillars.

Features include:

- Product creation and editing
- Product image capture or selection
- Inventory browsing
- Stock updates
- Inventory movement tracking
- Restock workflows
- Damaged item handling
- Shoe size support
- Barcode scanning
- Product camera support

Related screens and services:

- `lib/screens/shared/inventory_screen.dart`
- `lib/screens/admin/manage_products.dart`
- `lib/screens/shared/product_camera_screen.dart`
- `lib/services/database_service.dart`
- `lib/services/customer_service.dart`
- `lib/services/seed_service.dart`
- `lib/utils/shoe_size_diagnostic.dart`

## 5. Customer and Loyalty Management

Customer-related features include:

- Customer profiles
- Barcode-based customer identifiers
- Points tracking
- Loyalty ledger history
- Loyalty rewards screen

Related files:

- `lib/screens/owner/customer_management_screen.dart`
- `lib/screens/owner/loyalty_rewards_screen.dart`
- `lib/models/customer.dart`
- `lib/models/loyalty_ledger_entry.dart`
- `lib/services/customer_service.dart`

## 6. Supplier and Procurement

Supplier and procurement features include:

- Supplier management
- Purchase orders
- Purchase order PDF generation
- Restock record tracking
- Supplier-linked delivery processing

Related files:

- `lib/screens/owner/supplier_management_screen.dart`
- `lib/screens/admin/manage_products.dart`
- `lib/services/purchase_order_pdf_service.dart`
- `lib/services/payroll_service.dart`
- `lib/models/purchase_order.dart`
- `lib/models/supplier.dart`

## 7. Attendance and HR

The system supports staff attendance and payroll-related workflows.

Features include:

- Clock in / clock out
- Daily attendance tracking
- Attendance history and logs
- Attendance archive support
- Attendance schedule data
- Leave-related records
- Payroll screen
- Bulk payroll processing

Related files:

- `lib/screens/admin/manage_attendance_screen.dart`
- `lib/screens/admin/payroll_screen.dart`
- `lib/screens/owner/owner_dashboard.dart`
- `lib/screens/manager/manager_dashboard.dart`
- `lib/screens/cashier/cashier_dashboard.dart`
- `lib/screens/inventory_clerk/inventory_clerk_dashboard.dart`
- `lib/screens/sales_promoter/sales_promoter_dashboard.dart`
- `lib/screens/delivery_receiver/delivery_receiver_dashboard.dart`
- `lib/services/attendance_service.dart`
- `lib/services/bulk_payroll_service.dart`
- `lib/services/payroll_service.dart`

## 8. Sales Reporting and Analytics

Reporting features are available for business oversight and decision-making.

Features include:

- Sales reports
- Inventory reports
- Activity logs
- Charts and visual summaries
- Business analytics

Related screens and services:

- `lib/screens/admin/reports_screen.dart`
- `lib/screens/owner/sales_report_screen.dart`
- `lib/services/shared_api_service.dart`
- `lib/services/database_inspector.dart`
- `lib/services/payroll_service.dart`

## 9. CCTV and Monitoring

The CCTV module supports store monitoring and timestamped event tracking.

Features include:

- Single and multi-camera support
- RTSP / HTTP / local video feed handling
- Camera configuration
- Camera ordering/positioning
- Video playback support
- CCTV timestamp markers
- QR code format support for camera/timestamp workflows

Related files:

- `lib/screens/owner/cctv_screen.dart`
- `lib/screens/owner/cctv_screen_backup.dart`
- `lib/widgets/camera_feed_widget.dart`
- `lib/widgets/camera_feed_fallback.dart`
- `lib/widgets/camera_player_widget.dart`
- `lib/services/cctv_service.dart`
- `lib/services/cctv_config.dart`
- `lib/services/cctv_config_manager.dart`
- `lib/models/camera.dart`
- `lib/models/cctv_timestamp.dart`

## 10. Cloud Sync and Multi-Device Support

The system supports shared data synchronization between devices.

Features include:

- Sync push
- Sync pull
- Business-scoped sync
- Multi-device setup
- Device status tracking
- Shared data management
- Cloud subscription-based package enforcement

Related files:

- `lib/services/supabase_sync_service.dart`
- `lib/services/cloud_subscription_service.dart`
- `lib/screens/shared/shared_data_screen.dart`
- `lib/services/shared_api_service.dart`
- `backend/routes/sync.js`
- `MULTI_DEVICE_SETUP.md`
- `MULTI_DEVICE_STATUS.md`
- `MULTI_DEVICE_SYNC_README.md`
- `CLOUD_SYNC_*` documentation files

## 11. Licensing, Activation, and Subscriptions

This system includes a complete activation-code workflow.

Features include:

- Activation code generation
- Activation code distribution
- Activation requests
- Activation notifications
- Activation code revocation
- Subscription records
- Subscriber management
- Demo access
- Trial expiry lock

Related files:

- `lib/screens/developer/activation_code_generator_screen.dart`
- `lib/screens/developer/activation_requests_screen.dart`
- `lib/screens/developer/code_revocation_screen.dart`
- `lib/screens/developer/subscribers_screen.dart`
- `lib/screens/developer/subscription_records_screen.dart`
- `lib/screens/developer/demo_access_screen.dart`
- `lib/screens/shared/trial_locked_screen.dart`
- `lib/services/license_service.dart`
- `lib/services/package_service.dart`
- `lib/services/subscriber_service.dart`
- `lib/services/cloud_subscription_service.dart`
- `backend/routes/license.js`
- `supabase/functions/send-activation-code/index.ts`
- `supabase/functions/notify-activation-request/index.ts`

## 12. Email, OTP, and Password Reset

Communication and account recovery flows include:

- OTP sending and verification
- Password reset emails
- Deep-link password reset callback handling
- Gmail / SMTP email configuration

Related files:

- `lib/services/email_notification_service.dart`
- `lib/services/password_reset_service.dart`
- `lib/services/otp_service.dart`
- `supabase/functions/send-password-reset/index.ts`
- `supabase/functions/verify-password-reset/index.ts`
- `supabase_functions/send_otp/index.ts`
- `supabase_functions/verify_otp/index.ts`
- `web/reset_callback.html`
- `web/reset_callback.css`

## 13. Localization, Theme, and Accessibility

The app includes user-facing customization and accessibility controls.

Features include:

- Theme persistence
- Locale switching
- English and Filipino translation support
- Motion preference / reduced motion support
- Settings screen

Related files:

- `lib/utils/theme_controller.dart`
- `lib/utils/locale_controller.dart`
- `lib/utils/motion_controller.dart`
- `lib/screens/shared/settings_screen.dart`
- `lib/utils/app_localizations.dart`
- `FILIPINO_TRANSLATION_SYSTEM.md`

## 14. AI Help

The app includes an AI help entry point for contextual assistance.

Related files:

- `lib/services/ai_help_service.dart`
- `lib/widgets/ai_help_button.dart`
- `AI_HELP_FEATURE.md`

## 15. Backup and Restore

Backup and restore workflows are available from the app.

Features include:

- Local backup creation
- Restore from backup
- Backup directory preparation
- Optional cloud-based backup assistance

Related files:

- `lib/screens/owner/backup_restore_screen.dart`
- `lib/services/database_service.dart`
- `lib/services/google_drive_service.dart`
- `BACKUP_RESTORE_SETUP.md`
- `QUICK_START_CLOUD_SYNC.md`

## 16. Shared and Supporting Screens

The system also includes shared utility screens used across roles:

- Splash screen
- Loading screen
- User manual screen
- Package selection screen
- Shared data screen
- Settings screen
- Developer authentication screen
- License test screen
- Trial locked screen

Related files:

- `lib/screens/shared/splash_screen.dart`
- `lib/screens/shared/loading_screen.dart`
- `lib/screens/shared/user_manual_screen.dart`
- `lib/screens/shared/package_selection_screen.dart`
- `lib/screens/shared/shared_data_screen.dart`
- `lib/screens/shared/developer_auth_screen.dart`
- `lib/screens/shared/license_test_screen.dart`
- `lib/screens/shared/trial_locked_screen.dart`

## Backend API Summary

The backend exposes REST endpoints for:

- `GET /api/health`
- `GET /api/health/db`
- `POST /api/auth/login`
- `POST /api/auth/google/register-owner`
- `POST /api/business/init`
- `POST /api/license/activate`
- `GET /api/license/code/:code`
- `POST /api/sync/push`
- `GET /api/sync/pull`
- CRUD routes for customers, cameras, products, suppliers, sales, sale items, purchase orders, inventory movements, attendance data, damage reports, and activity logs

The backend also contains:

- A MySQL connection manager
- Schema self-healing for some tables and constraints
- JWT verification for bearer tokens
- Google OAuth support for owner registration
- Developer account storage and login flow

## Database Features

The MySQL layer includes tables and relationships for:

- Businesses
- Users
- Developer accounts
- Activation codes
- Activation code requests
- Subscriptions
- Subscription records
- Products
- Sales
- Sale items
- Customers
- Loyalty ledger
- Suppliers
- Purchase orders
- Purchase order items
- Inventory movements
- Damage reports
- Cameras
- CCTV timestamps
- Attendance entries
- Attendance leaves
- Attendance schedule
- Attendance archive
- Activity logs

The backend also enforces and repairs important constraints such as:

- Business-scoped user email uniqueness
- Customer code and barcode uniqueness per business
- Sales to customer relationships
- Sales to cashier relationships
- Damage report product relationships
- Attendance archive uniqueness

## Platforms and UX Notes

- Windows camera capture is limited and typically falls back to file selection.
- Mobile platforms support camera and photo-library access.
- Desktop platforms use `sqflite_common_ffi` so local database operations work correctly.
- Deep links are used so Supabase recovery and reset links can bring the user back into the app.
- The app is designed to continue working offline for local workflows where possible.

## Related Documents

If you want deeper detail on a specific feature area, these documents already exist in the repository:

- [README.md](README.md)
- [USER_MANUAL.md](USER_MANUAL.md)
- [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md)
- [SYSTEM_STRUCTURE_FLOW.md](SYSTEM_STRUCTURE_FLOW.md)
- [SUPABASE_SCHEMA.md](SUPABASE_SCHEMA.md)
- [CLOUD_SYNC_DOCUMENTATION_INDEX.md](CLOUD_SYNC_DOCUMENTATION_INDEX.md)
- [CCTV_IMPLEMENTATION.md](CCTV_IMPLEMENTATION.md)
- [SUPPLIER_MANAGEMENT_GUIDE.md](SUPPLIER_MANAGEMENT_GUIDE.md)
- [DEVELOPER_DASHBOARD_ARCHITECTURE.md](DEVELOPER_DASHBOARD_ARCHITECTURE.md)
- [LICENSE_ACTIVATION_GUIDE.md](LICENSE_ACTIVATION_GUIDE.md)
- [BACKUP_RESTORE_SETUP.md](BACKUP_RESTORE_SETUP.md)

## Quick Setup Summary

1. Configure the backend in `backend/.env`.
2. Start MySQL and run the backend server.
3. Launch the Flutter app.
4. Create or configure the admin, owner, or developer accounts.
5. Set up activation, packages, and sync services as needed.

The root `README.md` contains the standard backend startup commands and Windows autostart helpers.

