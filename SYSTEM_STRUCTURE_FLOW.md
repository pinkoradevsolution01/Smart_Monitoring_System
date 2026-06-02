# Smart Monitoring System - Structure Flow

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            FLUTTER APPLICATION                               │
│                         (Cross-platform: Mobile/Desktop/Web)                │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 1. Application Bootstrap Flow

```
main.dart
  │
  ├─► Initialize Platform-Specific Database
  │   └─► Desktop: sqfliteFfiInit()
  │   └─► Mobile: sqflite (default)
  │   └─► Web: database_service_web.dart
  │
  ├─► Initialize Controllers (Persistent Settings)
  │   ├─► ThemeController (theme selection)
  │   ├─► MotionController (accessibility)
  │   └─► LocaleController (language: en/fil)
  │
  ├─► Register Services in GetIt (DI Container)
  │   ├─► POSService (products, cart, sales)
  │   ├─► UserService (owner/cashier accounts)
  │   ├─► AdminService (admin authentication)
  │   └─► AIHelpService (AI assistance)
  │
  ├─► Configure CCTV Service (Singleton)
  │   └─► CCTVService.instance
  │
  └─► Run SmartStoreApp
      └─► SplashScreen (entry point)
```

## 2. Authentication & Navigation Flow

```
┌─────────────────┐
│  SplashScreen   │
│  (Animated)     │
└────────┬────────┘
         │
         v
┌─────────────────┐
│  LoginScreen    │ ◄── Email/Password or PIN
│                 │
└────────┬────────┘
         │
         ├──────── Validate Credentials ─────────┐
         │                                        │
         v                                        v
    AdminService                            UserService
    (Admin Auth)                         (Owner/Cashier)
         │                                        │
         v                                        v
┌─────────────────┐                    ┌──────────────────┐
│ LoadingScreen   │                    │  LoadingScreen   │
│ (1.4s animated) │                    │  (1.4s animated) │
└────────┬────────┘                    └────────┬─────────┘
         │                                       │
         v                                       v
┌─────────────────┐                    ┌──────────────────┐
│ Admin Dashboard │                    │  Role-Based      │
│                 │                    │  Dashboard       │
└─────────────────┘                    └────────┬─────────┘
                                                 │
                                ┌────────────────┼────────────────┐
                                v                v                v
                         OwnerDashboard   CashierDashboard   (user param)
```

## 3. Role-Based Access Control

```
┌──────────────────────────────────────────────────────────────────┐
│                        USER ROLES & PERMISSIONS                   │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐     │
│  │   ADMIN     │      │   OWNER     │      │  CASHIER    │     │
│  ├─────────────┤      ├─────────────┤      ├─────────────┤     │
│  │ • Manage    │      │ • Sales     │      │ • POS       │     │
│  │   Users     │      │   Reports   │      │   Terminal  │     │
│  │ • Manage    │      │ • CCTV      │      │ • View      │     │
│  │   Products  │      │   Monitor   │      │   Products  │     │
│  │ • Reports   │      │ • Inventory │      │ • Process   │     │
│  │ • Settings  │      │ • Damage    │      │   Sales     │     │
│  │             │      │   Reports   │      │             │     │
│  └─────────────┘      │ • Settings  │      └─────────────┘     │
│                       └─────────────┘                           │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

## 4. Service Layer Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                         DEPENDENCY INJECTION                        │
│                           (GetIt Container)                         │
└────────────────────────────────────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
        v                         v                         v
┌───────────────┐       ┌──────────────────┐      ┌──────────────────┐
│  POSService   │       │  UserService     │      │  AdminService    │
│ (ChangeNotifier)      │                  │      │                  │
├───────────────┤       ├──────────────────┤      ├──────────────────┤
│ • Products    │       │ • CRUD Users     │      │ • Authenticate   │
│ • Cart        │       │ • Owner/Cashier  │      │ • Manage Account │
│ • Sales       │       │ • PIN Validation │      │                  │
│ • Inventory   │       │                  │      │                  │
└───────┬───────┘       └────────┬─────────┘      └──────────────────┘
        │                        │
        └────────┬───────────────┘
                 │
                 v
        ┌────────────────────┐
        │  DatabaseService   │
        │  (Platform-aware)  │   
        ├────────────────────┤
        │ • Mobile: sqflite  │
        │ • Desktop: sqflite_│
        │   common_ffi       │
        │ • Web: IndexedDB   │
        └────────────────────┘

┌──────────────────┐              ┌──────────────────┐
│  CCTVService     │              │  AIHelpService   │
│  (Singleton)     │              │                  │
├──────────────────┤              ├──────────────────┤
│ • Stream RTSP    │              │ • AI Chat        │
│ • HTTP Cameras   │              │ • Context Help   │
│ • Recording      │              │ • Gemini API     │
│ • Timestamps     │              │                  │
└──────────────────┘              └──────────────────┘
```

