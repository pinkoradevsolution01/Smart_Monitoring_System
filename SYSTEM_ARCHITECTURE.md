# Smart Monitoring System - Visual Architecture

## System Architecture Diagram

```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║                        SMART MONITORING SYSTEM ARCHITECTURE                        ║
║                        (Flutter Cross-Platform Application)                        ║
╚═══════════════════════════════════════════════════════════════════════════════════╝

┌───────────────────────────────────────────────────────────────────────────────────┐
│                                 PRESENTATION LAYER                                 │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌─────────────┐        ┌─────────────┐        ┌─────────────┐                  │
│  │   ADMIN     │        │   OWNER     │        │  CASHIER    │                  │
│  │  SCREENS    │        │  SCREENS    │        │  SCREENS    │                  │
│  ├─────────────┤        ├─────────────┤        ├─────────────┤                  │
│  │ • Dashboard │        │ • Dashboard │        │ • Dashboard │                  │
│  │ • Users     │        │ • Sales     │        │ • POS       │                  │
│  │ • Products  │        │   Reports   │        │ • Inventory │                  │
│  │ • Reports   │        │ • CCTV      │        │   (View)    │                  │
│  │ • Settings  │        │ • Inventory │        │             │                  │
│  └─────────────┘        │ • Damages   │        └─────────────┘                  │
│                         │ • Settings  │                                          │
│                         └─────────────┘                                          │
│                                                                                    │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         SHARED UI COMPONENTS                               │  │
│  ├───────────────────────────────────────────────────────────────────────────┤  │
│  │  • SplashScreen  • LoginScreen  • LoadingScreen  • SettingsScreen         │  │
│  │  • InventoryScreen  • ProductCameraScreen                                 │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                    │
└────────────────────────────────────────┬───────────────────────────────────────────┘
                                         │
                                         │ UI Events / User Actions
                                         │
                                         ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                              STATE MANAGEMENT LAYER                                │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │                       GLOBAL CONTROLLERS (ValueNotifier)                 │    │
│  ├─────────────────────────────────────────────────────────────────────────┤    │
│  │  ThemeController      LocaleController      MotionController            │    │
│  │  • themeKey           • locale (en/fil)     • reduceMotion             │    │
│  │  • customColor        • ValueNotifier       • Accessibility            │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│                                    │                                              │
│                                    │ Persisted via                                │
│                                    ▼                                              │
│                          ┌──────────────────────┐                                │
│                          │  SharedPreferences   │                                │
│                          │  • theme_key         │                                │
│                          │  • locale            │                                │
│                          │  • reduce_motion     │                                │
│                          └──────────────────────┘                                │
│                                                                                    │
└────────────────────────────────────────┬───────────────────────────────────────────┘
                                         │
                                         │ State Updates / Notifications
                                         │
                                         ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                               BUSINESS LOGIC LAYER                                 │
│                          (Dependency Injection - GetIt)                            │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐         │
│  │   POSService       │  │   UserService      │  │   AdminService     │         │
│  │ (ChangeNotifier)   │  │                    │  │                    │         │
│  ├────────────────────┤  ├────────────────────┤  ├────────────────────┤         │
│  │ • getProducts()    │  │ • createUser()     │  │ • authenticate()   │         │
│  │ • addToCart()      │  │ • updateUser()     │  │ • getAccount()     │         │
│  │ • removeFromCart() │  │ • deleteUser()     │  │ • updateAccount()  │         │
│  │ • updateQuantity() │  │ • getUserById()    │  │                    │         │
│  │ • checkout()       │  │ • getAllUsers()    │  │                    │         │
│  │ • searchProducts() │  │ • authenticateUser()│ │                    │         │
│  │ • getSales()       │  │ • validatePin()    │  │                    │         │
│  │ • updateStock()    │  │                    │  │                    │         │
│  │ • getMovements()   │  │                    │  │                    │         │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘         │
│           │                        │                        │                     │
│           └────────────────────────┼────────────────────────┘                     │
│                                    │                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐         │
│  │   CCTVService      │  │  AIHelpService     │  │   SeedService      │         │
│  │   (Singleton)      │  │                    │  │                    │         │
│  ├────────────────────┤  ├────────────────────┤  ├────────────────────┤         │
│  │ • configure()      │  │ • sendMessage()    │  │ • seedSampleProd() │         │
│  │ • addCamera()      │  │ • getHistory()     │  │ • seedUsers()      │         │
│  │ • removeCamera()   │  │ • clearHistory()   │  │                    │         │
│  │ • startRecording() │  │ • Gemini API       │  │                    │         │
│  │ • stopRecording()  │  │                    │  │                    │         │
│  │ • testConnection() │  │                    │  │                    │         │
│  │ • addTimestamp()   │  │                    │  │                    │         │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘         │
│           │                        │                                              │
│           └────────────────────────┘                                              │
│                                                                                    │
└────────────────────────────────────┬───────────────────────────────────────────────┘
                                     │
                                     │ Data Operations / Queries
                                     │
                                     ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                 DATA ACCESS LAYER                                  │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│                          ┌──────────────────────────┐                             │
│                          │   DatabaseService        │                             │
│                          │  (Platform Abstraction)  │                             │
│                          └────────────┬─────────────┘                             │
│                                       │                                            │
│              ┌────────────────────────┼────────────────────────┐                  │
│              │                        │                        │                  │
│              ▼                        ▼                        ▼                  │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐      │
│  │ database_service    │  │ database_service    │  │ database_service    │      │
│  │      _io.dart       │  │     _web.dart       │  │    (interface)      │      │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────────┤      │
│  │ Mobile & Desktop    │  │    Web Browser      │  │  Abstract Methods   │      │
│  │ • sqflite           │  │ • IndexedDB         │  │  • initDB()         │      │
│  │ • sqflite_common    │  │ • Web SQL           │  │  • insert()         │      │
│  │   _ffi (Desktop)    │  │                     │  │  • update()         │      │
│  │                     │  │                     │  │  • delete()         │      │
│  │                     │  │                     │  │  • query()          │      │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘      │
│                                                                                    │
└────────────────────────────────────┬───────────────────────────────────────────────┘
                                     │
                                     │ SQL Transactions / CRUD
                                     │
                                     ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                PERSISTENCE LAYER                                   │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌───────────────────────────────────────────────────────────────────────────┐   │
│  │                        SQLite Database (pos_system.db)                     │   │
│  │                              Schema Version: 3                              │   │
│  ├───────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                             │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │   │
│  │  │  products   │  │   sales     │  │ sale_items  │  │    users    │     │   │
│  │  ├─────────────┤  ├─────────────┤  ├────────────   ─┤  ├─────────────┤     │   │
│  │  │ id          │  │ id          │  │ id          │  │ id          │     │   │
│  │  │ name        │  │ total       │  │ sale_id     │  │ name        │     │   │
│  │  │ barcode     │  │ discount    │  │ product_id  │  │ email       │     │   │
│  │  │ category    │  │ timestamp   │  │ name        │  │ password    │     │   │
│  │  │ price       │  │ payment     │  │ quantity    │  │ pin         │     │   │
│  │  │ quantity    │  │             │  │ price       │  │ role        │     │   │
│  │  │ image_path  │  │             │  │ discount    │  │ is_active   │     │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘     │   │
│  │                                                                             │   │
│  │  ┌──────────────────┐  ┌─────────────┐  ┌──────────────────┐            │   │
│  │  │ inventory_       │  │  cameras    │  │ damage_reports   │            │   │
│  │  │   movements      │  ├─────────────┤  ├──────────────────┤            │   │
│  │  ├──────────────────┤  │ id          │  │ id               │            │   │
│  │  │ id               │  │ name        │  │ product_id       │            │   │
│  │  │ product_id       │  │ url         │  │ description      │            │   │
│  │  │ type             │  │ type        │  │ quantity         │            │   │
│  │  │ quantity         │  │ is_active   │  │ reported_by      │            │   │
│  │  │ timestamp        │  │             │  │ timestamp        │            │   │
│  │  │ reason           │  │             │  │ status           │            │   │
│  │  └──────────────────┘  └─────────────┘  └──────────────────┘            │   │
│  │                                                                             │   │
│  └───────────────────────────────────────────────────────────────────────────┘   │
│                                                                                    │
└───────────────────────────────────────────────────────────────────────────────────┘


┌───────────────────────────────────────────────────────────────────────────────────┐
│                            EXTERNAL INTEGRATIONS                                   │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Video Streams   │  │  Barcode Scanner│  │  Image Picker   │                  │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤                  │
│  │ • RTSP          │  │ • mobile_       │  │ • camera        │                  │
│  │ • HTTP Stream   │  │   scanner       │  │ • image_picker  │                  │
│  │ • Local Video   │  │ • QR/Barcode    │  │ • file_picker   │                  │
│  │ • video_player  │  │                 │  │   (Desktop)     │                  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
│                                                                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
│  │  Charts/Graphs  │  │   AI Service    │  │  Printing       │                  │
│  ├─────────────────┤  ├─────────────────┤  ├─────────────────┤                  │
│  │ • fl_chart      │  │ • Gemini API    │  │ • pdf           │                  │
│  │ • Line Charts   │  │ • Natural Lang  │  │ • printing      │                  │
│  │ • Bar Charts    │  │ • Context-Aware │  │ • Receipts      │                  │
│  │ • Pie Charts    │  │                 │  │   (Planned)     │                  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
│                                                                                    │
└───────────────────────────────────────────────────────────────────────────────────┘
```

