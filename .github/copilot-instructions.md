# Smart Monitoring System - AI Agent Instructions

## Project Overview
Flutter-based POS and monitoring system supporting admin/owner/cashier roles with inventory management, CCTV monitoring, and sales reporting. Cross-platform targeting mobile (Android/iOS) and desktop (Windows/Linux/macOS).

## Architecture

### Service Layer & Dependency Injection
- **GetIt** for singleton DI: Services registered in `main.dart` (`POSService`, `UserService`, `AdminService`)
- Access via `GetIt.I.get<ServiceName>()` or inject in constructors
- **Platform-specific database**: `database_service.dart` conditionally exports `database_service_io.dart` (sqflite) vs `database_service_web.dart`
- Desktop platforms use `sqflite_common_ffi` (initialized in `main()` before runApp)
- **CCTVService** is singleton via `CCTVService.instance` (not in GetIt)

### State Management
- **ValueNotifier** pattern for global settings:
  - `ThemeController.themeKey` - persisted theme selection ('red'/'yellow'/'blue')
  - `LocaleController.locale` - runtime language (English/Filipino)
  - `MotionController.reduceMotion` - accessibility preference
- **ChangeNotifier** services: `POSService`, `CCTVService` extend `ChangeNotifier` for reactive updates
- Use `ValueListenableBuilder` in `main.dart` to rebuild MaterialApp on theme/locale changes
- Persistence via `shared_preferences` for theme, locale, motion settings

### Localization Pattern
**Lightweight in-app localization** (NOT using intl/ARB):
- `lib/utils/app_localizations.dart` contains static `Map<String, Map<String, String>>` for 'en' and 'fil'
- Call `AppLocalizations.t('key')` to fetch translation based on `LocaleController.locale.value`
- Placeholders use simple string replacement: `AppLocalizations.t('stock_label').replaceAll('{n}', count.toString())`
- Add new keys to both 'en' and 'fil' maps when introducing user-facing strings

### Theme System
- **Dynamic theming**: `lib/theme.dart` provides `AppTheme.forPrimary(MaterialColor)` to generate ThemeData
- `ThemeController.presets` maps keys to MaterialColors (includes 'black', 'green', 'violet', 'orange', 'brown', 'grey', 'red', 'yellow', 'blue')
- Icons should use `Theme.of(context).colorScheme.primary` (not hardcoded colors) to follow theme
- Settings screen (`lib/screens/shared/settings_screen.dart`) uses ChoiceChip for theme selection

### Navigation & Auth Flow
- **No formal router package**: Uses named routes in `AppRouter.routes` (only admin) + manual `MaterialPageRoute` with user parameters for owner/cashier
- **Login flow**: `login_screen.dart` → `LoadingScreen` (animated transition) → role-based dashboard
- **LoadingScreen**: Full-screen animated gradient, rotating icon, bouncing dots; auto-navigates via `pushReplacement` after 1400ms
- Dashboards require user context: `OwnerDashboard(user: user)`, `CashierDashboard(user: user)`

## Data Models & Database

### Core Models
Located in `lib/models/`:
- **Product**: id, name, barcode, category, sellingPrice, quantity, imagePath
- **CartItem**: wraps Product with quantity and discount
- **Sale/SaleItem**: transaction records with timestamps
- **User**: id, name, email, password, pin, role (UserRole.owner/cashier), isActive
- **InventoryMovement**: type (sale/restock/adjustment), quantity, timestamp

### Database Operations
- **POSService** (`lib/services/pos_service.dart`):
  - Manages products, cart, sales via `DatabaseService`
  - Exposes `cart`, `products`, `recentSales` getters
  - Cart computed totals: `cartSubtotal`, `cartDiscount`, `cartTotal`
  - Call `notifyListeners()` after state mutations
- **Seed data**: Uncomment `SeedService.seedSampleProducts()` in `main.dart` to populate demo products
- **Schema version**: Currently v3 in `database_service_io.dart`; handle migrations in `_upgradeTables`

## Key Screens & Components

### Role-Based Dashboards
- **AdminDashboard** (`lib/screens/admin/`): Manage users, products, view reports
- **OwnerDashboard** (`lib/screens/owner/`): Sales reports, CCTV monitoring, inventory
- **CashierDashboard** (`lib/screens/cashier/`): POS terminal access
- All use `AppLocalizations.t(...)` for text; no hardcoded strings

