# Smart Monitoring System - Development Guide

## Overview
This is a Flutter-based Point-of-Sale (POS) system with inventory management and sales reporting capabilities. The system is designed for retail store operations with role-based access (Admin, Owner, Cashier).

## Architecture

### Project Structure
```
lib/
├── main.dart                 # App entry point with GetIt DI registration
├── models/                   # Data models
│   ├── product.dart         # Product model with profit/lowStock helpers
│   ├── sale.dart            # Sale transaction model with SaleStatus enum
│   ├── sale_item.dart       # Individual items in a sale
│   ├── inventory_movement.dart  # Stock change tracking
│   └── cart_item.dart       # Shopping cart item model
├── services/
│   ├── database_service.dart     # SQLite persistence layer (singleton)
│   ├── pos_service.dart          # Business logic (ChangeNotifier)
│   └── seed_service.dart         # Sample data population for testing
├── screens/
│   ├── auth/                 # Authentication screens
│   ├── admin/                # Admin dashboard & management
│   ├── owner/                # Owner dashboard & sales reports
│   ├── cashier/              # Cashier POS terminal
│   └── shared/               # Shared screens (inventory, settings)
├── utils/
│   ├── app_localizations.dart    # Multi-language support (EN, Filipino)
│   ├── locale_controller.dart    # Language controller
│   └── theme_controller.dart     # Theme controller
└── widgets/                  # Reusable UI components
```

### Technology Stack
- **Framework:** Flutter (Dart)
- **Database:** SQLite (sqflite package)
- **State Management:** ChangeNotifier + GetIt DI
- **Localization:** Intl package with custom AppLocalizations
- **Dependency Injection:** GetIt (service locator pattern)

## Core Components

### 1. DatabaseService (Singleton Pattern)
**Location:** `lib/services/database_service.dart`

Handles all database operations:
- **Tables:** products, sales, sale_items, inventory_movements
- **Key Methods:**
  - Product operations: `insertProduct()`, `getAllProducts()`, `updateProduct()`, `deleteProduct()`, `searchProducts()`, `getLowStockProducts()`
  - Sale operations: `insertSale()`, `getSaleById()`, `getAllSales()`, `getDailySales()`, `getTotalTransactions()`
  - Inventory: `recordInventoryMovement()`, `getProductMovements()`, `getProductMovementsByDateRange()`

### 2. POSService (ChangeNotifier)
**Location:** `lib/services/pos_service.dart`

Business logic layer (state management):
- **Properties:** `cart` (List<CartItem>), `products` (List<Product>), `recentSales` (List<Sale>)
- **Cart Operations:** `addToCart()`, `removeFromCart()`, `updateCartItem()`, `clearCart()`
- **Sale Processing:** `processSale()` — creates sale, updates inventory, records movements, refreshes UI
- **Reporting:** `loadRecentSales()`, `getSalesReport()`, `getDailySales()`, `getTotalRevenue()`, `getTotalItemsSold()`

#### Sale Processing Flow
```
1. User clicks Checkout
2. POSService.processSale() is called with payment method & cashier name
3. Sale record is inserted into database
4. Sale items are inserted into sale_items table
5. For each cart item:
   - Product quantity is decremented
   - InventoryMovement record is created (tracks "sale" movement)
6. Cart is cleared and UI is refreshed via notifyListeners()
```

### 3. SeedService
**Location:** `lib/services/seed_service.dart`

Provides sample product data for development/testing:
- `seedSampleProducts()` — Populates 8 sample products (clothing, accessories, footwear)
- `clearAllProducts()` — Removes all products from database

**Usage (in main.dart):**
```dart
// Uncomment to seed on first run:
// await SeedService.seedSampleProducts();
```

## Key Features

### Cashier POS Screen (`lib/screens/cashier/cashier_pos.dart`)
- **Product Grid:** Displays all products with name, price, stock status
- **Quick Stock Indicator:** Red icon for low-stock items
- **Shopping Cart:** Modal bottom sheet with real-time totals
- **Checkout:** Processes sale, updates inventory, shows confirmation
- **Sales Log:** View recent sales (last 30 days) with item counts and totals