## Application Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          APPLICATION EXECUTION FLOW                              │
└─────────────────────────────────────────────────────────────────────────────────┘

START
  │
  ├─► main() Entry Point
  │    └─► WidgetsFlutterBinding.ensureInitialized()
  │
  ├─► Platform Detection
  │    ├─► Desktop (Windows/Linux/macOS) → sqfliteFfiInit()
  │    ├─► Mobile (Android/iOS) → sqflite (default)
  │    └─► Web → IndexedDB wrapper
  │
  ├─► Initialize Controllers
  │    ├─► ThemeController.init() → Load saved theme
  │    └─► MotionController.init() → Load accessibility settings
  │
  ├─► Initialize Services (GetIt DI)
  │    ├─► POSService.initialize() → Load products, sales
  │    ├─► UserService → Ready for auth
  │    ├─► AdminService → Ready for admin auth
  │    └─► AIHelpService → Ready for chat
  │
  ├─► Configure CCTV
  │    └─► CCTVService.instance.configure() → Default camera URL
  │
  └─► runApp(SmartStoreApp)
       │
       └─► MaterialApp
            ├─► ValueListenableBuilder (Theme)
            ├─► ValueListenableBuilder (Locale)
            └─► Home: SplashScreen
                 │
                 └─► Animated Splash (2-3 seconds)
                      │
                      └─► Navigate to LoginScreen
                           │
                           ├─────────────────────────────────────┐
                           │                                     │
                           ▼                                     ▼
                    ADMIN LOGIN                           USER LOGIN
                           │                                     │
                           │                                     │
                    AdminService                          UserService
                    .authenticate()                       .authenticateUser()
                           │                                     │
                           │                                     │
                           ▼                                     ▼
                    LoadingScreen                         LoadingScreen
                    (1.4s transition)                    (1.4s transition)
                           │                                     │
                           │                                     │
                           ▼                                     ▼
                    AdminDashboard                        Role Check
                           │                                     │
                           │                          ┌──────────┴──────────┐
                           │                          │                     │
                           │                          ▼                     ▼
                           │                   OwnerDashboard      CashierDashboard
                           │                          │                     │
                           │                          │                     │
                           └──────────────────────────┴─────────────────────┘
                                                      │
                                                      │
                                           ┌──────────┴──────────┐
                                           │                     │
                                           ▼                     ▼
                                    Feature Screens      Shared Screens
                                    • POS Terminal       • Inventory
                                    • Sales Reports      • Settings
                                    • CCTV Monitoring    • Product Camera
                                    • User Management
                                    • Product Management
                                    • Damage Reports
