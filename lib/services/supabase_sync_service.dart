import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/product.dart';
import '../models/shoe_size.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../models/damage_report.dart';
import '../models/customer.dart';
import '../models/user.dart';
import 'database_service.dart';
import 'backend_api_service.dart';
import 'backend_config.dart';
import 'attendance_service.dart';
import 'user_service.dart';

/// Comprehensive cloud sync service for Supabase integration
/// Syncs all business data: products, sales, inventory, purchases, suppliers, etc.
class SupabaseSyncService extends ChangeNotifier {
  static final SupabaseSyncService _instance = SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;
  SupabaseSyncService._internal();

  final _api = ApiClient();

  String? _businessId;
  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSyncTime;
  final Map<String, int> _syncStats = {};
  Timer? _autoSyncTimer;
  Timer? _queuedPushTimer;
  bool _autoSyncEnabled = true;
  Duration _autoSyncInterval = const Duration(seconds: 30);
  Duration _queuedPushDelay = const Duration(seconds: 2);

  // Getters
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  Map<String, int> get syncStats => _syncStats;
  String? get businessId => _businessId;
  bool get isConfigured => BackendConfig.useRestBackend && _businessId != null;
  bool get isAutoSyncEnabled => _autoSyncEnabled;
  Duration get autoSyncInterval => _autoSyncInterval;
  Duration get queuedPushDelay => _queuedPushDelay;