## 5. Data Models & Relationships

```
┌──────────────────────────────────────────────────────────────────────┐
│                          DATA MODEL LAYER                             │
└──────────────────────────────────────────────────────────────────────┘

┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Product   │         │  CartItem   │         │    Sale     │
├─────────────┤         ├─────────────┤         ├─────────────┤
│ • id        │◄────┐   │ • product   │         │ • id        │
│ • name      │     └───│ • quantity  │         │ • total     │
│ • barcode   │         │ • discount  │         │ • timestamp │
│ • price     │         └─────────────┘         │ • items[]   │
│ • quantity  │                                 └──────┬──────┘
│ • category  │                                        │
│ • imagePath │                                        │
└─────────────┘                                        v
                                              ┌─────────────┐
┌─────────────┐                               │  SaleItem   │
│    User     │                               ├─────────────┤
├─────────────┤                               │ • productId │
│ • id        │                               │ • name      │
│ • name      │                               │ • quantity  │
│ • email     │                               │ • price     │
│ • password  │                               │ • discount  │
│ • pin       │                               └─────────────┘
│ • role      │
│ • isActive  │
└─────────────┘         ┌─────────────────────┐
                        │ InventoryMovement   │
┌─────────────┐         ├─────────────────────┤
│AdminAccount │         │ • productId         │
├─────────────┤         │ • type (sale/       │
│ • email     │         │   restock/adjust)   │
│ • password  │         │ • quantity          │
│ • createdAt │         │ • timestamp         │
└─────────────┘         │ • reason            │
                        └─────────────────────┘

┌─────────────┐         ┌─────────────────────┐
│   Camera    │         │   DamageReport      │
├─────────────┤         ├─────────────────────┤
│ • id        │         │ • id                │
│ • name      │         │ • productId         │
│ • url       │         │ • description       │
│ • type      │         │ • quantity          │
│ • isActive  │         │ • reportedBy        │
└─────────────┘         │ • timestamp         │
                        │ • status            │
                        └─────────────────────┘
```

## 6. Screen Hierarchy & Navigation

```
┌────────────────────────────────────────────────────────────────────┐
│                         SCREEN STRUCTURE                            │
└────────────────────────────────────────────────────────────────────┘

SplashScreen
    │
    └──► LoginScreen
            │
            ├──► AdminDashboard
            │       ├──► ManageUsersScreen
            │       │       └──► UserService CRUD
            │       ├──► ManageProductsScreen
            │       │       └──► POSService CRUD
            │       ├──► ReportsScreen
            │       │       └──► Sales Analytics (fl_chart)
            │       ├──► ManageAdminAccountScreen
            │       │       └──► AdminService
            │       └──► SettingsScreen
            │
            ├──► OwnerDashboard (user: User)
            │       ├──► SalesReportScreen
            │       │       └──► POSService + Analytics
            │       ├──► CCTVScreen
            │       │       ├──► Multi-camera view
            │       │       ├──► Video playback
            │       │       └──► Timestamp markers
            │       ├──► InventoryScreen (shared)
            │       │       ├──► Stock management
            │       │       ├──► Movement history
            │       │       └──► Low stock alerts
            │       ├──► DamageReportsScreen
            │       └──► SettingsScreen (shared)
            │
            └──► CashierDashboard (user: User)
                    ├──► CashierPOS
                    │       ├──► Product grid
                    │       ├──► Cart (modal bottom sheet)
                    │       ├──► Barcode scanner
                    │       └──► Checkout flow
                    ├──► InventoryScreen (view-only)
                    └──► SettingsScreen (shared)

Shared Screens:
    ├──► LoadingScreen (animated transition)
    ├──► SettingsScreen (theme, locale, motion)
    ├──► InventoryScreen (role-based access)
    └──► ProductCameraScreen (image capture)
```

## 7. State Management Pattern

