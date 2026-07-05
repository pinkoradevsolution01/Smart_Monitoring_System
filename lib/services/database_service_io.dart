import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/inventory_movement.dart';
import '../models/damage_report.dart';
import '../models/supplier.dart';
import '../models/restock_record.dart';
import '../models/purchase_order.dart';
import '../models/customer.dart';
import '../models/loyalty_ledger_entry.dart';
import 'supabase_sync_service.dart';

/// DatabaseService provides a singleton pattern for database operations.
/// Handles all CRUD operations for products, sales, inventory movements,
/// and provides analytics features like daily sales and transaction counting.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  bool _suppressCloudSync = false;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  SupabaseSyncService? _maybeSyncService() {
    try {
      return GetIt.I.isRegistered<SupabaseSyncService>()
          ? GetIt.I<SupabaseSyncService>()
          : null;
    } catch (_) {
      return null;
    }
  }

  void _queueCloudSync() {
    if (_suppressCloudSync) {
      return;
    }
    final sync = _maybeSyncService();
    if (sync != null && sync.isConfigured) {
      sync.queuePushAllData();
    }
  }

  Future<T> runWithoutCloudSync<T>(Future<T> Function() action) async {
    final previous = _suppressCloudSync;
    _suppressCloudSync = true;
    try {
      return await action();
    } finally {
      _suppressCloudSync = previous;
    }
  }

  /// Lazy initialization of database connection
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database and create tables if needed
  Future<Database> _initDatabase() async {
    // If running on the web, instruct the developer to use a web-compatible
    // database backend. Sqflite (and sqflite_common_ffi) do not work on web.
    if (kIsWeb) {
      throw StateError(
        'sqflite is not supported on the web. Use a web-compatible storage plugin (e.g. sembast_web, sqflite_web, or IndexedDB) or provide a conditional DatabaseService for web.',
      );
    }

    // Store database in Documents folder (persists after app uninstall)
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String appDataPath = join(documentsDir.path, 'SmartMonitoringSystem');

    // Create directory if it doesn't exist
    final appDataDir = Directory(appDataPath);
    if (!await appDataDir.exists()) {
      await appDataDir.create(recursive: true);
      debugPrint('📁 Created app data directory: $appDataPath');
    }

    final path = join(appDataPath, 'pos_system.db');
    debugPrint('📁 Opening database at: $path');

    final db = await openDatabase(
      path,
      version: 23,
      onCreate: (db, version) {
        debugPrint('🆕 Creating new database (version $version)');
        return _createTables(db, version);
      },
      onUpgrade: (db, oldVersion, newVersion) {
        debugPrint('⬆️ Upgrading database from v$oldVersion to v$newVersion');
        return _upgradeTables(db, oldVersion, newVersion);
      },
    );

    final dbVersion = await db.getVersion();
    debugPrint('✅ Database opened successfully (version $dbVersion)');

    // Force check and add return columns if they don't exist
    await _ensureReturnColumnsExist(db);

    // Force check and add payment columns if they don't exist
    await _ensurePaymentColumnsExist(db);

    // Force check and add shoe size columns if they don't exist
    await _ensureShoeSizeColumnsExist(db);

    // Remove legacy duplicate sales that may have been imported from backups
    // or created before saleNumber uniqueness was enforced.
    await _cleanupDuplicateSales(db);

    return db;
  }

  /// Create all database tables
  Future<void> _createTables(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        buyingPrice REAL NOT NULL,
        sellingPrice REAL NOT NULL,
        quantity INTEGER NOT NULL,
        reorderLevel INTEGER NOT NULL,
        category TEXT NOT NULL,
        imagePath TEXT,
        createdAt TEXT NOT NULL,
        shoeSizes TEXT,
        sizeType TEXT
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleNumber TEXT UNIQUE NOT NULL,
        itemCount INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        discountAmount REAL NOT NULL,
        taxAmount REAL NOT NULL,
        totalAmount REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        cashierName TEXT NOT NULL,
        saleDate TEXT NOT NULL,
        referenceCode TEXT,
        imagePath TEXT,
        cancelledReason TEXT,
        cancelledBy TEXT,
        cancelledAt TEXT,
        transactionType TEXT DEFAULT 'pos',
        reservationFee REAL,
        courier TEXT,
        deliveryStatus TEXT,
        customerId INTEGER,
        customerName TEXT,
        loyaltyPointsEarned INTEGER DEFAULT 0,
        loyaltyPointsRedeemed INTEGER DEFAULT 0
      )
    ''');

    // Sale items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        discount REAL NOT NULL,
        subtotal REAL NOT NULL,
        shoeSize TEXT,
        FOREIGN KEY (saleId) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products(id)
      )
    ''');

    // Inventory movements table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        quantityBefore INTEGER NOT NULL,
        quantityAfter INTEGER NOT NULL,
        quantityChanged INTEGER NOT NULL,
        movementType TEXT NOT NULL,
        reference TEXT NOT NULL,
        reason TEXT NOT NULL,
        movementDate TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products(id)
      )
    ''');

    // Damage reports table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS damage_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        totalValue REAL NOT NULL,
        reason TEXT NOT NULL,
        reportedBy TEXT NOT NULL,
        reportDate TEXT NOT NULL,
        returnStatus TEXT,
        returnApprovedBy TEXT,
        returnSignature TEXT,
        returnDate TEXT,
        paymentStatus TEXT,
        responsiblePerson TEXT,
        responsibleUserId TEXT,
        paymentDate TEXT,
        FOREIGN KEY (productId) REFERENCES products(id)
      )
    ''');

    // CCTV timestamps table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cctv_timestamps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        description TEXT,
        videoPath TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // Cameras table for multi-camera CCTV system
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cameras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        type TEXT NOT NULL,
        position INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        username TEXT,
        password TEXT
      )
    ''');

    // Attendance entries table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        time TEXT NOT NULL,
        type TEXT NOT NULL
      )
    ''');

    // Attendance leaves (admin recorded authorized breaks/leaves)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_leaves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        dateKey TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');

    // Attendance schedule (key/value JSON). We store a single key 'global'
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_schedule (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerCode TEXT UNIQUE NOT NULL,
        fullName TEXT NOT NULL,
        phoneNumber TEXT,
        email TEXT,
        address TEXT,
        pointsBalance INTEGER NOT NULL DEFAULT 0,
        lifetimePoints INTEGER NOT NULL DEFAULT 0,
        barcodeValue TEXT UNIQUE NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Loyalty ledger table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS loyalty_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER NOT NULL,
        saleId INTEGER,
        entryType TEXT NOT NULL,
        points INTEGER NOT NULL,
        balanceAfter INTEGER NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (saleId) REFERENCES sales(id) ON DELETE SET NULL
      )
    ''');

    // Suppliers table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contactPerson TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        address TEXT NOT NULL,
        notes TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Restock records table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS restock_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        supplierId INTEGER,
        supplierName TEXT,
        deliveryReceiptNo TEXT,
        damageQuantity INTEGER DEFAULT 0,
        damageReason TEXT,
        notes TEXT,
        referencedBy TEXT NOT NULL,
        restockDate TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products(id),
        FOREIGN KEY (supplierId) REFERENCES suppliers(id)
      )
    ''');

    // Purchase orders table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderNumber TEXT UNIQUE NOT NULL,
        supplierId INTEGER NOT NULL,
        supplierName TEXT NOT NULL,
        orderDate TEXT NOT NULL,
        expectedDeliveryDate TEXT,
        status TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        notes TEXT,
        approvedBy TEXT,
        signatureData TEXT,
        approvalDate TEXT,
        FOREIGN KEY (supplierId) REFERENCES suppliers(id)
      )
    ''');

    // Purchase order items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        totalPrice REAL NOT NULL,
        FOREIGN KEY (orderId) REFERENCES purchase_orders(id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products(id)
      )
    ''');

    // Activity logs table (audit/telemetry)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        message TEXT NOT NULL,
        meta TEXT,
        createdAt TEXT NOT NULL,
        sent INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indexes for performance
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_barcode ON products(barcode)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_date ON sales(saleDate)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_saleId ON sale_items(saleId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_productId ON inventory_movements(productId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_damage_reports_productId ON damage_reports(productId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_damage_reports_date ON damage_reports(reportDate)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cctv_timestamps_timestamp ON cctv_timestamps(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cameras_position ON cameras(position)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_restock_records_productId ON restock_records(productId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_restock_records_supplierId ON restock_records(supplierId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_restock_records_date ON restock_records(restockDate)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_orders_orderNumber ON purchase_orders(orderNumber)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplierId ON purchase_orders(supplierId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_order_items_orderId ON purchase_order_items(orderId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_logs_createdAt ON activity_logs(createdAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_fullName ON customers(fullName)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_barcodeValue ON customers(barcodeValue)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loyalty_ledger_customerId ON loyalty_ledger(customerId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loyalty_ledger_saleId ON loyalty_ledger(saleId)',
    );
    // Activity logs table index
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_logs_createdAt ON activity_logs(createdAt)',
    );
  }

  /// Handle database upgrades when version changes
  Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTables(db, newVersion);
    }
    if (oldVersion < 3) {
      // Add imagePath column to products table
      await db.execute('ALTER TABLE products ADD COLUMN imagePath TEXT');
    }
    if (oldVersion < 4) {
      // Add damage_reports table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS damage_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productId INTEGER NOT NULL,
          productName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unitPrice REAL NOT NULL,
          totalValue REAL NOT NULL,
          reason TEXT NOT NULL,
          reportedBy TEXT NOT NULL,
          reportDate TEXT NOT NULL,
          FOREIGN KEY (productId) REFERENCES products(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_damage_reports_productId ON damage_reports(productId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_damage_reports_date ON damage_reports(reportDate)',
      );
    }
    if (oldVersion < 5) {
      // Add cctv_timestamps table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cctv_timestamps (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          description TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cctv_timestamps_timestamp ON cctv_timestamps(timestamp)',
      );
    }
    if (oldVersion < 6) {
      // Add videoPath column to cctv_timestamps table
      await db.execute('ALTER TABLE cctv_timestamps ADD COLUMN videoPath TEXT');
    }
    if (oldVersion < 7) {
      // Add cameras table for multi-camera CCTV system
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cameras (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          type TEXT NOT NULL,
          position INTEGER NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cameras_position ON cameras(position)',
      );
    }
    if (oldVersion < 8) {
      // Add username and password columns for authenticated cameras (V380 Pro, etc.)
      try {
        await db.execute('ALTER TABLE cameras ADD COLUMN username TEXT');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE cameras ADD COLUMN password TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 9) {
      // Add referenceCode column to sales table for GCash/Online Bank transactions
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN referenceCode TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
    if (oldVersion < 10) {
      // Add imagePath column to sales table for captured receipt images
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN imagePath TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
    if (oldVersion < 11) {
      // Add cancellation fields to sales table
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN cancelledReason TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN cancelledBy TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN cancelledAt TEXT');
      } catch (e) {
        // Column might already exist, ignore error
      }
    }
    if (oldVersion < 12) {
      // Add suppliers table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          contactPerson TEXT NOT NULL,
          phone TEXT NOT NULL,
          email TEXT NOT NULL,
          address TEXT NOT NULL,
          notes TEXT,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name)',
      );

      // Add restock_records table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS restock_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productId INTEGER NOT NULL,
          productName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          supplierId INTEGER,
          supplierName TEXT,
          notes TEXT,
          referencedBy TEXT NOT NULL,
          restockDate TEXT NOT NULL,
          FOREIGN KEY (productId) REFERENCES products(id),
          FOREIGN KEY (supplierId) REFERENCES suppliers(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_restock_records_productId ON restock_records(productId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_restock_records_supplierId ON restock_records(supplierId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_restock_records_date ON restock_records(restockDate)',
      );
    }
    if (oldVersion < 13) {
      // Add delivery receipt and damage tracking columns to restock_records
      try {
        await db.execute(
          'ALTER TABLE restock_records ADD COLUMN deliveryReceiptNo TEXT',
        );
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute(
          'ALTER TABLE restock_records ADD COLUMN damageQuantity INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute(
          'ALTER TABLE restock_records ADD COLUMN damageReason TEXT',
        );
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 14) {
      // Add purchase orders tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orderNumber TEXT UNIQUE NOT NULL,
          supplierId INTEGER NOT NULL,
          supplierName TEXT NOT NULL,
          orderDate TEXT NOT NULL,
          expectedDeliveryDate TEXT,
          status TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          notes TEXT,
          approvedBy TEXT,
          signatureData TEXT,
          approvalDate TEXT,
          FOREIGN KEY (supplierId) REFERENCES suppliers(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_order_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orderId INTEGER NOT NULL,
          productId INTEGER NOT NULL,
          productName TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unitPrice REAL NOT NULL,
          totalPrice REAL NOT NULL,
          FOREIGN KEY (orderId) REFERENCES purchase_orders(id) ON DELETE CASCADE,
          FOREIGN KEY (productId) REFERENCES products(id)
        )
      ''');

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_orders_orderNumber ON purchase_orders(orderNumber)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplierId ON purchase_orders(supplierId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_order_items_orderId ON purchase_order_items(orderId)',
      );
    }
    if (oldVersion < 15) {
      // Add return status fields to damage_reports table
      try {
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnStatus TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnApprovedBy TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnSignature TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnDate TEXT',
        );
      } catch (e) {
        // Columns might already exist
        debugPrint('Note: Return columns may already exist in damage_reports');
      }
    }
    if (oldVersion < 16) {
      // Add shoe size support for shoe store business type
      try {
        await db.execute('ALTER TABLE products ADD COLUMN shoeSizes TEXT');
      } catch (e) {
        // Column might already exist
        debugPrint('Note: shoeSizes column may already exist in products');
      }
      try {
        await db.execute('ALTER TABLE products ADD COLUMN sizeType TEXT');
      } catch (e) {
        // Column might already exist
        debugPrint('Note: sizeType column may already exist in products');
      }
    }
    if (oldVersion < 17) {
      // Add shoeSize column to sale_items table
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN shoeSize TEXT');
        debugPrint('✅ Added shoeSize column to sale_items');
      } catch (e) {
        // Column might already exist
        debugPrint('Note: shoeSize column may already exist in sale_items');
      }
    }
    if (oldVersion < 18) {
      // Add activity_logs table for audit and telemetry
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          message TEXT NOT NULL,
          meta TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_logs_createdAt ON activity_logs(createdAt)',
      );
    }
    if (oldVersion < 19) {
      // Add sent column to activity_logs for telemetry sync tracking
      try {
        await db.execute(
          'ALTER TABLE activity_logs ADD COLUMN sent INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // may already exist
      }
    }
    if (oldVersion < 20) {
      // Add transactionType column to sales table
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN transactionType TEXT DEFAULT \'pos\'',
        );
        debugPrint('✅ Added transactionType column to sales');
      } catch (e) {
        debugPrint('Note: transactionType column may already exist in sales');
      }
    }
    if (oldVersion < 21) {
      // Add reservationFee column to sales table for reservation orders
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN reservationFee REAL');
        debugPrint('✅ Added reservationFee column to sales');
      } catch (e) {
        debugPrint('Note: reservationFee column may already exist in sales');
      }
    }
    if (oldVersion < 22) {
      // Add courier and deliveryStatus columns for delivery tracking
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN courier TEXT');
        debugPrint('✅ Added courier column to sales');
      } catch (e) {
        debugPrint('Note: courier column may already exist in sales');
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN deliveryStatus TEXT');
        debugPrint('✅ Added deliveryStatus column to sales');
      } catch (e) {
        debugPrint('Note: deliveryStatus column may already exist in sales');
      }
    }
    if (oldVersion < 23) {
      // Add customer loyalty support
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN customerId INTEGER');
      } catch (e) {
        debugPrint('Note: customerId column may already exist in sales');
      }
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN customerName TEXT');
      } catch (e) {
        debugPrint('Note: customerName column may already exist in sales');
      }
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN loyaltyPointsEarned INTEGER DEFAULT 0',
        );
      } catch (e) {
        debugPrint(
          'Note: loyaltyPointsEarned column may already exist in sales',
        );
      }
      try {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN loyaltyPointsRedeemed INTEGER DEFAULT 0',
        );
      } catch (e) {
        debugPrint(
          'Note: loyaltyPointsRedeemed column may already exist in sales',
        );
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerCode TEXT UNIQUE NOT NULL,
          fullName TEXT NOT NULL,
          phoneNumber TEXT,
          email TEXT,
          address TEXT,
          pointsBalance INTEGER NOT NULL DEFAULT 0,
          lifetimePoints INTEGER NOT NULL DEFAULT 0,
          barcodeValue TEXT UNIQUE NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS loyalty_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerId INTEGER NOT NULL,
          saleId INTEGER,
          entryType TEXT NOT NULL,
          points INTEGER NOT NULL,
          balanceAfter INTEGER NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL,
          FOREIGN KEY (customerId) REFERENCES customers(id) ON DELETE CASCADE,
          FOREIGN KEY (saleId) REFERENCES sales(id) ON DELETE SET NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_fullName ON customers(fullName)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_barcodeValue ON customers(barcodeValue)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_loyalty_ledger_customerId ON loyalty_ledger(customerId)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_loyalty_ledger_saleId ON loyalty_ledger(saleId)',
      );
    }
  }

  /// Ensure return columns exist in damage_reports table (migration helper)
  Future<void> _ensureReturnColumnsExist(Database db) async {
    try {
      // Try to query with return columns to see if they exist
      await db.rawQuery(
        'SELECT returnStatus, returnApprovedBy, returnSignature, returnDate FROM damage_reports LIMIT 1',
      );
      debugPrint('✅ Return columns already exist in damage_reports');
    } catch (e) {
      // Columns don't exist, add them
      debugPrint('⚠️ Return columns missing, adding them now...');
      try {
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnStatus TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnApprovedBy TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnSignature TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN returnDate TEXT',
        );
        debugPrint('✅ Return columns added successfully');
      } catch (alterError) {
        debugPrint('❌ Error adding return columns: $alterError');
      }
    }
  }

  /// Ensure payment columns exist in damage_reports table (migration helper)
  Future<void> _ensurePaymentColumnsExist(Database db) async {
    try {
      // Try to query with payment columns to see if they exist
      await db.rawQuery(
        'SELECT paymentStatus, responsiblePerson, responsibleUserId, paymentDate FROM damage_reports LIMIT 1',
      );
      debugPrint('✅ Payment columns already exist in damage_reports');
    } catch (e) {
      // Columns don't exist, add them
      debugPrint('⚠️ Payment columns missing, adding them now...');
      try {
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN paymentStatus TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN responsiblePerson TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN responsibleUserId TEXT',
        );
        await db.execute(
          'ALTER TABLE damage_reports ADD COLUMN paymentDate TEXT',
        );
        debugPrint('✅ Payment columns added successfully');
      } catch (alterError) {
        debugPrint('❌ Error adding payment columns: $alterError');
      }
    }
  }

  /// Ensure shoe size columns exist in products table (migration helper)
  Future<void> _ensureShoeSizeColumnsExist(Database db) async {
    try {
      // Try to query with shoe size columns to see if they exist
      await db.rawQuery('SELECT shoeSizes, sizeType FROM products LIMIT 1');
      debugPrint('✅ Shoe size columns already exist in products');
    } catch (e) {
      // Columns don't exist, add them
      debugPrint('⚠️ Shoe size columns missing, adding them now...');
      try {
        await db.execute('ALTER TABLE products ADD COLUMN shoeSizes TEXT');
        await db.execute('ALTER TABLE products ADD COLUMN sizeType TEXT');
        debugPrint('✅ Shoe size columns added successfully');
      } catch (alterError) {
        debugPrint('❌ Error adding shoe size columns: $alterError');
      }
    }
  }

  // ======================== PRODUCT OPERATIONS ========================

  /// Insert a new product into the database
  Future<int> insertProduct(Product product) async {
    final db = await database;
    final id = await db.insert('products', product.toMap());
    _queueCloudSync();
    return id;
  }

  /// Retrieve all products, ordered by name
  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name');
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  /// Get a product by its ID
  Future<Product?> getProductById(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  /// Get a product by its barcode
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  /// Search products by name (partial match)
  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  /// Update an existing product
  Future<int> updateProduct(Product product) async {
    final db = await database;
    final map = product.toMap();

    // Debug print for shoe products
    if (product.hasShoeVariants) {
      debugPrint('💾 Saving shoe product to DB:');
      debugPrint('   ID: ${product.id}');
      debugPrint('   Name: ${product.name}');
      debugPrint('   Persisted Quantity: ${map['quantity']}');
      debugPrint('   ShoeSizes JSON: ${map['shoeSizes']}');
    }

    final rows = await db.update('products', map, where: 'id = ?', whereArgs: [product.id]);
    _queueCloudSync();
    return rows;
  }

  /// Delete a product by its ID
  Future<int> deleteProduct(int id) async {
    final db = await database;
    final rows = await db.delete('products', where: 'id = ?', whereArgs: [id]);
    _queueCloudSync();
    return rows;
  }

  /// Get all products with stock below reorder level
  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'quantity <= reorderLevel',
      orderBy: 'quantity ASC',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  /// Get all products in a specific category
  Future<List<Product>> getProductsByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name',
    );
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  // ======================== CUSTOMER & LOYALTY OPERATIONS ========================

  Future<Customer> insertCustomer(Customer customer) async {
    final db = await database;
    final now = DateTime.now();
    final map = customer.copyWith(updatedAt: now).toMap();
    map['id'] = null;
    final id = await db.insert('customers', map);
    _queueCloudSync();
    return customer.copyWith(id: id, updatedAt: now);
  }

  Future<Customer> updateCustomer(Customer customer) async {
    final db = await database;
    final updated = customer.copyWith(updatedAt: DateTime.now());
    await db.update(
      'customers',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );
    _queueCloudSync();
    return updated;
  }

  Future<Customer> insertOrUpdateCustomer(Customer customer) async {
    final db = await database;
    final now = DateTime.now();
    final existing = customer.id == null
        ? []
        : await db.query(
            'customers',
            where: 'id = ?',
            whereArgs: [customer.id],
            limit: 1,
          );

    if (existing.isNotEmpty) {
      final updated = customer.copyWith(updatedAt: now);
      await db.update(
        'customers',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      _queueCloudSync();
      return updated;
    }

    final map = customer.copyWith(updatedAt: now).toMap();
    if (customer.id == null) {
      map['id'] = null;
    }
    final id = await db.insert('customers', map);
    _queueCloudSync();
    return customer.copyWith(id: id, updatedAt: now);
  }

  Future<List<Customer>> getCustomers({String? query}) async {
    final db = await database;
    final whereClauses = <String>['1 = 1'];
    final args = <Object?>[];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add(
        '(fullName LIKE ? OR phoneNumber LIKE ? OR email LIKE ? OR barcodeValue LIKE ?)',
      );
      final q = '%${query.trim()}%';
      args.addAll([q, q, q, q]);
    }

    final rows = await db.query(
      'customers',
      where: whereClauses.join(' AND '),
      whereArgs: args,
      orderBy: 'fullName COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<Customer?> getCustomerByBarcode(String barcodeValue) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'barcodeValue = ?',
      whereArgs: [barcodeValue],
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<Customer?> getCustomerByName(String fullName) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: 'LOWER(fullName) = LOWER(?)',
      whereArgs: [fullName.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<void> deactivateCustomer(int id) async {
    final customer = await getCustomerById(id);
    if (customer == null) return;
    await updateCustomer(customer.copyWith(isActive: false));
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'loyalty_ledger',
        where: 'customerId = ?',
        whereArgs: [id],
      );
      await txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
    _queueCloudSync();
  }

  Future<List<LoyaltyLedgerEntry>> getLoyaltyLedger(int customerId) async {
    final db = await database;
    final rows = await db.query(
      'loyalty_ledger',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'createdAt DESC',
    );
    return rows.map(LoyaltyLedgerEntry.fromMap).toList();
  }

  Future<void> replaceLoyaltyLedgerEntries(
    List<Map<String, dynamic>> entries,
  ) async {
    final db = await database;
    await db.delete('loyalty_ledger');
    if (entries.isNotEmpty) {
      final batch = db.batch();
      for (final entry in entries) {
        batch.insert('loyalty_ledger', entry);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> awardCustomerPoints({
    required int customerId,
    int? saleId,
    required int points,
    String? notes,
  }) async {
    if (points <= 0) return;
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final customer = Customer.fromMap(rows.first);
      final updated = customer.copyWith(
        pointsBalance: customer.pointsBalance + points,
        lifetimePoints: customer.lifetimePoints + points,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'customers',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [customerId],
      );
      await txn.insert('loyalty_ledger', {
        'customerId': customerId,
        'saleId': saleId,
        'entryType': LoyaltyEntryType.earn.toString().split('.').last,
        'points': points,
        'balanceAfter': updated.pointsBalance,
        'notes': notes,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _queueCloudSync();
  }

  Future<bool> redeemCustomerPoints({
    required int customerId,
    required int points,
    String? notes,
  }) async {
    if (points <= 0) return false;
    final db = await database;
    var success = false;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final customer = Customer.fromMap(rows.first);
      if (customer.pointsBalance < points) return;

      final updated = customer.copyWith(
        pointsBalance: customer.pointsBalance - points,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'customers',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [customerId],
      );
      await txn.insert('loyalty_ledger', {
        'customerId': customerId,
        'saleId': null,
        'entryType': LoyaltyEntryType.redeem.toString().split('.').last,
        'points': -points,
        'balanceAfter': updated.pointsBalance,
        'notes': notes,
        'createdAt': DateTime.now().toIso8601String(),
      });
      success = true;
    });
    if (success) {
      _queueCloudSync();
    }
    return success;
  }

  // ======================== SALE OPERATIONS ========================

  /// Insert a new sale with all its items
  Future<int> insertSale(Sale sale) async {
    final db = await database;
    // Prepare sale map but exclude nested items list (sqflite doesn't accept
    // nested List/Map types). Items are stored in `sale_items` table.
    final saleMap = Map<String, dynamic>.from(sale.toMap());
    saleMap.remove('items');
    saleMap.remove('id');

    debugPrint('📝 Inserting sale: ${sale.saleNumber}');
    debugPrint('   - Payment Method: ${sale.paymentMethod}');
    debugPrint('   - Total Amount: ₱${sale.totalAmount}');
    debugPrint('   - Tax Amount (Transfer Fee): ₱${sale.taxAmount}');
    debugPrint('   - Reference Code: ${sale.referenceCode}');
    debugPrint('   - Image Path: ${sale.imagePath}');

    try {
      final saleId = await db.insert('sales', saleMap);
      debugPrint('✅ Sale inserted with ID: $saleId');

      await _insertSaleItems(db, saleId, sale.items);

      _queueCloudSync();
      return saleId;
    } catch (e) {
      debugPrint('❌ Error inserting sale: $e');
      debugPrint('   Sale map: $saleMap');
      rethrow;
    }
  }

  Future<void> _insertSaleItems(
    DatabaseExecutor executor,
    int saleId,
    List<SaleItem> items,
  ) async {
    for (final item in items) {
      await executor.insert('sale_items', {
        'saleId': saleId,
        'productId': item.productId,
        'productName': item.productName,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'discount': item.discount,
        'subtotal': item.subtotal,
        'shoeSize': item.shoeSize,
      });
    }
  }

  List<Sale> _dedupeSalesByNumber(List<Sale> sales) {
    final Map<String, Sale> unique = {};
    for (final sale in sales) {
      unique.putIfAbsent(sale.saleNumber, () => sale);
    }
    return unique.values.toList();
  }

  Future<void> _cleanupDuplicateSales(Database db) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sales',
        columns: ['id', 'saleNumber', 'saleDate'],
        orderBy: 'saleDate DESC, id DESC',
      );

      final seenSaleNumbers = <String>{};
      final duplicateIds = <int>[];

      for (final row in rows) {
        final saleNumber = row['saleNumber'] as String?;
        final saleId = row['id'] as int?;
        if (saleNumber == null || saleId == null) {
          continue;
        }

        if (seenSaleNumbers.add(saleNumber)) {
          continue;
        }

        duplicateIds.add(saleId);
      }

      if (duplicateIds.isEmpty) {
        return;
      }

      for (final saleId in duplicateIds) {
        await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
        await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
      }

      debugPrint(
        '🧹 Removed ${duplicateIds.length} duplicate sale record(s) during database cleanup',
      );
    });
  }

  /// Insert or replace a sale by sale number.
  /// Used by cloud restore so repeated syncs do not fail on UNIQUE constraints.
  Future<int> insertOrUpdateSale(Sale sale) async {
    final db = await database;
    final saleMap = Map<String, dynamic>.from(sale.toMap());
    saleMap.remove('items');
    saleMap.remove('id');

    return await db.transaction((txn) async {
      final existingRows = await txn.query(
        'sales',
        columns: ['id'],
        where: 'saleNumber = ?',
        whereArgs: [sale.saleNumber],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final saleId = existingRows.first['id'] as int;
        await txn.update(
          'sales',
          saleMap,
          where: 'id = ?',
          whereArgs: [saleId],
        );
        await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);
        await _insertSaleItems(txn, saleId, sale.items);
        return saleId;
      }

      final saleId = await txn.insert('sales', saleMap);
      await _insertSaleItems(txn, saleId, sale.items);
      return saleId;
    });
  }

  /// Get a sale by its ID with all its items
  Future<Sale?> getSaleById(int id) async {
    final db = await database;
    final saleMaps = await db.query('sales', where: 'id = ?', whereArgs: [id]);
    if (saleMaps.isEmpty) return null;

    final sale = Sale.fromMap(saleMaps.first);
    final itemMaps = await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [id],
    );

    final items = itemMaps.map((map) => SaleItem.fromMap(map)).toList();
    debugPrint('📦 Loaded ${items.length} items for sale $id');
    for (final item in items) {
      debugPrint('   - ${item.productName}, shoeSize: ${item.shoeSize}');
    }
    return sale.copyWith(items: items);
  }

  /// Update an existing sale (e.g., for cancellation)
  Future<void> updateSale(Sale sale) async {
    final db = await database;
    final saleMap = Map<String, dynamic>.from(sale.toMap());
    saleMap.remove('items');
    saleMap['id'] = sale.id;

    await db.update('sales', saleMap, where: 'id = ?', whereArgs: [sale.id]);
    debugPrint('✅ Sale updated: ${sale.saleNumber} (Status: ${sale.status})');
    _queueCloudSync();
  }

  /// Get all sales, optionally filtered by date range
  Future<List<Sale>> getAllSales({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (startDate != null && endDate != null) {
      where = 'saleDate >= ? AND saleDate <= ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final maps = await db.query(
      'sales',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'saleDate DESC',
    );
    final List<Sale> results = [];
    for (final map in maps) {
      final sale = Sale.fromMap(map);
      final saleId =
          map['id'] as int? ?? 0; // defensive - but id should exist from DB
      final itemMaps = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((m) => SaleItem.fromMap(m)).toList();
      results.add(sale.copyWith(items: items));
    }
    return _dedupeSalesByNumber(results);
  }

  /// Get sales for a specific date range
  Future<List<Sale>> getSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    // Set start date to beginning of day and end date to end of day
    final adjustedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final adjustedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final maps = await db.query(
      'sales',
      where: 'saleDate >= ? AND saleDate <= ?',
      whereArgs: [
        adjustedStart.toIso8601String(),
        adjustedEnd.toIso8601String(),
      ],
      orderBy: 'saleDate DESC',
    );
    final List<Sale> results = [];
    for (final map in maps) {
      final sale = Sale.fromMap(map);
      final saleId = map['id'] as int? ?? 0;
      final itemMaps = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((m) => SaleItem.fromMap(m)).toList();
      results.add(sale.copyWith(items: items));
    }
    return _dedupeSalesByNumber(results);
  }

  /// Get delivery sales by status (for For Delivery screen)
  Future<List<Sale>> getDeliverySalesByStatus({SaleStatus? status}) async {
    final db = await database;
    String where = 'transactionType = ?';
    List<dynamic> whereArgs = ['delivery'];

    if (status != null) {
      where += ' AND status = ?';
      whereArgs.add(status.toString().split('.').last);
    }

    final maps = await db.query(
      'sales',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'saleDate DESC',
    );
    final List<Sale> results = [];
    for (final map in maps) {
      final sale = Sale.fromMap(map);
      final saleId = map['id'] as int? ?? 0;
      final itemMaps = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((m) => SaleItem.fromMap(m)).toList();
      results.add(sale.copyWith(items: items));
    }
    return _dedupeSalesByNumber(results);
  }

  /// Calculate total sales for a specific day
  Future<double> getDailySales(DateTime date) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(const Duration(days: 1));
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    double total = 0.0;
    for (final sale in sales) {
      if (sale.status == SaleStatus.completed) {
        total += sale.totalAmount;
      }
    }
    return total;
  }

  /// Get transaction count for a specific day
  Future<int> getTotalTransactions(DateTime date) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(const Duration(days: 1));
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    return sales.where((sale) => sale.status == SaleStatus.completed).length;
  }

  /// Calculate total sales for a date range
  Future<double> getSalesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    double total = 0.0;
    for (final sale in sales) {
      if (sale.status == SaleStatus.completed) {
        total += sale.totalAmount;
      }
    }
    return total;
  }

  /// Get transaction count for a date range
  Future<int> getTransactionCountForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    return sales.where((sale) => sale.status == SaleStatus.completed).length;
  }

  // ======================== INVENTORY MOVEMENT OPERATIONS ========================

  /// Record an inventory movement (stock change)
  Future<void> recordInventoryMovement(InventoryMovement movement) async {
    final db = await database;
    await db.insert('inventory_movements', movement.toMap());
  }

  /// Get all inventory movements for a product
  Future<List<InventoryMovement>> getProductMovements(int productId) async {
    final db = await database;
    final maps = await db.query(
      'inventory_movements',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'movementDate DESC',
    );
    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// Get inventory movements for a product within a date range
  Future<List<InventoryMovement>> getProductMovementsByDateRange(
    int productId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'inventory_movements',
      where: 'productId = ? AND movementDate >= ? AND movementDate < ?',
      whereArgs: [
        productId,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'movementDate DESC',
    );
    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// Get all inventory movements within a date range
  Future<List<InventoryMovement>> getAllMovementsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'inventory_movements',
      where: 'movementDate >= ? AND movementDate < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'movementDate DESC',
    );
    return maps.map((map) => InventoryMovement.fromMap(map)).toList();
  }

  /// Replace all inventory movements with a restored set from cloud sync.
  /// The cloud backend stores a reduced movement payload, so quantityBefore
  /// and quantityAfter are approximated from the available quantity change.
  Future<void> replaceInventoryMovements(
    List<Map<String, dynamic>> movements,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('inventory_movements');
      for (final movement in movements) {
        await txn.insert('inventory_movements', movement);
      }
    });
  }

  // ======================== DAMAGE REPORT OPERATIONS ========================

  /// Insert a new damage report
  Future<int> insertDamageReport(DamageReport report) async {
    final db = await database;
    return await db.insert('damage_reports', report.toMap());
  }

  /// Get all damage reports
  Future<List<DamageReport>> getAllDamageReports() async {
    final db = await database;
    final maps = await db.query('damage_reports', orderBy: 'reportDate DESC');
    return maps.map((map) => DamageReport.fromMap(map)).toList();
  }

  /// Get damage reports by date range
  Future<List<DamageReport>> getDamageReportsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    // Set start date to beginning of day and end date to end of day
    final adjustedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final adjustedEnd = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
      999,
    );

    final maps = await db.query(
      'damage_reports',
      where: 'reportDate >= ? AND reportDate <= ?',
      whereArgs: [
        adjustedStart.toIso8601String(),
        adjustedEnd.toIso8601String(),
      ],
      orderBy: 'reportDate DESC',
    );
    return maps.map((map) => DamageReport.fromMap(map)).toList();
  }

  /// Get damage reports for a specific product
  Future<List<DamageReport>> getDamageReportsByProduct(int productId) async {
    final db = await database;
    final maps = await db.query(
      'damage_reports',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'reportDate DESC',
    );
    return maps.map((map) => DamageReport.fromMap(map)).toList();
  }

  /// Get total damage value by date range
  Future<double> getTotalDamageValue(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(totalValue) as total FROM damage_reports WHERE reportDate >= ? AND reportDate < ?',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );
    return (result.first['total'] as double?) ?? 0.0;
  }

  /// Delete a damage report
  Future<int> deleteDamageReport(int id) async {
    final db = await database;
    return await db.delete('damage_reports', where: 'id = ?', whereArgs: [id]);
  }

  /// Update damage report with return information
  Future<int> updateDamageReportReturn({
    required int reportId,
    required String approvedBy,
    required String signature,
  }) async {
    final db = await database;
    return await db.update(
      'damage_reports',
      {
        'returnStatus': 'returned',
        'returnApprovedBy': approvedBy,
        'returnSignature': signature,
        'returnDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  /// Get damage report by ID
  Future<DamageReport?> getDamageReportById(int id) async {
    final db = await database;
    final maps = await db.query(
      'damage_reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return DamageReport.fromMap(maps.first);
  }

  /// Update damage report with payment information
  Future<int> updateDamageReportPayment({
    required int reportId,
    required String responsiblePerson,
    String? responsibleUserId,
  }) async {
    final db = await database;
    return await db.update(
      'damage_reports',
      {
        'paymentStatus': 'paid',
        'responsiblePerson': responsiblePerson,
        'responsibleUserId': responsibleUserId,
        'paymentDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  // ======================== CCTV TIMESTAMP OPERATIONS ========================

  /// Insert a new CCTV timestamp
  Future<int> insertCCTVTimestamp(Map<String, dynamic> timestamp) async {
    final db = await database;
    final id = await db.insert('cctv_timestamps', timestamp);
    _queueCloudSync();
    return id;
  }

  /// Get all CCTV timestamps ordered by timestamp descending
  Future<List<Map<String, dynamic>>> getAllCCTVTimestamps() async {
    final db = await database;
    return await db.query('cctv_timestamps', orderBy: 'timestamp DESC');
  }

  /// Get CCTV timestamps by date range
  Future<List<Map<String, dynamic>>> getCCTVTimestampsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return await db.query(
      'cctv_timestamps',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
  }

  /// Delete a CCTV timestamp
  Future<int> deleteCCTVTimestamp(int id) async {
    final db = await database;
    final rows = await db.delete('cctv_timestamps', where: 'id = ?', whereArgs: [id]);
    _queueCloudSync();
    return rows;
  }

  /// Update a CCTV timestamp (e.g., to add video path)
  Future<int> updateCCTVTimestamp(int id, Map<String, dynamic> data) async {
    final db = await database;
    final rows = await db.update(
      'cctv_timestamps',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
    _queueCloudSync();
    return rows;
  }

  /// Delete all CCTV timestamps
  Future<int> deleteAllCCTVTimestamps() async {
    final db = await database;
    final rows = await db.delete('cctv_timestamps');
    _queueCloudSync();
    return rows;
  }

  // ======================== CAMERA OPERATIONS ========================

  /// Insert a new camera
  Future<int> insertCamera(Map<String, dynamic> camera) async {
    final db = await database;
    final id = await db.insert('cameras', camera);
    _queueCloudSync();
    return id;
  }

  /// Get all cameras ordered by position
  Future<List<Map<String, dynamic>>> getAllCameras() async {
    final db = await database;
    return await db.query('cameras', orderBy: 'position ASC');
  }

  /// Get active cameras only
  Future<List<Map<String, dynamic>>> getActiveCameras() async {
    final db = await database;
    return await db.query(
      'cameras',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'position ASC',
    );
  }

  /// Get a camera by its ID
  Future<Map<String, dynamic>?> getCameraById(int id) async {
    final db = await database;
    final results = await db.query(
      'cameras',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update a camera
  Future<int> updateCamera(int id, Map<String, dynamic> data) async {
    final db = await database;
    final rows = await db.update('cameras', data, where: 'id = ?', whereArgs: [id]);
    _queueCloudSync();
    return rows;
  }

  /// Delete a camera
  Future<int> deleteCamera(int id) async {
    final db = await database;
    final rows = await db.delete('cameras', where: 'id = ?', whereArgs: [id]);
    _queueCloudSync();
    return rows;
  }

  /// Update camera positions (for reordering)
  Future<void> updateCameraPositions(
    List<Map<int, int>> idPositionPairs,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final pair in idPositionPairs) {
      final id = pair.keys.first;
      final position = pair[id]!;
      batch.update(
        'cameras',
        {'position': position},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    _queueCloudSync();
  }

  // ======================== DATABASE MANAGEMENT ========================

  /// Close the database connection
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Reset the database (delete all data)
  /// WARNING: This is destructive and cannot be undone
  // This method is intentionally provided for testing or maintenance tasks
  // and may not be referenced directly by the app at runtime.
  Future<void> resetAllData() async {
    final db = await database;
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('inventory_movements');
    await db.delete('damage_reports');
    await db.delete('products');
    // Optionally reclaim space
    await db.execute('VACUUM');
  }

  /// Clear ALL data from all tables (used for subscriber deactivation)
  /// WARNING: This is destructive and cannot be undone
  Future<void> clearAllData() async {
    final db = await database;
    // Delete all data from all tables in correct order (respecting foreign keys)
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('inventory_movements');
    await db.delete('damage_reports');
    await db.delete('cctv_timestamps');
    await db.delete('cameras');
    await db.delete('attendance_entries');
    await db.delete('attendance_leaves');
    await db.delete('attendance_schedule');
    await db.delete('purchase_order_items');
    await db.delete('purchase_orders');
    await db.delete('restock_records');
    await db.delete('suppliers');
    await db.delete('products');
    await db.delete('activity_logs');
    // Reclaim space
    await db.execute('VACUUM');
  }

  /// Reset only sales data (keeps products and inventory)
  /// WARNING: This is destructive and cannot be undone
  Future<void> resetSalesData() async {
    final db = await database;
    await db.delete('sale_items');
    await db.delete('sales');
    // Optionally reclaim space
    await db.execute('VACUUM');
  }

  /// Insert an activity log entry for auditing/telemetry purposes.
  /// `type` is a short event key (e.g. 'trial_activated', 'trial_cancelled').
  Future<int> insertActivityLog(
    String type,
    String message, {
    Map<String, dynamic>? meta,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final row = {
      'type': type,
      'message': message,
      'meta': meta != null ? jsonEncode(meta) : null,
      'createdAt': now,
    };
    final id = await db.insert('activity_logs', row);
    _queueCloudSync();
    return id;
  }

  Future<void> replaceActivityLogs(
    List<Map<String, dynamic>> logs,
  ) async {
    final db = await database;
    await db.delete('activity_logs');
    if (logs.isNotEmpty) {
      final batch = db.batch();
      for (final log in logs) {
        batch.insert('activity_logs', log);
      }
      await batch.commit(noResult: true);
    }
  }

  /// Fetch activity logs with optional filters (type, date range) ordered by createdAt desc
  Future<List<Map<String, dynamic>>> fetchActivityLogs({
    String? type,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (type != null && type.isNotEmpty) {
      where.add('type = ?');
      args.add(type);
    }
    if (from != null) {
      where.add('createdAt >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('createdAt <= ?');
      args.add(to.toIso8601String());
    }
    final whereClause = where.isNotEmpty ? where.join(' AND ') : null;
    return await db.query(
      'activity_logs',
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
  }

  /// Fetch unsent activity logs (sent = 0)
  Future<List<Map<String, dynamic>>> fetchUnsentActivityLogs({
    int limit = 200,
  }) async {
    final db = await database;
    return await db.query(
      'activity_logs',
      where: 'sent = 0',
      orderBy: 'createdAt ASC',
      limit: limit,
    );
  }

  /// Mark activity log ids as sent (set sent = 1)
  Future<void> markActivityLogsSent(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'activity_logs',
        {'sent': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    _queueCloudSync();
  }

  // ============================================================================
  // BACKUP & RESTORE (Data Protection)
  // ============================================================================

  /// Create a backup of the database
  /// Backups are stored in Documents/SmartMonitoringSystem/Backups
  /// Returns the backup file path
  Future<String> createBackup() async {
    try {
      final db = await database;
      final dbPath = db.path;

      // Get Documents directory
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String backupDir = join(
        documentsDir.path,
        'SmartMonitoringSystem',
        'Backups',
      );

      // Create backup directory if it doesn't exist
      final backupDirectory = Directory(backupDir);
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      // Generate backup filename with timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final backupPath = join(backupDir, 'pos_system_backup_$timestamp.db');

      // Copy database file to backup location
      final dbFile = File(dbPath);
      await dbFile.copy(backupPath);
      await _writeUsersBackupFile(backupPath);

      debugPrint('✅ Backup created: $backupPath');
      return backupPath;
    } catch (e) {
      debugPrint('❌ Backup failed: $e');
      rethrow;
    }
  }

  /// Ensure the app's backup folder exists before any backups are created.
  Future<String> ensureBackupDirectoryExists() async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String backupDir = join(
      documentsDir.path,
      'SmartMonitoringSystem',
      'Backups',
    );

    final backupDirectory = Directory(backupDir);
    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
      debugPrint('✅ Backup directory created: $backupDir');
    }
    return backupDir;
  }

  /// Create a backup of the database into a specific directory selected by the user.
  /// Returns the backup file path.
  Future<String> createBackupAt(String directoryPath) async {
    try {
      final db = await database;
      final dbPath = db.path;

      // Ensure target directory exists
      final targetDir = Directory(directoryPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Test writability by creating a temporary sentinel file, then remove it.
      final testFile = File(join(targetDir.path, '.backup_write_test'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        throw Exception(
            'Permission denied writing to $directoryPath. On Android use app-specific folders or grant storage permission. Original error: $e');
      }

      // Generate backup filename with timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final backupPath = join(targetDir.path, 'pos_system_backup_$timestamp.db');

      // Copy database file to selected location
      final dbFile = File(dbPath);
      await dbFile.copy(backupPath);
      await _writeUsersBackupFile(backupPath);

      debugPrint('✅ Backup created at selected folder: $backupPath');
      return backupPath;
    } catch (e) {
      debugPrint('❌ createBackupAt failed: $e');
      rethrow;
    }
  }

  /// Copy an existing backup file into the app's Backups folder so it appears
  /// in the app's local backup list.
  Future<String> copyBackupToAppFolder(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Backup file not found: $sourcePath');
      }

      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String backupDir = join(
        documentsDir.path,
        'SmartMonitoringSystem',
        'Backups',
      );

      final backupDirectory = Directory(backupDir);
      if (!await backupDirectory.exists()) {
        await backupDirectory.create(recursive: true);
      }

      final sourceFileName = basename(sourcePath);
      final destinationPath = join(backupDir, sourceFileName);

      if (normalize(sourceFile.path) == normalize(destinationPath)) {
        await _copyUsersBackupFile(sourcePath, destinationPath);
        return sourceFile.path;
      }

      String finalDestinationPath = destinationPath;
      if (await File(finalDestinationPath).exists()) {
        final nameWithoutExtension = basenameWithoutExtension(sourceFileName);
        final fileExtension = extension(sourceFileName);
        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .split('.')[0];
        finalDestinationPath = join(
          backupDir,
          '${nameWithoutExtension}_$timestamp$fileExtension',
        );
      }

      await sourceFile.copy(finalDestinationPath);
      await _copyUsersBackupFile(sourcePath, finalDestinationPath);
      debugPrint('✅ Backup copied to app folder: $finalDestinationPath');
      return finalDestinationPath;
    } catch (e) {
      debugPrint('❌ copyBackupToAppFolder failed: $e');
      rethrow;
    }
  }

  /// Restore database from a backup file
  /// WARNING: This will replace all current data
  Future<void> restoreFromBackup(String backupPath) async {
    try {
      final db = await database;
      final dbPath = db.path;

      // Close current database connection
      await db.close();
      _database = null;

      // Copy backup file to database location
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found: $backupPath');
      }

      await backupFile.copy(dbPath);
      await _restoreUsersFromBackup(backupPath);

      debugPrint('✅ Database restored from: $backupPath');

      // Reinitialize database
      await database;

      // After restoring the database file, queue a cloud sync so restored
      // data is pushed to the configured backend (if any).
      try {
        _queueCloudSync();
        debugPrint('🔄 Queued cloud sync after restoreFromBackup');
      } catch (e) {
        debugPrint('⚠️ Could not queue cloud sync after restore: $e');
      }
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      rethrow;
    }
  }

  /// Get list of all available backups
  /// Returns list of backup file paths sorted by date (newest first)
  Future<List<String>> getAvailableBackups() async {
    try {
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String backupDir = join(
        documentsDir.path,
        'SmartMonitoringSystem',
        'Backups',
      );

      final backupDirectory = Directory(backupDir);
      if (!await backupDirectory.exists()) {
        return [];
      }

      final backups = await backupDirectory
          .list()
          .where((entity) => entity.path.endsWith('.db'))
          .map((entity) => entity.path)
          .toList();

      // Sort by filename (which contains timestamp)
      backups.sort((a, b) => b.compareTo(a));

      return backups;
    } catch (e) {
      debugPrint('❌ Failed to list backups: $e');
      return [];
    }
  }

  /// Delete old backups (keeps only the most recent N backups)
  /// Default: keeps last 7 backups
  Future<void> cleanupOldBackups({int keepCount = 7}) async {
    try {
      final backups = await getAvailableBackups();

      if (backups.length <= keepCount) {
        return;
      }

      // Delete backups beyond keepCount
      for (int i = keepCount; i < backups.length; i++) {
        final file = File(backups[i]);
        await file.delete();
        debugPrint('🗑️ Deleted old backup: ${backups[i]}');
      }

      debugPrint(
        '✅ Cleanup complete: kept $keepCount backups, deleted ${backups.length - keepCount}',
      );
    } catch (e) {
      debugPrint('❌ Cleanup failed: $e');
    }
  }

  /// Export database to a user-specified location (Windows/Linux/macOS)
  /// Returns the export path
  Future<String> exportDatabase(String destinationPath) async {
    try {
      final db = await database;
      final dbPath = db.path;

      final dbFile = File(dbPath);
      await dbFile.copy(destinationPath);
      await _copyUsersBackupFile(dbPath, destinationPath);

      debugPrint('✅ Database exported to: $destinationPath');
      return destinationPath;
    } catch (e) {
      debugPrint('❌ Export failed: $e');
      rethrow;
    }
  }

  /// Get database file as bytes (for Android/iOS export)
  /// Required because FilePicker on mobile platforms requires bytes parameter
  Future<List<int>> getDatabaseBytes() async {
    try {
      final db = await database;
      final dbPath = db.path;

      // Read the database file as bytes
      final dbFile = File(dbPath);
      final bytes = await dbFile.readAsBytes();

      debugPrint('✅ Database read as bytes: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      debugPrint('❌ Failed to read database bytes: $e');
      rethrow;
    }
  }

  /// Import database from bytes (for cloud restore)
  /// WARNING: This will replace all current data
  Future<void> importDatabaseFromBytes(List<int> bytes) async {
    try {
      final db = await database;
      final dbPath = db.path;

      // Close current database connection
      await db.close();
      _database = null;

      // Write bytes to database location
      final dbFile = File(dbPath);
      await dbFile.writeAsBytes(bytes);

      debugPrint('✅ Database imported from bytes: ${bytes.length} bytes');

      // Reinitialize database
      await database;

      // After importing the database bytes, queue a cloud sync so restored
      // data is pushed to the configured backend (if any).
      try {
        _queueCloudSync();
        debugPrint('🔄 Queued cloud sync after importDatabaseFromBytes');
      } catch (e) {
        debugPrint('⚠️ Could not queue cloud sync after import: $e');
      }
    } catch (e) {
      debugPrint('❌ Import failed: $e');
      rethrow;
    }
  }

  String _usersBackupPath(String backupPath) {
    final dir = dirname(backupPath);
    final baseName = basenameWithoutExtension(backupPath);
    return join(dir, '${baseName}_users.json');
  }

  Future<void> _writeUsersBackupFile(String backupPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('users_data') ?? '[]';
      final usersFile = File(_usersBackupPath(backupPath));
      await usersFile.writeAsString(usersJson);
      debugPrint('✅ Users backup written: ${usersFile.path}');
    } catch (e) {
      debugPrint('⚠️ Failed to write users backup file: $e');
    }
  }

  Future<void> _copyUsersBackupFile(
    String sourceBackupPath,
    String destinationBackupPath,
  ) async {
    try {
      final sourceUsersFile = File(_usersBackupPath(sourceBackupPath));
      if (!await sourceUsersFile.exists()) {
        return;
      }

      final destinationUsersFile = File(_usersBackupPath(destinationBackupPath));
      await sourceUsersFile.copy(destinationUsersFile.path);
      debugPrint('✅ Users backup copied: ${destinationUsersFile.path}');
    } catch (e) {
      debugPrint('⚠️ Failed to copy users backup file: $e');
    }
  }

  Future<void> _restoreUsersFromBackup(String backupPath) async {
    try {
      final usersFile = File(_usersBackupPath(backupPath));
      if (!await usersFile.exists()) {
        debugPrint('ℹ️ No users backup found for: $backupPath');
        return;
      }

      final usersJson = await usersFile.readAsString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('users_data', usersJson);
      debugPrint('✅ Users restored from: ${usersFile.path}');
    } catch (e) {
      debugPrint('⚠️ Failed to restore users backup file: $e');
    }
  }

  // ======================== ATTENDANCE OPERATIONS ========================

  /// Replace attendance entries for a user (delete existing then insert provided list).
  /// Each entry is a map with keys: 'time' (ISO string) and 'type'.
  Future<void> replaceAttendanceEntries(
    String userId,
    List<Map<String, dynamic>> entries,
  ) async {
    final db = await database;
    final batch = db.batch();
    await db.delete(
      'attendance_entries',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    for (final e in entries) {
      batch.insert('attendance_entries', {
        'userId': userId,
        'time': e['time'] as String,
        'type': e['type'] as String,
      });
    }
    await batch.commit(noResult: true);
    _queueCloudSync();
  }

  /// Load all attendance entries for a user (ordered ascending by time)
  Future<List<Map<String, dynamic>>> getAttendanceEntries(String userId) async {
    final db = await database;
    final rows = await db.query(
      'attendance_entries',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'time ASC',
    );
    return rows.map((r) => {'time': r['time'], 'type': r['type']}).toList();
  }

  /// Save (upsert) an attendance leave payload for a user/date
  Future<void> saveAttendanceLeave(
    String userId,
    String dateKey,
    String payloadJson,
  ) async {
    final db = await database;
    await db.delete(
      'attendance_leaves',
      where: 'userId = ? AND dateKey = ?',
      whereArgs: [userId, dateKey],
    );
    await db.insert('attendance_leaves', {
      'userId': userId,
      'dateKey': dateKey,
      'payload': payloadJson,
    });
    _queueCloudSync();
  }

  /// Load leaves map for a user (dateKey -> payload JSON string)
  Future<Map<String, String>> getAttendanceLeaves(String userId) async {
    final db = await database;
    final rows = await db.query(
      'attendance_leaves',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    final out = <String, String>{};
    for (final r in rows) {
      out[r['dateKey'] as String] = r['payload'] as String;
    }
    return out;
  }

  Future<void> removeAttendanceLeave(String userId, String dateKey) async {
    final db = await database;
    await db.delete(
      'attendance_leaves',
      where: 'userId = ? AND dateKey = ?',
      whereArgs: [userId, dateKey],
    );
    _queueCloudSync();
  }

  /// Save attendance schedule as JSON under key 'global'
  Future<void> saveAttendanceSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    final payload = jsonEncode(schedule);
    await db.delete(
      'attendance_schedule',
      where: 'key = ?',
      whereArgs: ['global'],
    );
    await db.insert('attendance_schedule', {'key': 'global', 'value': payload});
    _queueCloudSync();
  }

  /// Load attendance schedule map (or null if none)
  Future<Map<String, dynamic>?> loadAttendanceSchedule() async {
    final db = await database;
    final rows = await db.query(
      'attendance_schedule',
      where: 'key = ?',
      whereArgs: ['global'],
    );
    if (rows.isEmpty) return null;
    final v = rows.first['value'] as String;
    try {
      return jsonDecode(v) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ======================== END ATTENDANCE OPERATIONS ========================

  // ======================== SUPPLIER OPERATIONS ========================

  /// Insert a new supplier into the database
  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    final id = await db.insert('suppliers', supplier.toMap());
    _queueCloudSync();
    return id;
  }

  /// Get all suppliers
  Future<List<Supplier>> getAllSuppliers() async {
    final db = await database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  /// Get active suppliers only
  Future<List<Supplier>> getActiveSuppliers() async {
    final db = await database;
    final maps = await db.query(
      'suppliers',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  /// Get supplier by ID
  Future<Supplier?> getSupplierById(int id) async {
    final db = await database;
    final maps = await db.query('suppliers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  /// Update supplier information
  Future<int> updateSupplier(Supplier supplier) async {
    final db = await database;
    final rows = await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    _queueCloudSync();
    return rows;
  }

  /// Delete a supplier
  Future<int> deleteSupplier(int id) async {
    final db = await database;
    final rows = await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    _queueCloudSync();
    return rows;
  }

  /// Search suppliers by name or contact person
  Future<List<Supplier>> searchSuppliers(String query) async {
    final db = await database;
    final maps = await db.query(
      'suppliers',
      where: 'name LIKE ? OR contactPerson LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  // ======================== RESTOCK RECORD OPERATIONS ========================

  /// Insert a new restock record
  Future<int> insertRestockRecord(RestockRecord record) async {
    final db = await database;
    return db.insert('restock_records', record.toMap());
  }

  /// Get all restock records
  Future<List<RestockRecord>> getAllRestockRecords() async {
    final db = await database;
    final maps = await db.query('restock_records', orderBy: 'restockDate DESC');
    return maps.map((map) => RestockRecord.fromMap(map)).toList();
  }

  /// Get restock records for a specific product
  Future<List<RestockRecord>> getRestockRecordsByProductId(
    int productId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'restock_records',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'restockDate DESC',
    );
    return maps.map((map) => RestockRecord.fromMap(map)).toList();
  }

  /// Get restock records for a specific supplier
  Future<List<RestockRecord>> getRestockRecordsBySupplierId(
    int supplierId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'restock_records',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      orderBy: 'restockDate DESC',
    );
    return maps.map((map) => RestockRecord.fromMap(map)).toList();
  }

  /// Get restock records within a date range
  Future<List<RestockRecord>> getRestockRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'restock_records',
      where: 'restockDate BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'restockDate DESC',
    );
    return maps.map((map) => RestockRecord.fromMap(map)).toList();
  }

  /// Delete a restock record
  Future<int> deleteRestockRecord(int id) async {
    final db = await database;
    return db.delete('restock_records', where: 'id = ?', whereArgs: [id]);
  }

  // ======================== PURCHASE ORDER OPERATIONS ========================

  /// Generate unique order number
  String generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(6);
    return 'PO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$timestamp';
  }

  /// Insert a new purchase order with items
  Future<int> insertPurchaseOrder(PurchaseOrder order) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Insert order
      final orderId = await txn.insert('purchase_orders', order.toMap());

      // Insert order items
      for (final item in order.items) {
        await txn.insert(
          'purchase_order_items',
          item.copyWith(orderId: orderId).toMap(),
        );
      }

      return orderId;
    });
  }

  /// Insert or replace a purchase order by order number.
  /// Used by cloud restore so repeated syncs do not create duplicates.
  Future<int> insertOrUpdatePurchaseOrder(PurchaseOrder order) async {
    final db = await database;

    return await db.transaction((txn) async {
      final existingRows = await txn.query(
        'purchase_orders',
        columns: ['id'],
        where: 'orderNumber = ?',
        whereArgs: [order.orderNumber],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final orderId = existingRows.first['id'] as int;
        await txn.update(
          'purchase_orders',
          order.copyWith(id: orderId).toMap(),
          where: 'id = ?',
          whereArgs: [orderId],
        );
        await txn.delete(
          'purchase_order_items',
          where: 'orderId = ?',
          whereArgs: [orderId],
        );
        for (final item in order.items) {
          await txn.insert(
            'purchase_order_items',
            item.copyWith(orderId: orderId).toMap(),
          );
        }
        return orderId;
      }

      final orderId = await txn.insert('purchase_orders', order.toMap());
      for (final item in order.items) {
        await txn.insert(
          'purchase_order_items',
          item.copyWith(orderId: orderId).toMap(),
        );
      }
      return orderId;
    });
  }

  /// Get all purchase orders
  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    final db = await database;
    final maps = await db.query('purchase_orders', orderBy: 'orderDate DESC');

    final orders = <PurchaseOrder>[];
    for (final map in maps) {
      final items = await getPurchaseOrderItems(map['id'] as int);
      orders.add(PurchaseOrder.fromMap(map).copyWith(items: items));
    }

    return orders;
  }

  /// Get purchase order by ID
  Future<PurchaseOrder?> getPurchaseOrderById(int id) async {
    final db = await database;
    final maps = await db.query(
      'purchase_orders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final items = await getPurchaseOrderItems(id);
    return PurchaseOrder.fromMap(maps.first).copyWith(items: items);
  }

  /// Get purchase order by order number
  Future<PurchaseOrder?> getPurchaseOrderByNumber(String orderNumber) async {
    final db = await database;
    final maps = await db.query(
      'purchase_orders',
      where: 'orderNumber = ?',
      whereArgs: [orderNumber],
    );

    if (maps.isEmpty) return null;

    final orderId = maps.first['id'] as int;
    final items = await getPurchaseOrderItems(orderId);
    return PurchaseOrder.fromMap(maps.first).copyWith(items: items);
  }

  /// Get purchase order items for a specific order
  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(int orderId) async {
    final db = await database;
    final maps = await db.query(
      'purchase_order_items',
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    return maps.map((map) => PurchaseOrderItem.fromMap(map)).toList();
  }

  /// Get purchase orders by supplier
  Future<List<PurchaseOrder>> getPurchaseOrdersBySupplier(
    int supplierId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'purchase_orders',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      orderBy: 'orderDate DESC',
    );

    final orders = <PurchaseOrder>[];
    for (final map in maps) {
      final items = await getPurchaseOrderItems(map['id'] as int);
      orders.add(PurchaseOrder.fromMap(map).copyWith(items: items));
    }

    return orders;
  }

  /// Get purchase orders by status
  Future<List<PurchaseOrder>> getPurchaseOrdersByStatus(String status) async {
    final db = await database;
    final maps = await db.query(
      'purchase_orders',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'orderDate DESC',
    );

    final orders = <PurchaseOrder>[];
    for (final map in maps) {
      final items = await getPurchaseOrderItems(map['id'] as int);
      orders.add(PurchaseOrder.fromMap(map).copyWith(items: items));
    }

    return orders;
  }

  /// Update purchase order
  Future<int> updatePurchaseOrder(PurchaseOrder order) async {
    final db = await database;

    return await db.transaction((txn) async {
      // Update order
      await txn.update(
        'purchase_orders',
        order.toMap(),
        where: 'id = ?',
        whereArgs: [order.id],
      );

      // Delete existing items
      await txn.delete(
        'purchase_order_items',
        where: 'orderId = ?',
        whereArgs: [order.id],
      );

      // Insert updated items
      for (final item in order.items) {
        await txn.insert(
          'purchase_order_items',
          item.copyWith(orderId: order.id!).toMap(),
        );
      }

      return order.id!;
    });
  }

  /// Approve purchase order with signature
  Future<int> approvePurchaseOrder(
    int orderId,
    String approvedBy,
    String signatureData,
  ) async {
    final db = await database;
    return db.update(
      'purchase_orders',
      {
        'status': 'approved',
        'approvedBy': approvedBy,
        'signatureData': signatureData,
        'approvalDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Update purchase order status
  Future<int> updatePurchaseOrderStatus(int orderId, String status) async {
    final db = await database;
    return db.update(
      'purchase_orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  /// Delete purchase order
  Future<int> deletePurchaseOrder(int id) async {
    final db = await database;
    // Items will be deleted automatically due to ON DELETE CASCADE
    return db.delete('purchase_orders', where: 'id = ?', whereArgs: [id]);
  }

  /// Get purchase order statistics
  Future<Map<String, dynamic>> getPurchaseOrderStatistics() async {
    final db = await database;

    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count, SUM(totalAmount) as total FROM purchase_orders',
    );

    final pendingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM purchase_orders WHERE status = ?',
      ['pending'],
    );

    final approvedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM purchase_orders WHERE status = ?',
      ['approved'],
    );

    return {
      'totalOrders': totalResult.first['count'] ?? 0,
      'totalAmount': totalResult.first['total'] ?? 0.0,
      'pendingOrders': pendingResult.first['count'] ?? 0,
      'approvedOrders': approvedResult.first['count'] ?? 0,
    };
  }

  // ======================== CLOUD SYNC HELPER METHODS ========================

  /// Insert or update a product (used for cloud sync)
  Future<int> insertOrUpdateProduct(Product product) async {
    if (product.id != null) {
      // Check if product exists
      final existing = await getProductById(product.id!);
      if (existing != null) {
        await updateProduct(product);
        return product.id!;
      }
    }
    return await insertProduct(product);
  }

  /// Insert or update a supplier (used for cloud sync)
  Future<int> insertOrUpdateSupplier(Supplier supplier) async {
    if (supplier.id != null) {
      // Check if supplier exists
      final existing = await getSupplierById(supplier.id!);
      if (existing != null) {
        await updateSupplier(supplier);
        return supplier.id!;
      }
    }
    return await insertSupplier(supplier);
  }
}