```

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            DATA FLOW PATTERNS                                    │
└─────────────────────────────────────────────────────────────────────────────────┘

╔════════════════════════════════════════════════════════════════════════════════╗
║                         USER INTERACTION FLOW                                   ║
╚════════════════════════════════════════════════════════════════════════════════╝

User Action (UI)
      │
      ├─► Tap Button / Enter Data / Scan Barcode
      │
      ▼
Widget Event Handler
      │
      ├─► Call Service Method
      │
      ▼
Service Layer (Business Logic)
      │
      ├─► Validate Input
      ├─► Transform Data
      ├─► Apply Rules
      │
      ▼
Database Service (Data Access)
      │
      ├─► SQL Query / Transaction
      │
      ▼
SQLite Database (Persistence)
      │
      ├─► Execute / Commit
      │
      ▼
Return Result to Service
      │
      ├─► Process Result
      │
      ▼
Service.notifyListeners()
      │
      ├─► Trigger UI Rebuild
      │
      ▼
UI Updates (Visual Feedback)
      │
      └─► Display Result / Show Message


╔════════════════════════════════════════════════════════════════════════════════╗
║                    EXAMPLE: COMPLETE SALE TRANSACTION                           ║
╚════════════════════════════════════════════════════════════════════════════════╝

1. Cashier Scans Product Barcode
         │
         ▼
2. mobile_scanner Package → Barcode String
         │
         ▼
3. CashierPOS Widget → onDetect()
         │
         ▼
4. POSService.searchProducts(barcode)
         │
         ▼
5. DatabaseService.query('SELECT * FROM products WHERE barcode = ?')
         │
         ▼
6. SQLite Returns Product Row
         │
         ▼
7. Product.fromMap() → Product Object
         │
         ▼
8. POSService.addToCart(product)
         │
         ├─► Create CartItem(product: product, quantity: 1)
         ├─► Add to _cart List
         └─► notifyListeners()
         │
         ▼
9. Cart Widget Rebuilds (ListenableBuilder)
         │
         ▼
10. Cashier Reviews Cart → Taps Checkout
         │
         ▼
11. POSService.checkout()
         │
         ├─► Validate Stock: product.quantity >= cartItem.quantity
         ├─► Calculate Total: sum(price * quantity - discount)
         ├─► Create Sale Object (total, timestamp)
         │
         ▼
12. DatabaseService.transaction()
         │
         ├─► INSERT INTO sales (total, discount, timestamp)
         ├─► Get sale.id
         │
         ├─► For each CartItem:
         │    ├─► INSERT INTO sale_items (sale_id, product_id, quantity, price)
         │    ├─► UPDATE products SET quantity = quantity - cartItem.quantity
         │    └─► INSERT INTO inventory_movements (type='sale', quantity, timestamp)
         │
         └─► COMMIT Transaction
         │
         ▼
13. Clear Cart: _cart.clear()
         │
         ▼
14. POSService.notifyListeners()
         │
         ▼
15. UI Updates:
         ├─► Cart shows empty
         ├─► SnackBar: "Sale completed successfully"
         └─► Product quantities updated in inventory
         │
         ▼
16. Receipt Generated (Future Feature)
         │
         └─► End Transaction


╔════════════════════════════════════════════════════════════════════════════════╗
║                      REAL-TIME STATE SYNCHRONIZATION                            ║
╚════════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────┐
│   POSService State   │
│   (ChangeNotifier)   │
└──────────┬───────────┘
           │
           │ notifyListeners()
           │
           ├──────────────────────────────────────┐
           │                                      │
           ▼                                      ▼
┌──────────────────────┐              ┌──────────────────────┐
│  Products Widget     │              │    Cart Widget       │
│  (ListenableBuilder) │              │  (ListenableBuilder) │
└──────────────────────┘              └──────────────────────┘
           │                                      │
           │ Rebuild on notify                    │ Rebuild on notify
           │                                      │
           ▼                                      ▼
    Display Updated                        Display Updated
    Product List                           Cart Items


┌──────────────────────┐
│ ThemeController      │
│ (ValueNotifier)      │
└──────────┬───────────┘
           │
           │ value changes
           │
           ▼
┌──────────────────────┐
│ ValueListenableBuilder│
│ (in MaterialApp)     │
└──────────┬───────────┘
           │
           │ Rebuild entire app
           │
           ▼
    New Theme Applied
    to All Widgets
```