```
┌────────────────────────────────────────────────────────────────────┐
│                     STATE MANAGEMENT LAYERS                         │
└────────────────────────────────────────────────────────────────────┘

Global Settings (ValueNotifier)
    ├──► ThemeController.themeKey
    │       └──► shared_preferences: 'theme_key'
    ├──► ThemeController.customColor
    │       └──► Runtime color picker
    ├──► LocaleController.locale
    │       └──► shared_preferences: 'locale'
    └──► MotionController.reduceMotion
            └──► shared_preferences: 'reduce_motion'

Service State (ChangeNotifier)
    ├──► POSService
    │       ├──► products (List<Product>)
    │       ├──► cart (List<CartItem>)
    │       ├──► recentSales (List<Sale>)
    │       └──► notifyListeners() on mutations
    │
    └──► CCTVService
            ├──► cameras (List<Camera>)
            ├──► activeCamera (Camera?)
            ├──► isRecording (bool)
            └──► notifyListeners() on state change

UI Rebuild Pattern:
    MaterialApp
        └──► ValueListenableBuilder<String>(ThemeController.themeKey)
                └──► ValueListenableBuilder<Color>(ThemeController.customColor)
                        └──► ValueListenableBuilder<Locale>(LocaleController.locale)
                                └──► Widget Tree
```

## 8. Feature Module Breakdown

```
┌────────────────────────────────────────────────────────────────────┐
│                         FEATURE MODULES                             │
└────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│   POS Module         │
├──────────────────────┤
│ • Product Catalog    │
│ • Shopping Cart      │
│ • Barcode Scanning   │
│ • Checkout Process   │
│ • Receipt Generation │
│ • Payment Processing │
└──────────────────────┘

┌──────────────────────┐
│  Inventory Module    │
├──────────────────────┤
│ • Stock Tracking     │
│ • Low Stock Alerts   │
│ • Movement History   │
│ • Restock Management │
│ • Product Images     │
│ • Category Filter    │
└──────────────────────┘

┌──────────────────────┐
│  CCTV Module         │
├──────────────────────┤
│ • Multi-Camera View  │
│ • RTSP/HTTP Streams  │
│ • Video Recording    │
│ • Playback Control   │
│ • Timestamp Markers  │
│ • Camera Config      │
└──────────────────────┘

┌──────────────────────┐
│  Reports Module      │
├──────────────────────┤
│ • Sales Analytics    │
│ • Revenue Charts     │
│ • Product Performance│
│ • Daily/Weekly/Month │
│ • Export Data        │
│ • Visual Graphs      │
└──────────────────────┘

┌──────────────────────┐
│  User Management     │
├──────────────────────┤
│ • Role Assignment    │
│ • PIN Authentication │
│ • Active/Inactive    │
│ • User CRUD          │
│ • Admin Account      │
└──────────────────────┘

┌──────────────────────┐
│  AI Help Module      │
├──────────────────────┤
│ • Chat Interface     │
│ • Context-Aware Help │
│ • Gemini Integration │
│ • Conversation History│
└──────────────────────┘

┌──────────────────────┐
│  Settings Module     │
├──────────────────────┤
│ • Theme Selection    │
│ • Custom Colors      │
│ • Language Toggle    │
│ • Motion Settings    │
│ • Accessibility      │
└──────────────────────┘
```

## 9. Database Schema Flow

```
┌────────────────────────────────────────────────────────────────────┐
│                    DATABASE ARCHITECTURE                            │
└────────────────────────────────────────────────────────────────────┘

SQLite Database: pos_system.db (Schema v3)

┌─────────────────┐
│   products      │
├─────────────────┤
│ id (PK)         │
│ name            │
│ barcode         │
│ category        │
│ selling_price   │
│ quantity        │
│ image_path      │
│ created_at      │
└─────────────────┘
        │
        │ 1:N
        v
┌─────────────────┐       ┌─────────────────┐
│  sale_items     │       │    sales        │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ id (PK)         │
│ sale_id (FK) ───┼──────►│ total           │
│ product_id (FK) │       │ discount        │
│ name            │       │ timestamp       │
│ quantity        │       │ payment_method  │
│ price           │       └─────────────────┘
│ discount        │
└─────────────────┘

┌──────────────────────┐
│  inventory_movements │
├──────────────────────┤
│ id (PK)              │
│ product_id (FK)      │
│ type (enum)          │
│ quantity             │
│ timestamp            │
│ reason               │
│ performed_by         │
└──────────────────────┘

┌─────────────────┐       ┌─────────────────┐
│     users       │       │  admin_account  │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ email           │
│ name            │       │ password (hash) │
│ email           │       │ created_at      │
│ password (hash) │       └─────────────────┘
│ pin             │
│ role            │
│ created_at      │
│ is_active       │
└─────────────────┘

┌─────────────────┐       ┌──────────────────┐
│    cameras      │       │  damage_reports  │
├─────────────────┤       ├──────────────────┤
│ id (PK)         │       │ id (PK)          │
│ name            │       │ product_id (FK)  │
│ url             │       │ description      │
│ type            │       │ quantity         │
│ is_active       │       │ reported_by      │
│ created_at      │       │ timestamp        │
└─────────────────┘       │ status           │
                          │ resolution_notes │
                          └──────────────────┘
```