### POS Screen (`lib/screens/cashier/cashier_pos.dart`)
- Grid of product tiles with add-to-cart tap
- Cart sheet (modal bottom sheet) with +/- quantity controls using theme-colored icons
- Cart icons use `Icon(..., color: Theme.of(context).colorScheme.primary)` (NOT const)
- Checkout: validates stock, reduces quantities, records sale, clears cart

### Inventory Screen (`lib/screens/shared/inventory_screen.dart`)
- Search by name/barcode
- Update stock levels
- View inventory movement history per product
- Low stock warnings (stock <= 5 shown in red)

### CCTV Integration
- **CCTVService** supports RTSP/HTTP streams or local video files
- Configure via `CCTVService.instance.configure(cameraUrl: '...')`
- `cctv_screen.dart` uses `video_player` for playback
- `CCTVConfig` provides default demo URLs

## Development Workflow

### Running the App
```bash
# Mobile/Web
flutter run

# Desktop (Windows)
flutter run -d windows

# Generate release build
flutter build apk --release  # Android
flutter build windows --release
```

### Database Inspection
- SQLite database at `getDatabasesPath()/pos_system.db` on desktop
- Use DB Browser for SQLite or run queries via `DatabaseService` methods
- Reset DB: Delete file and restart app (schema recreated on init)

### Testing
- Widget tests in `test/widget_test.dart` use fake `POSService` via GetIt
- Unregister/re-register services in `setUp`/`tearDown` to avoid singleton conflicts
- Platform-specific code requires conditional imports (use `kIsWeb`, `defaultTargetPlatform`)

### Common Tasks
**Add new translation key**:
1. Add to both 'en' and 'fil' maps in `lib/utils/app_localizations.dart`
2. Use `AppLocalizations.t('new_key')` in UI
3. For dynamic values: `.replaceAll('{placeholder}', value)`

**Add new theme color**:
1. Add entry to `ThemeController.presets` map
2. Update settings screen ChoiceChip list

**New user role**:
1. Add to `UserRole` enum in `lib/models/user.dart`
2. Create dashboard in `lib/screens/<role>/`
3. Update login navigation logic in `login_screen.dart`

## Platform-Specific Notes

### Windows Desktop
- Camera capture NOT supported (no camera delegate); use `file_picker` for image selection
- Product images stored as file paths; validate paths exist before display
- Use `kIsWeb` and `defaultTargetPlatform` checks for platform-specific features

### Image Handling
- `image_picker` for mobile camera/gallery
- `file_picker` for desktop file selection
- Stored in `Product.imagePath` as absolute path string
- Future improvement: Copy images to app data directory to prevent broken paths

## Critical Patterns

### Don't
- ❌ Use `const Icon(...)` when icon needs dynamic color (breaks theme switching)
- ❌ Hardcode user-facing strings (always use `AppLocalizations.t(...)`)
- ❌ Access database directly in UI (use service methods)
- ❌ Forget `notifyListeners()` after service state changes
- ❌ Use `sqflite` APIs on web without conditional imports

### Do
- ✅ Use `Theme.of(context).colorScheme.primary` for icons/accents
- ✅ Persist settings via `shared_preferences` (see ThemeController/MotionController)
- ✅ Initialize services in `main()` before `runApp()`
- ✅ Use `ValueListenableBuilder` to rebuild UI on controller changes
- ✅ Add both English and Filipino translations for all new strings
- ✅ Call `await POSService.initialize()` before registering in GetIt
- ✅ Handle desktop FFI init: check platform and call `sqfliteFfiInit()` in `main()`

## External Dependencies
- **sqflite/sqflite_common_ffi**: Local database (products, sales, users)
- **shared_preferences**: Persisted settings (theme, locale, motion)
- **get_it**: Service locator pattern
- **fl_chart**: Sales charts and analytics visualization
- **mobile_scanner**: Barcode scanning for products
- **camera/video_player**: CCTV feed display
- **printing/pdf**: Receipt generation (planned feature)
- **image_picker/file_picker**: Product image selection (platform-specific)

## Notes
- Current implementation uses in-memory cart; consider persisting for crash recovery
- CCTV demo uses placeholder URLs; configure `CCTVConfig` for real streams
- Admin accounts managed separately from User table (see `AdminService`/`admin_account.dart`)
- Loading animations use `AnimationController` with staggered intervals for bouncing dots effect