## Security & Authentication Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        AUTHENTICATION & AUTHORIZATION                            │
└─────────────────────────────────────────────────────────────────────────────────┘

LoginScreen
     │
     ├─── Input: Email + Password
     │
     ├─── Check Login Type
     │
     ├─────────────────────────────────────────┐
     │                                         │
     ▼                                         ▼
ADMIN PATH                                USER PATH
     │                                         │
     │                                         │
AdminService.authenticate()            UserService.authenticateUser()
     │                                         │
     ├─► Check admin_account table            ├─► Query users table
     ├─► Compare email (plain)                ├─► Match email
     ├─► Compare password (plain)             ├─► Compare password (plain)
     │   ⚠️ NOT HASHED (dev only)             │   ⚠️ NOT HASHED (dev only)
     │                                         ├─► Check is_active = 1
     │                                         ├─► Return User object
     ▼                                         ▼
Return true/false                        Return User or null
     │                                         │
     │                                         │
     └──────────────┬──────────────────────────┘
                    │
                    ▼
           Authentication Success
                    │
                    ├─► Store User Context (NOT persisted)
                    ├─► Navigate to Dashboard
                    │
                    ▼
           ┌─────────────────────┐
           │  Role-Based Access  │
           ├─────────────────────┤
           │                     │
           │  if (role == admin) │
           │    → AdminDashboard │
           │                     │
           │  if (role == owner) │
           │    → OwnerDashboard │
           │                     │
           │  if (role == cashier)│
           │    → CashierDashboard│
           │                     │
           └─────────────────────┘
                    │
                    │
                    ▼
           Screen-Level Checks
           (User object required)
                    │
                    ├─► Owner: Full management access
                    ├─► Cashier: POS only
                    └─► Admin: System configuration