## 10. Localization Flow

```
┌────────────────────────────────────────────────────────────────────┐
│                    LOCALIZATION SYSTEM                              │
└────────────────────────────────────────────────────────────────────┘

AppLocalizations (lib/utils/app_localizations.dart)
    │
    ├──► Static Map<String, Map<String, String>>
    │       ├──► 'en': { 'key': 'English text' }
    │       └──► 'fil': { 'key': 'Filipino text' }
    │
    └──► t(String key) method
            │
            └──► Reads LocaleController.locale.value
                    │
                    └──► Returns translated string

Usage Pattern:
    AppLocalizations.t('welcome_message')
    AppLocalizations.t('stock_label').replaceAll('{n}', count.toString())

Supported Languages:
    • English (en) - default
    • Filipino (fil)

Settings Control:
    SettingsScreen
        └──► ToggleButtons: EN / FIL
                └──► Updates LocaleController.setLocale()
                        └──► Persists to shared_preferences
                                └──► Rebuilds MaterialApp
```

## 11. Theme System Flow

```
┌────────────────────────────────────────────────────────────────────┐
│                       THEME ARCHITECTURE                            │
└────────────────────────────────────────────────────────────────────┘

ThemeController
    │
    ├──► Presets (Map<String, MaterialColor>)
    │       ├──► 'red', 'yellow', 'blue' (default)
    │       ├──► 'black', 'green', 'violet'
    │       ├──► 'orange', 'brown', 'grey'
    │       └──► 'custom' (runtime color picker)
    │
    ├──► themeKey (ValueNotifier<String>)
    │       └──► Persists to shared_preferences
    │
    ├──► customColor (ValueNotifier<Color>)
    │       └──► Runtime-only (not persisted)
    │
    └──► getMaterialColor(String key)
            │
            └──► Returns MaterialColor

AppTheme.forPrimary(MaterialColor primary)
    │
    ├──► Generates ThemeData
    │       ├──► colorScheme (from primary)
    │       ├──► appBarTheme
    │       ├──► cardTheme
    │       ├──► elevatedButtonTheme
    │       └──► inputDecorationTheme
    │
    └──► Applied to MaterialApp

Icon Theming Pattern:
    ✅ Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary)
    ❌ const Icon(Icons.favorite, color: Colors.red) // Breaks theming
```

## 12. External Integration Points

```
┌────────────────────────────────────────────────────────────────────┐
│                    EXTERNAL DEPENDENCIES                            │
└────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│  sqflite / FFI   │ ──► Local SQLite Database
├──────────────────┤     • Mobile: sqflite
│ DatabaseService  │     • Desktop: sqflite_common_ffi
└──────────────────┘     • Web: IndexedDB wrapper

┌──────────────────┐
│ shared_prefs     │ ──► Persistent Key-Value Storage
├──────────────────┤     • theme_key
│ Settings Storage │     • locale (en/fil)
└──────────────────┘     • reduce_motion

┌──────────────────┐
│  video_player    │ ──► CCTV Stream Playback
├──────────────────┤     • RTSP protocol
│ CCTVService      │     • HTTP streams
└──────────────────┘     • Local video files

┌──────────────────┐
│ mobile_scanner   │ ──► Barcode Scanning
├──────────────────┤     • Product lookup
│ POS Module       │     • Quick add to cart
└──────────────────┘

┌──────────────────┐
│  camera/picker   │ ──► Image Capture
├──────────────────┤     • Mobile: image_picker
│ Product Images   │     • Desktop: file_picker
└──────────────────┘

┌──────────────────┐
│  fl_chart        │ ──► Data Visualization
├──────────────────┤     • Sales charts
│ Reports Module   │     • Revenue analytics
└──────────────────┘

┌──────────────────┐
│  Gemini API      │ ──► AI Assistance
├──────────────────┤     • Chat interface
│ AIHelpService    │     • Context-aware help
└──────────────────┘

┌──────────────────┐
│  get_it          │ ──► Dependency Injection
├──────────────────┤     • Service locator
│ DI Container     │     • Singleton management
└──────────────────┘
```

## 13. Development Workflow