### Inventory Screen (`lib/screens/shared/inventory_screen.dart`)
- **Search Functionality:** Filter by product name or barcode
- **Stock Status:** Color-coded (red for low-stock, green for healthy)
- **Quick Stock Update:** Update quantity directly from list
- **Inventory Movements:** View historical stock changes for each product
- **Add Product:** FAB opens dialog to add new products
- **Localization:** All strings support English and Filipino

### Sales Report Screen (`lib/screens/owner/sales_report_screen.dart`)
- **Recent Sales List:** Shows sales with item counts, dates, and totals
- **Date Range Picker:** Filter sales by custom date range
- **Transaction Details:** Tap sale to see breakdown of items sold
- **Summary Stats:** Total items sold and total revenue display

## Running the Application

### Prerequisites
```bash
flutter pub get
```

### With Sample Data
1. Open `lib/main.dart`
2. Uncomment line (in `main()` function):
   ```dart
   await SeedService.seedSampleProducts();
   ```
3. Run the app once to seed, then re-comment the line
4. Run again to test with data

### Clean Run (No Sample Data)
```bash
flutter run
```

### Testing
```bash
# Run analyzer
flutter analyze

# Run tests
flutter test
```

## Localization

### Adding New Strings
1. Open `lib/utils/app_localizations.dart`
2. Add key to both English ('en') and Filipino ('fil') maps:
   ```dart
   'en': {
     'your_key': 'Your English text',
     // ...
   },
   'fil': {
     'your_key': 'Your Filipino text',
     // ...
   }
   ```
3. Use in screens:
   ```dart
   Text(AppLocalizations.t('your_key'))
   ```

## Error Handling

### Database Errors
- Caught in POSService.processSale() and logged to console
- User sees friendly snackbar message on UI
- Sale processing returns `false` on failure

### Asset/Network Errors
- Check import paths in services/screens
- Verify all model classes are exported correctly

## Common Tasks

### Add New Screen
1. Create file in `lib/screens/{role}/{screen_name}.dart`
2. Import models/services needed
3. Register route in `lib/app_router.dart`
4. Navigate from parent screen

### Modify Database Schema
1. Update table creation SQL in `DatabaseService._createTables()`
2. Increment `version` parameter in `openDatabase()`
3. Handle migration in `_upgradeTables()`
4. Update model classes and their `toMap()`/`fromMap()` methods

### Add Product Feature
1. Add method to `DatabaseService`
2. Call from `POSService` and notify listeners
3. Update UI screen to display/use feature

## Performance Considerations
- **Database:** SQLite with indexed queries on frequently searched fields (barcode, saleDate)
- **State Management:** GetIt singleton pattern avoids duplicate service instances
- **UI:** ChangeNotifier only refreshes listening screens on `.notifyListeners()`
- **Search:** Client-side filtering to avoid DB queries on every keystroke

## Future Enhancements
- [ ] Barcode scanning with mobile_scanner package
- [ ] PDF export for sales reports (printing package integrated)
- [ ] Analytics dashboard with fl_chart (already in dependencies)
- [ ] Cloud sync for multi-store operations
- [ ] Advanced inventory forecasting
- [ ] Staff performance tracking

## Debugging Tips
1. **Enable logging:** Check console for `print()` statements in `POSService.processSale()`
2. **Check DB state:** Use DatabaseService.getAllProducts() from console
3. **Verify models:** Ensure `toMap()` includes all fields used in `fromMap()`
4. **Test LocalePicker:** Change language to verify localization strings exist
5. **Monitor rebuilds:** Use DevTools widget inspector to trace rebuild sources

## Support
For issues or questions, refer to:
- Flutter docs: https://flutter.dev/docs
- GetIt docs: https://github.com/fluttercommunity/get_it
- Sqflite docs: https://pub.dev/packages/sqflite