┌──────────────────────────────────────────────────────────────┐
│              AUTHORIZATION MATRIX                             │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Feature              │ Admin │ Owner │ Cashier │            │
│  ────────────────────│───────│───────│─────────│            │
│  Manage Users         │  ✓    │  ✗    │   ✗     │            │
│  Manage Products      │  ✓    │  ✗    │   ✗     │            │
│  View All Reports     │  ✓    │  ✓    │   ✗     │            │
│  CCTV Access          │  ✓    │  ✓    │   ✗     │            │
│  Damage Reports       │  ✓    │  ✓    │   ✗     │            │
│  POS Terminal         │  ✓    │  ✓    │   ✓     │            │
│  View Inventory       │  ✓    │  ✓    │   ✓     │            │
│  Update Inventory     │  ✓    │  ✓    │   ✗     │            │
│  Settings Access      │  ✓    │  ✓    │   ✓     │            │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## Module Interaction Map

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          MODULE DEPENDENCIES                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

                              ┌──────────────┐
                              │   main.dart  │
                              │  (Bootstrap) │
                              └───────┬──────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
           ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
           │   theme.dart│   │ app_router  │   │ Controllers │
           │             │   │   .dart     │   │ (Theme/     │
           │ AppTheme    │   │             │   │  Locale)    │
           └─────────────┘   └─────────────┘   └─────────────┘
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                              ┌───────▼──────┐
                              │ MaterialApp  │
                              └───────┬──────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
           ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
           │   Screens   │   │  Services   │   │   Models    │
           │  (UI Layer) │   │ (Business)  │   │   (Data)    │
           └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
                  │                 │                 │
                  │     Uses        │    Transforms   │
                  └────────►────────┴────────►────────┘
                                    │
                                    ▼
                           ┌─────────────────┐
                           │ DatabaseService │
                           │  (Data Access)  │
                           └────────┬────────┘
                                    │
                                    ▼
                           ┌─────────────────┐
                           │ SQLite Database │
                           │ (Persistence)   │
                           └─────────────────┘