```
┌────────────────────────────────────────────────────────────────────┐
│                    DEVELOPMENT LIFECYCLE                            │
└────────────────────────────────────────────────────────────────────┘

1. Code → 2. Build → 3. Test → 4. Deploy

Development:
    ├──► Flutter SDK (Dart)
    ├──► VS Code / Android Studio
    ├──► Hot Reload / Hot Restart
    └──► Debug Tools

Build Targets:
    ├──► flutter run -d android
    ├──► flutter run -d ios
    ├──► flutter run -d windows
    ├──► flutter run -d linux
    ├──► flutter run -d macos
    └──► flutter run -d chrome

Testing:
    ├──► Unit Tests (services, models)
    ├──► Widget Tests (UI components)
    └──► Integration Tests (planned)

Database Management:
    ├──► Schema Migrations (_upgradeTables)
    ├──► Seed Data (SeedService)
    └──► DB Browser for SQLite (inspection)

Release:
    ├──► flutter build apk --release
    ├──► flutter build windows --release
    └──► flutter build web --release
```

## 14. Security Flow

```
┌────────────────────────────────────────────────────────────────────┐
│                       SECURITY LAYERS                               │
└────────────────────────────────────────────────────────────────────┘

Authentication:
    LoginScreen
        │
        ├──► Admin Authentication
        │       └──► AdminService.authenticate(email, password)
        │               └──► Stored credentials (NOT hashed - dev only)
        │
        └──► User Authentication
                ├──► Email + Password (UserService)
                └──► PIN (4-6 digits, UserService)

Authorization:
    Role-Based Access Control (RBAC)
        │
        ├──► Admin: Full system access
        ├──► Owner: Management + Reports + CCTV
        └──► Cashier: POS terminal only

Data Protection:
    ├──► Local SQLite database (unencrypted - dev)
    ├──► No network transmission (offline-first)
    └──► Future: Implement bcrypt for passwords

Session Management:
    ├──► No persistent sessions
    ├──► Login required each app launch
    └──► User context passed via navigation params
```

## 15. Error Handling & Logging

```
┌────────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING STRATEGY                          │
└────────────────────────────────────────────────────────────────────┘

Database Errors:
    DatabaseService
        └──► try-catch blocks
                ├──► Log to console (debugPrint)
                └──► Return empty list / null

Service Errors:
    POSService / UserService / CCTVService
        └──► try-catch with user feedback
                ├──► SnackBar notifications
                └──► Error dialogs

Validation Errors:
    Forms (Login, Product, User)
        └──► TextFormField validators
                └──► Inline error messages

Network Errors (CCTV):
    CCTVService.testConnection()
        └──► Connection timeout handling
                └──► User-friendly error messages

Future Improvements:
    ├──► Implement logging framework (logger package)
    ├──► Error reporting service (Sentry/Firebase Crashlytics)
    └──► Offline error queue with retry logic
```

---

## Quick Reference: Key Files

| Component | File Path |
|-----------|-----------|
| **Entry Point** | `lib/main.dart` |
| **Routing** | `lib/app_router.dart` |
| **Theme** | `lib/theme.dart` |
| **Localization** | `lib/utils/app_localizations.dart` |
| **POS Service** | `lib/services/pos_service.dart` |
| **Database** | `lib/services/database_service.dart` |
| **CCTV** | `lib/services/cctv_service.dart` |
| **User Auth** | `lib/services/user_service.dart` |
| **Admin Auth** | `lib/services/admin_service.dart` |
| **AI Help** | `lib/services/ai_help_service.dart` |
| **Models** | `lib/models/` |
| **Screens** | `lib/screens/{admin,owner,cashier,auth,shared}/` |

---

## Data Flow Example: Complete Sale Transaction

```
1. Cashier scans product barcode
        │
        v
2. Mobile Scanner reads barcode
        │
        v
3. POSService.searchProducts(barcode)
        │
        v
4. DatabaseService queries products table
        │
        v
5. Product found → Add to cart
        │
        v
6. POSService.addToCart(product)
        │
        v
7. CartItem created with quantity=1
        │
        v
8. notifyListeners() → UI updates
        │
        v
9. Cashier reviews cart → Checkout
        │
        v
10. POSService.checkout()
        │
        ├──► Validate stock levels
        ├──► Calculate totals (with discounts)
        ├──► Create Sale record
        ├──► Create SaleItem records
        ├──► Update product quantities
        ├──► Create InventoryMovement records
        │
        v
11. DatabaseService transactions
        │
        v
12. Cart cleared → notifyListeners()
        │
        v
13. Success message → Return to POS screen
```

---

**Document Version:** 1.0  
**Last Updated:** December 1, 2025  
**System Version:** Smart Monitoring System v1.0