  /// Initialize business context (call this after license activation)
  Future<void> initializeBusiness({
    required String businessName,
    required String ownerEmail,
    String? existingBusinessId,
  }) async {
    if (!BackendConfig.useRestBackend) {
      throw Exception('Backend not configured');
    }

    try {
      if (existingBusinessId != null) {
        // Use existing business ID
        _businessId = existingBusinessId;
      } else {
        final response = await _api.postJson(
          'business/init',
          body: {
            'businessName': businessName,
            'ownerEmail': ownerEmail,
            'existingBusinessId': existingBusinessId,
          },
        );
        if (response is Map<String, dynamic>) {
          _businessId = response['businessId']?.toString();
        }
      }

      debugPrint('✅ Business initialized: $_businessId');
      startAutoSync();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing business: $e');
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Push all local data to Supabase (Backup)
  Future<bool> pushAllData() async {
    if (!isConfigured) {
      _lastError = 'Business not initialized. Please activate license first.';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _lastError = null;
    _syncStats.clear();
    notifyListeners();

    try {
      debugPrint('📤 Starting full backup to Supabase...');

      // Push data in order (respecting foreign keys)
      await _pushUsers();
      await _pushCustomers();
      await _pushLoyaltyLedger();
      await _pushCameras();
      await _pushCctvTimestamps();
      await _pushAttendance();
      await _pushActivityLogs();
      await _pushSuppliers();
      await _pushProducts();
      await _pushSales();
      await _pushInventoryMovements();
      await _pushPurchaseOrders();
      await _pushDamageReports();

      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();

      debugPrint('✅ Backup completed successfully');
      debugPrint('📊 Sync stats: $_syncStats');
      return true;
    } catch (e) {
      debugPrint('❌ Backup failed: $e');
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Pull all data from Supabase to local database (Restore)
  Future<bool> pullAllData() async {
    if (!isConfigured) {
      _lastError = 'Business not initialized. Please activate license first.';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _lastError = null;
    _syncStats.clear();
    notifyListeners();

    try {
      debugPrint('📥 Starting restore from Supabase...');

      final db = DatabaseService();
      final payload = await _api.getJson(
        'sync/pull',
        queryParameters: {'businessId': _businessId!},
      );

      // Pull data in order (respecting foreign keys)
      await db.runWithoutCloudSync(() async {
        await _pullUsers(payload);
        await _pullCustomers(db, payload);
        await _pullLoyaltyLedger(db, payload);
        await _pullCameras(db, payload);
        await _pullCctvTimestamps(db, payload);
        await _pullAttendance(db, payload);
        await _pullActivityLogs(db, payload);
        await _pullSuppliers(db, payload);
        await _pullProducts(db, payload);
        await _pullSales(db, payload);
        await _pullInventoryMovements(db, payload);
        await _pullPurchaseOrders(db, payload);
        await _pullDamageReports(db, payload);
      });

      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();

      debugPrint('✅ Restore completed successfully');
      debugPrint('📊 Sync stats: $_syncStats');
      return true;
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Two-way sync: Pull then Push (ensures latest data everywhere)
  Future<bool> syncBidirectional() async {
    if (!isConfigured) {
      _lastError = 'Business not initialized. Please activate license first.';
      notifyListeners();
      return false;
    }

    try {
      debugPrint('🔄 Starting bidirectional sync...');

      // First pull cloud data
      final pullSuccess = await pullAllData();
      if (!pullSuccess) return false;

      // Then push local changes
      final pushSuccess = await pushAllData();
      return pushSuccess;
    } catch (e) {
      debugPrint('❌ Bidirectional sync failed: $e');
      _lastError = e.toString();
      return false;
    }
  }

  /// Start periodic background sync while the app is open.
  /// This helps keep multiple devices in sync against the same MySQL backend.
  void startAutoSync({Duration? interval}) {
    if (!isConfigured || !_autoSyncEnabled) {
      return;
    }

    if (interval != null && interval.inSeconds > 0) {
      _autoSyncInterval = interval;
    }

    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (_) async {
      if (!isConfigured || _isSyncing) {
        return;
      }

      try {
        await syncBidirectional();
      } catch (e) {
        debugPrint('⚠️ Auto-sync tick failed: $e');
      }
    });

    debugPrint(
      '✅ Auto-sync started for business $_businessId every ${_autoSyncInterval.inSeconds}s',
    );
  }

  /// Stop periodic background sync.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _queuedPushTimer?.cancel();
    _queuedPushTimer = null;
    debugPrint('ℹ️ Auto-sync stopped');
  }

  /// Enable or disable automatic syncing.
  void setAutoSyncEnabled(bool enabled, {Duration? interval}) {
    _autoSyncEnabled = enabled;
    if (enabled) {
      startAutoSync(interval: interval);
    } else {
      stopAutoSync();
    }
  }

  // ============================================================================
  // PUSH METHODS (Local → Cloud)
  // ============================================================================

  /// Queue a cloud push after a local write.
  /// Repeated calls within a short window collapse into one sync.
  void queuePushAllData({Duration? delay}) {
    if (!isConfigured || !_autoSyncEnabled) {
      return;
    }

    if (delay != null && delay.inMilliseconds > 0) {
      _queuedPushDelay = delay;
    }

    _queuedPushTimer?.cancel();
    _queuedPushTimer = Timer(_queuedPushDelay, () async {
      if (!isConfigured || _isSyncing) {
        return;
      }

      try {
        await pushAllData();
      } catch (e) {
        debugPrint('⚠️ Queued push failed: $e');
      }
    });
  }

  Future<void> _pushCustomers() async {
    try {
      final db = DatabaseService();
      final customers = await db.getCustomers();

      if (customers.isEmpty) {
        _syncStats['customers_pushed'] = 0;
        return;
      }

      final customerData = customers
          .map(
            (c) => {
              'id': c.id?.toString(),
              'business_id': _businessId,
              'customer_code': c.customerCode,
              'full_name': c.fullName,
              'phone_number': c.phoneNumber,
              'email': c.email,
              'address': c.address,
              'points_balance': c.pointsBalance,
              'lifetime_points': c.lifetimePoints,
              'barcode_value': c.barcodeValue,
              'created_at': c.createdAt.toIso8601String(),
              'updated_at': c.updatedAt.toIso8601String(),
              'is_active': c.isActive ? 1 : 0,
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'customers': customerData},
      );
      _syncStats['customers_pushed'] = customers.length;
      debugPrint('✅ Pushed ${customers.length} customers');
    } catch (e) {
      debugPrint('❌ Error pushing customers: $e');
      rethrow;
    }
  }

  Future<void> _pushUsers() async {
    try {
      final userService = UserService();
      await userService.initialize();
      final users = userService.users;

      if (users.isEmpty) {
        _syncStats['users_pushed'] = 0;
        return;
      }

      final userData = users
          .map(
            (user) => {
              'id': user.id,
              'business_id': _businessId,
              'email': user.email,
              'password_hash': user.password,
              'role': user.role.toString().split('.').last,
              'full_name': user.name,
              'contact_number': user.contactNumber,
              'auth_method': user.authMethod,
              'is_active': user.isActive ? 1 : 0,
              'last_login_at': null,
              'created_at': user.createdAt.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'users': userData},
      );
      _syncStats['users_pushed'] = users.length;
      debugPrint('✅ Pushed ${users.length} users');
    } catch (e) {
      debugPrint('❌ Error pushing users: $e');
      rethrow;
    }
  }

  Future<void> _pushLoyaltyLedger() async {
    try {
      final db = DatabaseService();
      final customers = await db.getCustomers();
      final entries = <Map<String, dynamic>>[];

      for (final customer in customers) {
        if (customer.id == null) continue;
        final ledger = await db.getLoyaltyLedger(customer.id!);
        for (final entry in ledger) {
          entries.add({
            'id': entry.id?.toString(),
            'business_id': _businessId,
            'customer_id': entry.customerId.toString(),
            'sale_id': entry.saleId?.toString(),
            'entry_type': entry.entryType.toString().split('.').last,
            'points': entry.points,
            'balance_after': entry.balanceAfter,
            'notes': entry.notes,
            'created_at': entry.createdAt.toIso8601String(),
          });
        }
      }

      if (entries.isEmpty) {
        _syncStats['loyalty_ledger_pushed'] = 0;
        return;
      }

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'loyaltyLedger': entries},
      );
      _syncStats['loyalty_ledger_pushed'] = entries.length;
      debugPrint('✅ Pushed ${entries.length} loyalty ledger entries');
    } catch (e) {
      debugPrint('❌ Error pushing loyalty ledger: $e');
      rethrow;
    }
  }

  Future<void> _pushCameras() async {
    try {
      final db = DatabaseService();
      final cameras = await db.getAllCameras();

      if (cameras.isEmpty) {
        _syncStats['cameras_pushed'] = 0;
        return;
      }

      final cameraData = cameras
          .map(
            (camera) => {
              'id': camera['id']?.toString(),
              'business_id': _businessId,
              'name': camera['name'],
              'location': camera['location'] ?? '',
              'stream_url': camera['url'] ?? camera['stream_url'] ?? '',
              'type': camera['type'] ?? 'http',
              'position': camera['position'] ?? 0,
              'is_active':
                  (camera['isActive'] ?? camera['is_active'] ?? 1) == 1,
              'username': camera['username'],
              'password': camera['password'],
              'created_at':
                  camera['createdAt']?.toString() ??
                  camera['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'cameras': cameraData},
      );
      _syncStats['cameras_pushed'] = cameras.length;
      debugPrint('✅ Pushed ${cameras.length} cameras');
    } catch (e) {
      debugPrint('❌ Error pushing cameras: $e');
      rethrow;
    }
  }

  Future<void> _pushCctvTimestamps() async {
    try {
      final db = DatabaseService();
      final timestamps = await db.getAllCCTVTimestamps();
      final cameras = await db.getAllCameras();

      if (timestamps.isEmpty) {
        _syncStats['cctv_timestamps_pushed'] = 0;
        return;
      }

      if (cameras.isEmpty) {
        debugPrint('⚠️ Skipping CCTV timestamp push because no cameras exist');
        _syncStats['cctv_timestamps_pushed'] = 0;
        return;
      }

      final cameraId = cameras.first['id']?.toString();
      if (cameraId == null || cameraId.isEmpty) {
        _syncStats['cctv_timestamps_pushed'] = 0;
        return;
      }

      final timestampData = timestamps
          .map(
            (timestamp) => {
              'id': timestamp['id']?.toString(),
              'business_id': _businessId,
              'camera_id': cameraId,
              'label': timestamp['description'] ?? 'Timestamp',
              'description': timestamp['description'],
              'timestamp':
                  timestamp['timestamp']?.toString() ??
                  DateTime.now().toIso8601String(),
              'notes': timestamp['notes'],
              'video_path': timestamp['videoPath'] ?? timestamp['video_path'],
              'created_by': 'system',
              'created_at':
                  timestamp['createdAt']?.toString() ??
                  timestamp['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'cctvTimestamps': timestampData},
      );
      _syncStats['cctv_timestamps_pushed'] = timestamps.length;
      debugPrint('✅ Pushed ${timestamps.length} CCTV timestamps');
    } catch (e) {
      debugPrint('❌ Error pushing CCTV timestamps: $e');
      rethrow;
    }
  }

  Future<void> _pushAttendance() async {
    try {
      final userService = UserService();
      await userService.initialize();

      final users = userService.users;
      final entries = <Map<String, dynamic>>[];
      final leaves = <Map<String, dynamic>>[];
      final archives = <Map<String, dynamic>>[];
      final attendance = AttendanceService.instance;

      for (final user in users) {
        final userEntries = await attendance.loadEntries(user.id);
        for (final entry in userEntries) {
          entries.add({
            'id': null,
            'business_id': _businessId,
            'user_id': user.id,
            'time': entry.time.toIso8601String(),
            'type': entry.type,
            'created_at': entry.time.toIso8601String(),
          });
        }

        final userLeaves = await attendance.loadLeaves(user.id);
        userLeaves.forEach((dateKey, payload) {
          leaves.add({
            'id': null,
            'business_id': _businessId,
            'user_id': user.id,
            'date_key': dateKey,
            'payload': payload is String ? payload : jsonEncode(payload),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        });

        final userArchive = await attendance.loadArchive(user.id);
        userArchive.forEach((dateKey, archivedEntries) {
          archives.add({
            'id': null,
            'business_id': _businessId,
            'user_id': user.id,
            'date_key': dateKey,
            'entries': jsonEncode(
              archivedEntries.map((entry) => entry.toJson()).toList(),
            ),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        });
      }

      final schedule = await attendance.loadSchedule();
      final schedulePayload = {
        'key': 'global',
        'value': jsonEncode(schedule),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final body = <String, dynamic>{'businessId': _businessId};
      if (entries.isNotEmpty) {
        body['attendanceEntries'] = entries;
      }
      if (leaves.isNotEmpty) {
        body['attendanceLeaves'] = leaves;
      }
      body['attendanceArchive'] = archives;
      body['attendanceSchedule'] = schedulePayload;

      await _api.postJson('sync/push', body: body);
      _syncStats['attendance_entries_pushed'] = entries.length;
      _syncStats['attendance_leaves_pushed'] = leaves.length;
      _syncStats['attendance_archive_pushed'] = archives.length;
      _syncStats['attendance_schedule_pushed'] = 1;
      debugPrint(
        '✅ Pushed ${entries.length} attendance entries and ${leaves.length} leaves',
      );
    } catch (e) {
      debugPrint('❌ Error pushing attendance data: $e');
      rethrow;
    }
  }

  Future<void> _pushActivityLogs() async {
    try {
      final db = DatabaseService();
      final logs = await db.fetchUnsentActivityLogs();

      if (logs.isEmpty) {
        _syncStats['activity_logs_pushed'] = 0;
        return;
      }

      final payload = logs
          .map(
            (log) => {
              'id': log['id']?.toString(),
              'business_id': _businessId,
              'type': log['type'],
              'message': log['message'],
              'meta': log['meta'],
              'created_at':
                  log['createdAt']?.toString() ??
                  DateTime.now().toIso8601String(),
              'sent': (log['sent'] as int? ?? 0) == 1,
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'activityLogs': payload},
      );

      final ids = logs
          .map((log) => int.tryParse(log['id'].toString()) ?? 0)
          .where((id) => id > 0)
          .toList();
      if (ids.isNotEmpty) {
        await db.markActivityLogsSent(ids);
      }

      _syncStats['activity_logs_pushed'] = payload.length;
      debugPrint('✅ Pushed ${payload.length} activity logs');
    } catch (e) {
      debugPrint('❌ Error pushing activity logs: $e');
      rethrow;
    }
  }

  Future<void> _pushProducts() async {
    try {
      final db = DatabaseService();
      final products = await db.getAllProducts();

      if (products.isEmpty) {
        _syncStats['products_pushed'] = 0;
        return;
      }

      final productData = products
          .map(
            (p) => {
              'id': p.id.toString(),
              'business_id': _businessId,
              'name': p.name,
              'barcode': p.barcode,
              'description': p.description,
              'buying_price': p.buyingPrice,
              'category': p.category,
              'selling_price': p.sellingPrice,
              'quantity': p.quantity,
              'image_path': p.imagePath,
              'low_stock_threshold': p.reorderLevel,
              'shoe_sizes': p.shoeSizes != null
                  ? jsonEncode(p.shoeSizes!.map((s) => s.toMap()).toList())
                  : null,
              'size_type': p.sizeType,
              'created_at': p.createdAt.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'products': productData},
      );
      _syncStats['products_pushed'] = products.length;
      debugPrint('✅ Pushed ${products.length} products');
    } catch (e) {
      debugPrint('❌ Error pushing products: $e');
      rethrow;
    }
  }

  Future<void> _pushSales() async {
    try {
      final db = DatabaseService();
      final sales = await db.getAllSales();
      final userService = UserService();
      await userService.initialize();
      final users = userService.users;

      if (sales.isEmpty) {
        _syncStats['sales_pushed'] = 0;
        return;
      }

      final salesData = sales
          .map(
            (s) => {
              // Send sale_number instead of passing a non-numeric 'id'
              'sale_number': s.saleNumber,
              'business_id': _businessId,
              'cashier_id': _resolveCashierId(s.cashierName, users),
              'cashier_name': s.cashierName,
              'customer_name': s.customerName,
              'customer_id': s.customerId,
              'payment_method': s.paymentMethod,
              'status': s.status.toString().split('.').last,
              'subtotal': s.subtotal,
              'discount': s.discountAmount,
              'total_amount': s.totalAmount,
              'amount_paid': s.totalAmount,
              'change_amount': 0.0,
              'item_count': s.itemCount,
              'datetime': s.saleDate.toIso8601String(),
              'notes': s.notes,
              'reference_code': s.referenceCode,
              'image_path': s.imagePath,
              'cancelled_reason': s.cancelledReason,
              'cancelled_by': s.cancelledBy,
              'cancelled_at': s.cancelledAt?.toIso8601String(),
              'transaction_type': s.transactionType.toString().split('.').last,
              'reservation_fee': s.reservationFee,
              'courier': s.courier,
              'delivery_status': s.deliveryStatus?.toString().split('.').last,
              'loyalty_points_earned': s.loyaltyPointsEarned,
              'loyalty_points_redeemed': s.loyaltyPointsRedeemed,
              'created_at': s.saleDate.toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'sales': salesData},
      );
      _syncStats['sales_pushed'] = sales.length;
      debugPrint('✅ Pushed ${sales.length} sales');

      // Push sale items
      await _pushSaleItems(sales);
    } catch (e) {
      debugPrint('❌ Error pushing sales: $e');
      rethrow;
    }
  }

  String _resolveCashierId(String cashierName, List<User> users) {
    final trimmed = cashierName.trim();
    if (trimmed.isNotEmpty) {
      final matched = users.where((u) {
        return u.name.trim().toLowerCase() == trimmed.toLowerCase() ||
            u.email.trim().toLowerCase() == trimmed.toLowerCase();
      }).toList();
      if (matched.isNotEmpty) {
        return matched.first.id;
      }
    }

    final activeUsers = users.where((u) => u.isActive).toList();
    if (activeUsers.isNotEmpty) {
      final cashiers = activeUsers.where((u) => u.role == UserRole.cashier).toList();
      if (cashiers.isNotEmpty) return cashiers.first.id;
      return activeUsers.first.id;
    }

    return users.isNotEmpty ? users.first.id : 'cashier-1';
  }

  Future<void> _pushSaleItems(List<Sale> sales) async {
    try {
      final allItems = <Map<String, dynamic>>[];

      for (final sale in sales) {
        for (final item in sale.items) {
          allItems.add({
            // Reference sale by its sale_number to allow server mapping
            'sale_number': sale.saleNumber,
            'business_id': _businessId,
            'product_id': item.productId.toString(),
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'discount': item.discount,
            'subtotal': item.subtotal,
            'shoe_size': item.shoeSize,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (allItems.isNotEmpty) {
        await _api.postJson(
          'sync/push',
          body: {'businessId': _businessId, 'saleItems': allItems},
        );
        _syncStats['sale_items_pushed'] = allItems.length;
        debugPrint('✅ Pushed ${allItems.length} sale items');
      }
    } catch (e) {
      debugPrint('❌ Error pushing sale items: $e');
      rethrow;
    }
  }

  Future<void> _pushInventoryMovements() async {
    try {
      final db = DatabaseService();
      // Get movements via getAllMovementsByDateRange with wide date range
      final startDate = DateTime(2020, 1, 1);
      final endDate = DateTime.now().add(const Duration(days: 365));
      final movements = await db.getAllMovementsByDateRange(startDate, endDate);

      if (movements.isEmpty) {
        _syncStats['inventory_movements_pushed'] = 0;
        return;
      }

      final movementData = movements
          .map(
            (m) => {
              'id': m.id.toString(),
              'business_id': _businessId,
              'product_id': m.productId.toString(),
              'product_name': '', // Not available in local model
              'movement_type': m.movementType,
              'quantity': m.quantityChanged,
              'reference': m.reference,
              'notes': m.reason,
              'performed_by': 'system', // userId not in local model
              'timestamp': m.movementDate.toIso8601String(),
              'created_at': m.movementDate.toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'inventoryMovements': movementData},
      );
      _syncStats['inventory_movements_pushed'] = movements.length;
      debugPrint('✅ Pushed ${movements.length} inventory movements');
    } catch (e) {
      debugPrint('❌ Error pushing inventory movements: $e');
      rethrow;
    }
  }

  Future<void> _pushSuppliers() async {
    try {
      final db = DatabaseService();
      final suppliers = await db.getAllSuppliers();

      if (suppliers.isEmpty) {
        _syncStats['suppliers_pushed'] = 0;
        return;
      }

      final supplierData = suppliers
          .map(
            (s) => {
              'id': s.id.toString(),
              'business_id': _businessId,
              'name': s.name,
              'contact_person': s.contactPerson,
              'email': s.email,
              'phone': s.phone,
              'address': s.address,
              'notes': s.notes,
              'is_active': s.isActive,
              'created_at': s.createdAt.toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'suppliers': supplierData},
      );
      _syncStats['suppliers_pushed'] = suppliers.length;
      debugPrint('✅ Pushed ${suppliers.length} suppliers');
    } catch (e) {
      debugPrint('❌ Error pushing suppliers: $e');
      rethrow;
    }
  }

  Future<void> _pushPurchaseOrders() async {
    try {
      final db = DatabaseService();
      final orders = await db.getAllPurchaseOrders();

      if (orders.isEmpty) {
        _syncStats['purchase_orders_pushed'] = 0;
        return;
      }

      final orderData = orders
          .map(
            (o) => {
              'id': o.id.toString(),
              'business_id': _businessId,
              'supplier_id': o.supplierId.toString(),
              'order_number': o.orderNumber,
              'order_date': o.orderDate.toIso8601String(),
              'expected_delivery': o.expectedDeliveryDate?.toIso8601String(),
              'status': o.status,
              'total_amount': o.totalAmount,
              'notes': o.notes,
              'created_by': o.approvedBy ?? 'system',
              'created_at': o.orderDate.toIso8601String(),
            },
          )
          .toList();

      final orderItems = <Map<String, dynamic>>[];
      for (final order in orders) {
        final orderId = order.id;
        if (orderId == null) continue;
        for (final item in order.items) {
          orderItems.add({
            'id': item.id?.toString(),
            'business_id': _businessId,
            'purchase_order_id': orderId.toString(),
            'order_id': orderId.toString(),
            'product_id': item.productId.toString(),
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total_price': item.totalPrice,
          });
        }
      }

      await _api.postJson(
        'sync/push',
        body: {
          'businessId': _businessId,
          'purchaseOrders': orderData,
          'purchaseOrderItems': orderItems,
        },
      );
      _syncStats['purchase_orders_pushed'] = orders.length;
      _syncStats['purchase_order_items_pushed'] = orderItems.length;
      debugPrint('✅ Pushed ${orders.length} purchase orders');
      debugPrint('✅ Pushed ${orderItems.length} purchase order items');
    } catch (e) {
      debugPrint('❌ Error pushing purchase orders: $e');
      rethrow;
    }
  }

  Future<void> _pushDamageReports() async {
    try {
      final db = DatabaseService();
      // Get damage reports via date range query
      final startDate = DateTime(2020, 1, 1);
      final endDate = DateTime.now().add(const Duration(days: 365));
      final reports = await db.getDamageReportsByDateRange(startDate, endDate);

      if (reports.isEmpty) {
        _syncStats['damage_reports_pushed'] = 0;
        return;
      }

      final reportData = reports
          .map(
            (r) => {
              'id': r.id.toString(),
              'business_id': _businessId,
              'product_id': r.productId.toString(),
              'product_name': r.productName,
              'quantity': r.quantity,
              'damage_type': r.reason,
              'description': r.reason,
              'reported_by': r.reportedBy,
              'reported_at': r.reportDate.toIso8601String(),
              'status': r.returnStatus ?? 'pending',
              'resolution_notes': r.responsiblePerson,
              'created_at': r.reportDate.toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'damageReports': reportData},
      );
      _syncStats['damage_reports_pushed'] = reports.length;
      debugPrint('✅ Pushed ${reports.length} damage reports');
    } catch (e) {
      debugPrint('❌ Error pushing damage reports: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PULL METHODS (Cloud → Local)
  // ============================================================================

  Future<void> _pullUsers(Map<String, dynamic> payload) async {
    try {
      final response = payload['users'] is List
          ? List<Map<String, dynamic>>.from(payload['users'] as List)
          : <Map<String, dynamic>>[];

      final users = response.map((data) {
        return User(
          id: data['id']?.toString() ?? '',
          name: data['full_name']?.toString() ?? '',
          email: data['email']?.toString() ?? '',
          password: data['password_hash']?.toString() ?? '',
          pin: null,
          contactNumber: data['contact_number']?.toString(),
          role: UserRole.values.firstWhere(
            (role) =>
                role.toString().split('.').last ==
                data['role']?.toString().toLowerCase(),
            orElse: () => UserRole.cashier,
          ),
          businessId: data['business_id']?.toString(),
          createdAt: _asDateTime(data['created_at']),
          isActive: _asBool(data['is_active']),
          authMethod: data['auth_method']?.toString() ?? 'password',
        );
      }).toList();

      final userService = UserService();
      await userService.clearAllUsers(queueCloudSync: false);
      for (final user in users) {
        await userService.addUser(user, queueCloudSync: false);
      }

      _syncStats['users_pulled'] = users.length;
      debugPrint('✅ Pulled ${users.length} users');
    } catch (e) {
      debugPrint('❌ Error pulling users: $e');
      rethrow;
    }
  }

  Future<void> _pullCustomers(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = payload['customers'] is List
          ? List<Map<String, dynamic>>.from(payload['customers'] as List)
          : <Map<String, dynamic>>[];

      final customers = response.map((data) {
        return Customer(
          id: _asInt(data['id']),
          customerCode: data['customer_code']?.toString() ?? '',
          fullName: data['full_name']?.toString() ?? '',
          phoneNumber: data['phone_number']?.toString(),
          email: data['email']?.toString(),
          address: data['address']?.toString(),
          pointsBalance: _asInt(data['points_balance']),
          lifetimePoints: _asInt(data['lifetime_points']),
          barcodeValue: data['barcode_value']?.toString() ?? '',
          createdAt: _asDateTime(data['created_at']),
          updatedAt: _asDateTime(data['updated_at']),
          isActive: _asBool(data['is_active']),
        );
      }).toList();

      for (final customer in customers) {
        await db.insertOrUpdateCustomer(customer);
      }

      _syncStats['customers_pulled'] = customers.length;
      debugPrint('✅ Pulled ${customers.length} customers');
    } catch (e) {
      debugPrint('❌ Error pulling customers: $e');
      rethrow;
    }
  }

  Future<void> _pullLoyaltyLedger(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = payload['loyaltyLedger'] is List
          ? List<Map<String, dynamic>>.from(payload['loyaltyLedger'] as List)
          : <Map<String, dynamic>>[];

      final entries = response
          .map(
            (data) => <String, dynamic>{
              'id': _asInt(data['id']),
              'customerId': _asInt(data['customer_id']),
              'saleId': data['sale_id'] == null
                  ? null
                  : _asInt(data['sale_id']),
              'entryType': data['entry_type']?.toString() ?? 'earn',
              'points': _asInt(data['points']),
              'balanceAfter': _asInt(data['balance_after']),
              'notes': data['notes']?.toString(),
              'createdAt': _asDateTime(data['created_at']).toIso8601String(),
            },
          )
          .toList();

      await db.replaceLoyaltyLedgerEntries(entries);
      _syncStats['loyalty_ledger_pulled'] = entries.length;
      debugPrint('✅ Pulled ${entries.length} loyalty ledger entries');
    } catch (e) {
      debugPrint('❌ Error pulling loyalty ledger: $e');
      rethrow;
    }
  }

  Future<void> _pullCameras(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = payload['cameras'] is List
          ? List<Map<String, dynamic>>.from(payload['cameras'] as List)
          : <Map<String, dynamic>>[];

      final existing = await db.getAllCameras();
      final existingIds = existing
          .map((camera) => camera['id'])
          .whereType<int>()
          .toSet();
      final incomingIds = <int>{};

      for (final data in response) {
        final rawId = data['id'];
        final id = rawId == null ? null : _asInt(rawId);
        final cameraMap = {
          'id': id,
          'name': data['name']?.toString() ?? '',
          'url': data['stream_url']?.toString() ?? '',
          'type': data['type']?.toString() ?? 'http',
          'position': _asInt(data['position']),
          'isActive': _asBool(data['is_active']) ? 1 : 0,
          'createdAt': _asDateTime(data['created_at']).toIso8601String(),
          'username': data['username']?.toString(),
          'password': data['password']?.toString(),
        };

        if (id != null) {
          incomingIds.add(id);
          final existingCamera = await db.getCameraById(id);
          if (existingCamera == null) {
            await db.insertCamera(cameraMap);
          } else {
            await db.updateCamera(id, cameraMap);
          }
        } else {
          await db.insertCamera(cameraMap);
        }
      }

      for (final id in existingIds.difference(incomingIds)) {
        await db.deleteCamera(id);
      }

      _syncStats['cameras_pulled'] = response.length;
      debugPrint('✅ Pulled ${response.length} cameras');
    } catch (e) {
      debugPrint('❌ Error pulling cameras: $e');
      rethrow;
    }
  }

  Future<void> _pullCctvTimestamps(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = payload['cctvTimestamps'] is List
          ? List<Map<String, dynamic>>.from(payload['cctvTimestamps'] as List)
          : <Map<String, dynamic>>[];

      await db.deleteAllCCTVTimestamps();
      for (final data in response) {
        await db.insertCCTVTimestamp({
          'id': _asInt(data['id']),
          'timestamp': _asDateTime(data['timestamp']).toIso8601String(),
          'description': data['description']?.toString() ?? data['label']?.toString(),
          'videoPath': data['video_path']?.toString(),
          'createdAt': _asDateTime(data['created_at']).toIso8601String(),
        });
      }

      _syncStats['cctv_timestamps_pulled'] = response.length;
      debugPrint('✅ Pulled ${response.length} CCTV timestamps');
    } catch (e) {
      debugPrint('❌ Error pulling CCTV timestamps: $e');
      rethrow;
    }
  }

  Future<void> _pullAttendance(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final entriesResponse = payload['attendanceEntries'] is List
          ? List<Map<String, dynamic>>.from(
              payload['attendanceEntries'] as List,
            )
          : <Map<String, dynamic>>[];
      final leavesResponse = payload['attendanceLeaves'] is List
          ? List<Map<String, dynamic>>.from(payload['attendanceLeaves'] as List)
          : <Map<String, dynamic>>[];
      final archiveResponse = payload['attendanceArchive'] is List
          ? List<Map<String, dynamic>>.from(payload['attendanceArchive'] as List)
          : <Map<String, dynamic>>[];
      final scheduleResponse = payload['attendanceSchedule'];

      final groupedEntries = <String, List<AttendanceEntry>>{};
      for (final data in entriesResponse) {
        final userId = data['user_id']?.toString() ?? '';
        if (userId.isEmpty) continue;
        final entry = AttendanceEntry(
          time: _asDateTime(data['time']),
          type: data['type']?.toString() ?? 'IN',
        );
        groupedEntries.putIfAbsent(userId, () => <AttendanceEntry>[]).add(entry);
      }

      for (final entry in groupedEntries.entries) {
        await AttendanceService.instance.replaceEntries(entry.key, entry.value);
      }

      final leavesByUser = <String, Map<String, dynamic>>{};
      for (final data in leavesResponse) {
        final userId = data['user_id']?.toString() ?? '';
        final dateKey = data['date_key']?.toString() ?? '';
        if (userId.isEmpty || dateKey.isEmpty) continue;
        leavesByUser.putIfAbsent(userId, () => <String, dynamic>{});
        final payloadValue = data['payload'];
        leavesByUser[userId]![dateKey] = payloadValue is String
            ? (jsonDecode(payloadValue) as Map<String, dynamic>)
            : Map<String, dynamic>.from(payloadValue as Map);
      }

      for (final entry in leavesByUser.entries) {
        for (final leave in entry.value.entries) {
          await AttendanceService.instance.saveLeave(
            entry.key,
            leave.key,
            leave.value,
          );
        }
      }

      final archivesByUser = <String, Map<String, List<AttendanceEntry>>>{};
      for (final data in archiveResponse) {
        final userId = data['user_id']?.toString() ?? '';
        final dateKey = data['date_key']?.toString() ?? '';
        if (userId.isEmpty || dateKey.isEmpty) continue;
        final rawEntries = data['entries'];
        final decodedEntries = <AttendanceEntry>[];
        if (rawEntries is String && rawEntries.isNotEmpty) {
          try {
            final list = jsonDecode(rawEntries) as List<dynamic>;
            decodedEntries.addAll(
              list.map(
                (e) => AttendanceEntry.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              ),
            );
          } catch (_) {}
        } else if (rawEntries is List) {
          decodedEntries.addAll(
            rawEntries
                .map(
                  (e) => AttendanceEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(),
          );
        }
        archivesByUser.putIfAbsent(userId, () => <String, List<AttendanceEntry>>{});
        archivesByUser[userId]![dateKey] = decodedEntries;
      }

      final userService = UserService();
      await userService.initialize();
      for (final user in userService.users) {
        await AttendanceService.instance.replaceArchive(
          user.id,
          archivesByUser[user.id] ?? <String, List<AttendanceEntry>>{},
        );
      }

      if (scheduleResponse != null) {
        Map<String, dynamic>? schedule;
        if (scheduleResponse is Map<String, dynamic>) {
          final value = scheduleResponse['value'];
          if (value is String && value.isNotEmpty) {
            try {
              schedule = Map<String, dynamic>.from(jsonDecode(value) as Map);
            } catch (_) {
              schedule = null;
            }
          } else if (value is Map) {
            schedule = Map<String, dynamic>.from(value);
          }
        } else if (scheduleResponse is List && scheduleResponse.isNotEmpty) {
          final first = scheduleResponse.first;
          if (first is Map) {
            final value = first['value'];
            if (value is String && value.isNotEmpty) {
              try {
                schedule = Map<String, dynamic>.from(jsonDecode(value) as Map);
              } catch (_) {
                schedule = null;
              }
            } else if (value is Map) {
              schedule = Map<String, dynamic>.from(value);
            }
          }
        }

        if (schedule != null) {
          await AttendanceService.instance.saveSchedule(schedule);
        }
      }

      _syncStats['attendance_entries_pulled'] = entriesResponse.length;
      _syncStats['attendance_leaves_pulled'] = leavesResponse.length;
      _syncStats['attendance_archive_pulled'] = archiveResponse.length;
      _syncStats['attendance_schedule_pulled'] = scheduleResponse == null ? 0 : 1;
      debugPrint(
        '✅ Pulled ${entriesResponse.length} attendance entries and ${leavesResponse.length} leaves',
      );
    } catch (e) {
      debugPrint('❌ Error pulling attendance data: $e');
      rethrow;
    }
  }

  Future<void> _pullActivityLogs(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = payload['activityLogs'] is List
          ? List<Map<String, dynamic>>.from(payload['activityLogs'] as List)
          : <Map<String, dynamic>>[];

      final logs = response
          .map(
            (data) => <String, dynamic>{
              'id': _asInt(data['id']),
              'type': data['type']?.toString() ?? '',
              'message': data['message']?.toString() ?? '',
              'meta': data['meta']?.toString(),
              'createdAt': _asDateTime(data['created_at']).toIso8601String(),
              'sent': (() {
                final sent = data['sent'];
                if (sent == true) return 1;
                if (sent is num && sent.toInt() == 1) return 1;
                return 0;
              })(),
            },
          )
          .toList();

      await db.replaceActivityLogs(logs);
      _syncStats['activity_logs_pulled'] = logs.length;
      debugPrint('✅ Pulled ${logs.length} activity logs');
    } catch (e) {
      debugPrint('❌ Error pulling activity logs: $e');
      rethrow;
    }
  }

  Future<void> _pullProducts(DatabaseService db, Map<String, dynamic> payload) async {
    try {
      final response = payload['products'] is List
          ? List<Map<String, dynamic>>.from(payload['products'] as List)
          : <Map<String, dynamic>>[];

      final products = response.map((data) {
        return Product(
          id: _asInt(data['id']),
          barcode: data['barcode'] ?? '',
          name: data['name'],
          description: data['description']?.toString(),
          buyingPrice: _asDouble(data['buying_price']),
          sellingPrice: _asDouble(data['selling_price']),
          quantity: _asInt(data['quantity']),
          reorderLevel: _asInt(data['low_stock_threshold'], fallback: 5),
          category: data['category'] ?? 'General',
          imagePath: data['image_path'],
          createdAt: _asDateTime(data['created_at']),
          shoeSizes: _parseShoeSizes(data['shoe_sizes']),
          sizeType: data['size_type']?.toString(),
        );
      }).toList();

      // Clear and re-insert (simple sync strategy)
      for (final product in products) {
        await db.insertOrUpdateProduct(product);
      }

      _syncStats['products_pulled'] = products.length;
      debugPrint('✅ Pulled ${products.length} products');
    } catch (e) {
      debugPrint('❌ Error pulling products: $e');
      rethrow;
    }
  }

  Future<void> _pullSales(DatabaseService db, Map<String, dynamic> payload) async {
    try {
      final response = payload['sales'] is List
          ? List<Map<String, dynamic>>.from(payload['sales'] as List)
          : <Map<String, dynamic>>[];
      final saleItems = payload['saleItems'] is List
          ? List<Map<String, dynamic>>.from(payload['saleItems'] as List)
          : <Map<String, dynamic>>[];

      final itemsBySale = <String, List<Map<String, dynamic>>>{};
      for (final item in saleItems) {
        final saleId = item['sale_id']?.toString() ?? '';
        itemsBySale.putIfAbsent(saleId, () => []).add(item);
      }

      final sales = response.map((data) {
        final cloudSaleId = data['id']?.toString() ?? '';
        final saleNumber = data['sale_number']?.toString() ??
            data['saleNumber']?.toString() ??
            cloudSaleId;
        final items = (itemsBySale[cloudSaleId] ?? []).map((itemData) {
          final unitPrice = _asDouble(itemData['unit_price']);
          final quantity = _asInt(itemData['quantity']);
          final discount = _asDouble(itemData['discount']);
          return SaleItem(
            id: null,
            saleId: 0,
            productId: _asInt(itemData['product_id']),
            productName: itemData['product_name'],
            quantity: quantity,
            unitPrice: unitPrice,
            discount: discount,
            subtotal: unitPrice * quantity,
            shoeSize: itemData['shoe_size']?.toString(),
          );
        }).toList();

        return Sale(
          id: null,
          saleNumber: saleNumber,
          items: items,
          subtotal: _asDouble(data['subtotal']),
          discountAmount: _asDouble(data['discount']),
          taxAmount: 0.0,
          totalAmount: _asDouble(data['total_amount']),
          paymentMethod: data['payment_method'],
          status: _parseSaleStatus(data['status']),
          notes: data['notes'],
          cashierName: data['cashier_name'],
          saleDate: _asDateTime(data['datetime']),
          referenceCode: data['reference_code']?.toString(),
          imagePath: data['image_path']?.toString(),
          cancelledReason: data['cancelled_reason']?.toString(),
          cancelledBy: data['cancelled_by']?.toString(),
          cancelledAt: data['cancelled_at'] == null
              ? null
              : _asDateTime(data['cancelled_at']),
          transactionType: data['transaction_type']?.toString() == 'delivery'
              ? TransactionType.delivery
              : TransactionType.pos,
          reservationFee: _asDouble(data['reservation_fee'], fallback: 0.0),
          courier: data['courier']?.toString(),
          deliveryStatus: data['delivery_status'] == null
              ? null
              : DeliveryStatus.values.firstWhere(
                  (e) =>
                      e.toString().split('.').last ==
                      data['delivery_status'].toString(),
                  orElse: () => DeliveryStatus.pending,
                ),
          customerId: _asInt(data['customer_id'], fallback: 0) == 0
              ? null
              : _asInt(data['customer_id']),
          customerName: data['customer_name']?.toString(),
          loyaltyPointsEarned: _asInt(data['loyalty_points_earned']),
          loyaltyPointsRedeemed: _asInt(data['loyalty_points_redeemed']),
        );
      }).toList();

      for (final sale in sales) {
        await db.insertOrUpdateSale(sale);
      }

      _syncStats['sales_pulled'] = sales.length;
      debugPrint('✅ Pulled ${sales.length} sales');
    } catch (e) {
      debugPrint('❌ Error pulling sales: $e');
      rethrow;
    }
  }

  Future<void> _pullInventoryMovements(DatabaseService db, Map<String, dynamic> payload) async {
    try {
      final response = payload['inventoryMovements'] is List
          ? List<Map<String, dynamic>>.from(payload['inventoryMovements'] as List)
          : <Map<String, dynamic>>[];

      final movements = response
          .map(
            (data) => <String, dynamic>{
              'id': _asInt(data['id']),
              'productId': _asInt(data['product_id']),
              // The backend stores the reduced cloud payload, so the exact
              // before/after quantities cannot be reconstructed here.
              'quantityBefore': 0,
              'quantityAfter': _asInt(data['quantity']),
              'quantityChanged': _asInt(data['quantity']),
              'movementType': data['movement_type']?.toString() ?? '',
              'reference': data['reference']?.toString() ?? '',
              'reason': data['notes']?.toString() ?? '',
              'movementDate': _asDateTime(data['timestamp']).toIso8601String(),
            },
          )
          .toList();

      await db.replaceInventoryMovements(movements);
      _syncStats['inventory_movements_pulled'] = response.length;
      debugPrint('✅ Pulled ${response.length} inventory movements');
    } catch (e) {
      debugPrint('❌ Error pulling inventory movements: $e');
      // Don't rethrow - continue with other syncs
    }
  }

  Future<void> _pullSuppliers(DatabaseService db, Map<String, dynamic> payload) async {
    try {
      final response = payload['suppliers'] is List
          ? List<Map<String, dynamic>>.from(payload['suppliers'] as List)
          : <Map<String, dynamic>>[];

      final suppliers = response.map((data) {
        return Supplier(
          id: _asInt(data['id']),
          name: data['name'],
          contactPerson: data['contact_person'] ?? '',
          phone: data['phone'] ?? '',
          email: data['email'] ?? '',
          address: data['address'] ?? '',
          notes: data['notes'] ?? '',
          isActive: _asBool(data['is_active']),
          createdAt: _asDateTime(data['created_at']),
        );
      }).toList();

      for (final supplier in suppliers) {
        await db.insertOrUpdateSupplier(supplier);
      }

      _syncStats['suppliers_pulled'] = suppliers.length;
      debugPrint('✅ Pulled ${suppliers.length} suppliers');
    } catch (e) {
      debugPrint('❌ Error pulling suppliers: $e');
      rethrow;
    }
  }

  Future<void> _pullPurchaseOrders(DatabaseService db, Map<String, dynamic> payload) async {
    try {
      final response = payload['purchaseOrders'] is List
          ? List<Map<String, dynamic>>.from(payload['purchaseOrders'] as List)
          : <Map<String, dynamic>>[];
      final responseItems = payload['purchaseOrderItems'] is List
          ? List<Map<String, dynamic>>.from(payload['purchaseOrderItems'] as List)
          : <Map<String, dynamic>>[];

      final itemsByOrder = <String, List<Map<String, dynamic>>>{};
      for (final item in responseItems) {
        final orderId = item['purchase_order_id']?.toString() ?? 
            item['order_id']?.toString() ??
            '';
        itemsByOrder.putIfAbsent(orderId, () => []).add(item);
      }

      final orders = <PurchaseOrder>[];
      for (final data in response) {
        final cloudOrderKey = data['id']?.toString() ?? '';
        final orderNumber = data['order_number']?.toString() ??
            data['orderNumber']?.toString() ??
            cloudOrderKey;
        final itemMaps = itemsByOrder[cloudOrderKey] ?? const [];
        final items = itemMaps.map((itemData) {
          final quantity = _asInt(itemData['quantity']);
          final unitPrice = _asDouble(itemData['unit_price']);
          return PurchaseOrderItem(
            id: _asInt(itemData['id']) == 0 ? null : _asInt(itemData['id']),
            orderId: 0,
            productId: _asInt(itemData['product_id']),
            productName: itemData['product_name']?.toString() ?? '',
            quantity: quantity,
            unitPrice: unitPrice,
            totalPrice: _asDouble(
              itemData['total_price'],
              fallback: unitPrice * quantity,
            ),
          );
        }).toList();

        final supplierId = _asInt(data['supplier_id']);
        var supplierName = data['supplier_name']?.toString() ?? '';
        if (supplierName.isEmpty && supplierId > 0) {
          final supplier = await db.getSupplierById(supplierId);
          supplierName = supplier?.name ?? '';
        }

        orders.add(
          PurchaseOrder(
            id: null,
            orderNumber: orderNumber,
            supplierId: supplierId,
            supplierName: supplierName,
            orderDate: _asDateTime(data['order_date']),
            expectedDeliveryDate: data['expected_delivery'] == null
                ? null
                : _asDateTime(data['expected_delivery']),
            status: data['status']?.toString() ?? 'pending',
            items: items,
            totalAmount: _asDouble(data['total_amount']),
            notes: data['notes']?.toString() ?? '',
            approvedBy: data['approved_by']?.toString(),
            signatureData:
                data['signatureData']?.toString() ??
                data['signature_data']?.toString(),
            approvalDate: data['approval_date'] == null
                ? null
                : _asDateTime(data['approval_date']),
          ),
        );
      }

      for (final order in orders) {
        await db.insertOrUpdatePurchaseOrder(order);
      }

      _syncStats['purchase_orders_pulled'] = orders.length;
      _syncStats['purchase_order_items_pulled'] = responseItems.length;
      debugPrint('✅ Pulled ${orders.length} purchase orders');
      debugPrint('✅ Pulled ${responseItems.length} purchase order items');
    } catch (e) {
      debugPrint('❌ Error pulling purchase orders: $e');
      // Don't rethrow - continue with other syncs
    }
  }

  Future<void> _pullDamageReports(DatabaseService db, Map<String, dynamic> payload) async {
    try {
      final response = payload['damageReports'] is List
          ? List<Map<String, dynamic>>.from(payload['damageReports'] as List)
          : <Map<String, dynamic>>[];

      final reports = response.map((data) {
        final quantity = _asInt(data['quantity']);
        final unitPrice = 0.0; // Not stored in cloud, would need product lookup
        final status = data['status']?.toString();
        return DamageReport(
          id: _asInt(data['id']),
          productId: _asInt(data['product_id']),
          productName: data['product_name'],
          quantity: quantity,
          unitPrice: unitPrice,
          totalValue: unitPrice * quantity,
          reason: data['damage_type']?.toString() ??
              data['description']?.toString() ??
              'unknown',
          reportedBy: data['reported_by']?.toString() ?? 'unknown',
          reportDate: _asDateTime(data['reported_at']),
          returnStatus: status,
          responsiblePerson: data['resolution_notes']?.toString(),
        );
      }).toList();

      for (final report in reports) {
        await db.insertDamageReport(report);
      }

      _syncStats['damage_reports_pulled'] = reports.length;
      debugPrint('✅ Pulled ${reports.length} damage reports');
    } catch (e) {
      debugPrint('❌ Error pulling damage reports: $e');
      rethrow;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value.toInt() != 0;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return fallback;
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? (fallback ?? DateTime.now());
  }

  SaleStatus _parseSaleStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return SaleStatus.completed;
      case 'pending':
        return SaleStatus.pending;
      case 'cancelled':
        return SaleStatus.cancelled;
      case 'returned':
        return SaleStatus.returned;
      default:
        return SaleStatus.completed;
    }
  }

  List<ShoeSize> _parseShoeSizes(dynamic value) {
    if (value == null) return const <ShoeSize>[];
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      if (decoded is! List) return const <ShoeSize>[];
      return decoded
          .map((entry) => ShoeSize.fromMap(Map<String, dynamic>.from(entry as Map)))
          .toList();
    } catch (_) {
      return const <ShoeSize>[];
    }
  }

  /// Clear business context (call on logout)
  void clearBusinessContext() {
    stopAutoSync();
    _queuedPushTimer?.cancel();
    _queuedPushTimer = null;
    _businessId = null;
    _lastError = null;
    _syncStats.clear();
    notifyListeners();
  }

  /// Get sync summary for display
  String getSyncSummary() {
    if (_syncStats.isEmpty) return 'No sync performed yet';

    final parts = <String>[];
    _syncStats.forEach((key, value) {
      parts.add('$key: $value');
    });

    return parts.join(', ');
  }
}