┌────────────────────────────────────────────────────────────────┐
│                  SERVICE INTERACTION DIAGRAM                    │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│     AdminService ─────────┐                                    │
│          │                │                                    │
│          │                │                                    │
│     UserService ──────────┼───► DatabaseService                │
│          │                │           │                        │
│          │                │           │                        │
│     POSService ───────────┤           └──► SQLite DB           │
│          │                │                                    │
│          │                │                                    │
│     CCTVService ──────────┘                                    │
│      (Singleton)                                               │
│          │                                                     │
│          └──► video_player (External)                          │
│                                                                 │
│     AIHelpService                                              │
│          │                                                     │
│          └──► Gemini API (External)                            │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT TARGETS                                        │
└─────────────────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────────┐
                        │  Flutter Codebase    │
                        │  (Single Source)     │
                        └──────────┬───────────┘
                                   │
                                   │ flutter build
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
    │     MOBILE      │  │    DESKTOP      │  │      WEB        │
    ├─────────────────┤  ├─────────────────┤  ├─────────────────┤
    │ • Android APK   │  │ • Windows EXE   │  │ • HTML/JS/WASM  │
    │ • iOS IPA       │  │ • Linux Binary  │  │ • Hosted        │
    │                 │  │ • macOS App     │  │                 │
    └─────────────────┘  └─────────────────┘  └─────────────────┘
             │                    │                    │
             ▼                    ▼                    ▼
    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
    │ Google Play     │  │ Direct Download │  │ Web Server      │
    │ App Store       │  │ Installers      │  │ (Firebase/etc)  │
    └─────────────────┘  └─────────────────┘  └─────────────────┘


Platform-Specific Features:

Mobile (Android/iOS):
  • Camera access for barcode scanning
  • image_picker for product photos
  • Native performance
  • Touch-optimized UI

Desktop (Windows/Linux/macOS):
  • sqflite_common_ffi for database
  • file_picker for image selection
  • Keyboard shortcuts
  • Mouse interactions
  • Larger screen layouts

Web:
  • IndexedDB for storage
  • Responsive design
  • No camera access (desktop mode)
  • Browser compatibility
```

---

## Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                      TECHNOLOGY LAYERS                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FRAMEWORK:      Flutter 3.x (Dart)                             │
│                                                                  │
│  UI:             Material Design 3                              │
│                  Custom Themes (9 presets + custom)             │
│                                                                  │
│  STATE:          ValueNotifier (settings)                       │
│                  ChangeNotifier (services)                      │
│                                                                  │
│  DI:             GetIt (Service Locator)                        │
│                                                                  │
│  DATABASE:       SQLite (sqflite / sqflite_common_ffi)          │
│                  IndexedDB (Web)                                │
│                                                                  │
│  PERSISTENCE:    SharedPreferences (settings)                   │
│                  SQLite (application data)                      │
│                                                                  │
│  VIDEO:          video_player (CCTV streams)                    │
│                                                                  │
│  SCANNING:       mobile_scanner (Barcodes/QR)                   │
│                                                                  │
│  CHARTS:         fl_chart (Analytics)                           │
│                                                                  │
│  AI:             Google Gemini API (Help Assistant)             │
│                                                                  │
│  IMAGES:         image_picker (Mobile)                          │
│                  file_picker (Desktop)                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

**Document:** System Architecture Diagram  
**Version:** 1.0  
**Date:** December 1, 2025  
**Status:** Active Development
