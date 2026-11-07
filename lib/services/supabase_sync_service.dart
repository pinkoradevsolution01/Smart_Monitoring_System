import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/product.dart';
import '../models/shoe_size.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/purchase_order.dart';
import '../models/supplier.dart';
import '../models/restock_record.dart';
import '../models/damage_report.dart';
import '../models/customer.dart';
import '../models/user.dart';
import 'database_service.dart';
import 'demo_session_service.dart';
import 'backend_api_service.dart';
import 'backend_config.dart';
import 'attendance_service.dart';
import 'user_service.dart';
import 'package_service.dart';
import 'business_info_service.dart';

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
  Timer? _initialCloudRestoreTimer;
  bool _autoSyncEnabled = true;
  // A full restore touches every local module table. Running it every 30
  // seconds competes with screen queries and SQLite writes, which makes the
  // app appear to freeze on devices with real sales and purchase-order data.
  // Local changes still use the short queued upload below; this cadence only
  // controls cloud-to-device refreshes from other devices.
  // A full pull currently contains all tenant records. Keep this deliberately
  // conservative so background refreshes do not repeatedly contend with POS
  // and inventory SQLite reads on mobile devices.
  Duration _autoSyncInterval = const Duration(minutes: 5);
  // Multiple local writes (such as a POS checkout) are collapsed into one
  // upload instead of starting an upload for every individual write.
  Duration _queuedPushDelay = const Duration(seconds: 5);
  int _retryAttempts = 0;
  DateTime? _nextRetryAt;
  int _activeExternalDatabaseReads = 0;
  Completer<void>? _externalReadsDrained;
  Completer<void>? _syncIdle;
  Future<bool>? _restoreInFlight;
  Future<void>? _initialCloudRestoreInFlight;
  bool _initialCloudRestoreVerified = false;
  bool _pendingLocalPush = false;

  // Getters
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  Map<String, int> get syncStats => _syncStats;
  String? get businessId => _businessId;

  /// Demonstration sessions must never pull production records or push data.
  bool get isConfigured =>
      !DemoSessionService.instance.isActive &&
      BackendConfig.useRestBackend &&
      _businessId != null;
  bool get isAutoSyncEnabled => _autoSyncEnabled;
  Duration get autoSyncInterval => _autoSyncInterval;
  Duration get queuedPushDelay => _queuedPushDelay;
  int get retryAttempts => _retryAttempts;
  DateTime? get nextRetryAt => _nextRetryAt;

  /// Runs a read-only local-data task without overlapping a cloud restore or
  /// backup. The small gate closes the race between checking [isSyncing] and
  /// SQLite beginning a sync transaction.
  Future<T> readLocalDataSafely<T>(Future<T> Function() action) async {
    while (_isSyncing) {
      final idle = _syncIdle;
      if (idle == null) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      } else {
        await idle.future;
      }
    }
    _activeExternalDatabaseReads += 1;
    try {
      return await action();
    } finally {
      _activeExternalDatabaseReads -= 1;
      if (_activeExternalDatabaseReads == 0 &&
          _externalReadsDrained != null &&
          !_externalReadsDrained!.isCompleted) {
        _externalReadsDrained!.complete();
        _externalReadsDrained = null;
      }
    }
  }

  Future<void> _beginSync() async {
    _isSyncing = true;
    _syncIdle = Completer<void>();
    notifyListeners();
    if (_activeExternalDatabaseReads > 0) {
      _externalReadsDrained ??= Completer<void>();
      await _externalReadsDrained!.future;
    }
  }

  void _finishSync() {
    _isSyncing = false;
    final idle = _syncIdle;
    _syncIdle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }

  String get _syncStateKey => 'sync_state_${_businessId ?? 'unassigned'}';

  Future<void> _restoreSyncState() async {
    final raw = (await SharedPreferences.getInstance()).getString(
      _syncStateKey,
    );
    if (raw == null) return;
    try {
      final state = jsonDecode(raw) as Map<String, dynamic>;
      _lastSyncTime = DateTime.tryParse(
        state['lastSyncTime']?.toString() ?? '',
      );
      _retryAttempts = (state['retryAttempts'] as num?)?.toInt() ?? 0;
      _nextRetryAt = DateTime.tryParse(state['nextRetryAt']?.toString() ?? '');
    } catch (_) {}
  }

  Future<void> _saveSyncState() async {
    await (await SharedPreferences.getInstance()).setString(
      _syncStateKey,
      jsonEncode({
        'lastSyncTime': _lastSyncTime?.toIso8601String(),
        'retryAttempts': _retryAttempts,
        'nextRetryAt': _nextRetryAt?.toIso8601String(),
      }),
    );
  }

  Future<void> _scheduleRetry() async {
    _retryAttempts = (_retryAttempts + 1).clamp(1, 8);
    final seconds = (5 * (1 << (_retryAttempts - 1))).clamp(5, 300);
    _nextRetryAt = DateTime.now().add(Duration(seconds: seconds));
    await _saveSyncState();
    _queuedPushTimer?.cancel();
    _queuedPushTimer = Timer(
      Duration(seconds: seconds),
      () => queuePushAllData(delay: Duration.zero),
    );
    notifyListeners();
  }

  Future<void> _recordSyncSuccess() async {
    _lastSyncTime = DateTime.now();
    _retryAttempts = 0;
    _nextRetryAt = null;
    await _saveSyncState();
  }

  /// Initialize business context (call this after license activation)
  Future<void> initializeBusiness({
    required String businessName,
    required String ownerEmail,
    String? existingBusinessId,
  }) async {
    if (DemoSessionService.instance.isActive) {
      throw StateError('Cloud synchronization is disabled during demo mode.');
    }
    if (!BackendConfig.useRestBackend) {
      throw Exception('Backend not configured');
    }

    try {
      // Always ask the backend for the canonical tenant. A cached ID can
      // belong to an account previously used on this device.
      final response = await _api.postJson(
        'business/init',
        body: {
          'businessName': businessName,
          'ownerEmail': ownerEmail,
          'existingBusinessId': existingBusinessId,
        },
      );
      if (response is Map<String, dynamic>) {
        final resolvedBusinessId = response['businessId']?.toString();
        if (resolvedBusinessId == null || resolvedBusinessId.isEmpty) {
          throw Exception('Backend did not return a business ID.');
        }
        if (_businessId != null && _businessId != resolvedBusinessId) {
          stopAutoSync();
          _initialCloudRestoreVerified = false;
          _pendingLocalPush = false;
          debugPrint(
            'Replaced stale sync business context with $resolvedBusinessId',
          );
        }
        _businessId = resolvedBusinessId;
        await _restoreSyncState();
        final token = response['token']?.toString();
        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('backend_access_token', token);
        }
        await _restoreVerifiedOwnerSetup(response);
      }

      debugPrint('✅ Business initialized: $_businessId');
      startAutoSync();
      // A complete cloud restore can take several seconds on a business with
      // sales history. Do not make Google sign-in or the splash screen wait
      // for it. The dashboard can use its local database immediately while
      // one verified restore runs in the background.
      _scheduleInitialCloudRestore();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing business: $e');
      _lastError = e.toString();
      rethrow;
    }
  }

  /// Starts exactly one non-blocking initial restore for the active business.
  /// It intentionally does not queue a full upload afterwards: routine local
  /// changes already schedule their own debounced upload, while a full upload
  /// on every app launch is both slow and unnecessary.
  void _startInitialCloudRestore() {
    final running = _initialCloudRestoreInFlight;
    if (running != null) return;

    final restore = _restoreCloudDataInBackground();
    _initialCloudRestoreInFlight = restore;
    unawaited(
      restore.whenComplete(() {
        if (identical(_initialCloudRestoreInFlight, restore)) {
          _initialCloudRestoreInFlight = null;
        }
      }),
    );
  }

  /// Give the first dashboard frame and its local SQLite queries a chance to
  /// complete before beginning a large restore. This avoids a visible freeze
  /// immediately after sign-in while still refreshing the cloud state soon.
  void _scheduleInitialCloudRestore() {
    if (_initialCloudRestoreInFlight != null ||
        _initialCloudRestoreTimer?.isActive == true) {
      return;
    }
    _initialCloudRestoreTimer = Timer(const Duration(seconds: 2), () {
      _initialCloudRestoreTimer = null;
      _startInitialCloudRestore();
    });
  }

  Future<void> _restoreCloudDataInBackground() async {
    final restored = await pullAllData();
    if (restored) {
      _initialCloudRestoreVerified = true;
      if (_pendingLocalPush) {
        _pendingLocalPush = false;
        queuePushAllData(delay: const Duration(seconds: 2));
      }
    } else {
      debugPrint(
        'Background cloud restore did not complete. Local data remains available and uploads stay paused until the next successful refresh.',
      );
    }
  }

  /// Restores reinstall-sensitive UI state only from the authenticated
  /// backend response. Keeping this in the shared initializer makes every
  /// Google owner sign-in path behave the same way.
  Future<void> _restoreVerifiedOwnerSetup(Map<String, dynamic> response) async {
    final packageName = response['subscriptionPackage']?.toString();
    final businessName = response['businessName']?.toString().trim();
    final businessAddress = response['businessAddress']?.toString();

    if (GetIt.I.isRegistered<PackageService>()) {
      await GetIt.I<PackageService>().restoreFromVerifiedBackendSubscription(
        packageName,
      );
    }

    if (businessName != null && businessName.isNotEmpty) {
      await BusinessInfoService().restoreFromVerifiedBackendBusiness(
        storeName: businessName,
        storeAddress: businessAddress,
      );
    }
  }

  /// Push all local data to Supabase (Backup)
  Future<bool> pushAllData() async {
    if (!isConfigured) {
      _lastError = 'Business not initialized. Please activate license first.';
      notifyListeners();
      return false;
    }
    if (!_initialCloudRestoreVerified) {
      // Never upload an empty or stale local snapshot before the canonical
      // cloud business records have completed their first merge.
      _pendingLocalPush = true;
      _lastError = 'Waiting for the initial cloud restore before uploading changes.';
      notifyListeners();
      return false;
    }

    await _beginSync();
    _lastError = null;
    _syncStats.clear();
    notifyListeners();

    try {
      debugPrint('📤 Starting full backup to Supabase...');

      final failedCollections = <String>[];

      // A bad historical record in one module must not prevent an unrelated
      // supplier order or restock from reaching the backend. Each collection
      // is independently retried, while the overall backup remains marked as
      // incomplete until every collection succeeds.
      await _pushCollection('users', _pushUsers, failedCollections);
      await _pushCollection('customers', _pushCustomers, failedCollections);
      await _pushCollection(
        'loyalty records',
        _pushLoyaltyLedger,
        failedCollections,
      );
      await _pushCollection('cameras', _pushCameras, failedCollections);
      await _pushCollection(
        'CCTV timestamps',
        _pushCctvTimestamps,
        failedCollections,
      );
      await _pushCollection('attendance', _pushAttendance, failedCollections);
      await _pushCollection(
        'activity logs',
        _pushActivityLogs,
        failedCollections,
      );
      await _pushCollection('suppliers', _pushSuppliers, failedCollections);
      await _pushCollection('products', _pushProducts, failedCollections);
      await _pushCollection('sales', _pushSales, failedCollections);
      await _pushCollection(
        'inventory movements',
        _pushInventoryMovements,
        failedCollections,
      );
      await _pushCollection(
        'purchase orders',
        _pushPurchaseOrders,
        failedCollections,
      );
      await _pushCollection(
        'restock records',
        _pushRestockRecords,
        failedCollections,
      );
      await _pushCollection(
        'damage reports',
        _pushDamageReports,
        failedCollections,
      );

      if (failedCollections.isNotEmpty) {
        _lastError =
            'Some changes are still waiting to sync: ${failedCollections.join(', ')}.';
        debugPrint('Partial backup completed. $_lastError');
        _finishSync();
        await _scheduleRetry();
        notifyListeners();
        return false;
      }

      await _recordSyncSuccess();
      _finishSync();
      notifyListeners();

      debugPrint('✅ Backup completed successfully');
      debugPrint('📊 Sync stats: $_syncStats');
      return true;
    } catch (e) {
      debugPrint('❌ Backup failed: $e');
      _lastError = safeApiError(e);
      _finishSync();
      await _scheduleRetry();
      notifyListeners();
      return false;
    }
  }

  Future<void> _pushCollection(
    String name,
    Future<void> Function() push,
    List<String> failedCollections,
  ) async {
    try {
      await push();
    } catch (error) {
      failedCollections.add(name);
      debugPrint('Cloud sync skipped $name for this attempt: $error');
    }
  }

  /// Sends the exact supplier order that a SmartPlus guided task is checking.
  /// This is intentionally separate from a full backup: a stale sale or
  /// historical loyalty record must not block completion of a real, approved
  /// supplier order or a recorded delivery.
  Future<bool> syncPurchaseOrderForSmartPlus(String orderNumber) async {
    final normalizedOrderNumber = orderNumber.trim();
    if (!isConfigured || normalizedOrderNumber.isEmpty) {
      _lastError = 'The supplier order cannot be synced before business setup is complete.';
      notifyListeners();
      return false;
    }
    if (!_initialCloudRestoreVerified) {
      _lastError =
          'Waiting for the first cloud restore before syncing this supplier order.';
      notifyListeners();
      return false;
    }

    try {
      final snapshot = await readLocalDataSafely<Map<String, dynamic>>(() async {
        final db = DatabaseService();
        final order = await db.getPurchaseOrderByNumber(normalizedOrderNumber);
        if (order == null || order.id == null) {
          throw StateError('Supplier order $normalizedOrderNumber was not found on this device.');
        }

        final supplier = await db.getSupplierById(order.supplierId);
        if (supplier == null) {
          throw StateError('The supplier for $normalizedOrderNumber was not found.');
        }

        final productsById = <int, Product>{};
        for (final item in order.items) {
          final product = await db.getProductById(item.productId);
          if (product == null) {
            throw StateError('Product ${item.productName} is missing from inventory.');
          }
          productsById[item.productId] = product;
        }

        final restocks = await db.getAllRestockRecords();
        final linkedRestocks = restocks
            .where(
              (record) => record.referencedBy.toLowerCase().contains(
                normalizedOrderNumber.toLowerCase(),
              ),
            )
            .toList(growable: false);
        final pendingVersions = await db.pendingPurchaseOrderVersions();

        return {
          'pendingVersions': pendingVersions.containsKey(order.orderNumber)
              ? <String, int>{
                  order.orderNumber: pendingVersions[order.orderNumber]!,
                }
              : <String, int>{},
          'payload': <String, dynamic>{
            'businessId': _businessId,
            'products': productsById.values.map(_productSyncRecord).toList(),
            'suppliers': [_supplierSyncRecord(supplier)],
            'purchaseOrders': [_purchaseOrderSyncRecord(order)],
            'purchaseOrderItems': order.items
                .map((item) => _purchaseOrderItemSyncRecord(order, item))
                .toList(),
            'restockRecords': linkedRestocks
                .map(_restockRecordSyncRecord)
                .toList(),
          },
        };
      });

      await _api.postJson(
        'sync/push',
        body: Map<String, dynamic>.from(snapshot['payload'] as Map),
      );
      final pendingVersions = Map<String, int>.from(
        snapshot['pendingVersions'] as Map,
      );
      if (pendingVersions.isNotEmpty) {
        await DatabaseService().acknowledgePurchaseOrderVersions(
          pendingVersions,
        );
      }
      _lastSyncTime = DateTime.now();
      await _saveSyncState();
      notifyListeners();
      debugPrint('SmartPlus synced supplier order $normalizedOrderNumber');
      return true;
    } catch (error) {
      _lastError = safeApiError(error);
      debugPrint(
        'Unable to sync SmartPlus supplier order $normalizedOrderNumber: $error',
      );
      await _scheduleRetry();
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic> _productSyncRecord(Product product) => {
    'id': product.id.toString(),
    'business_id': _businessId,
    'name': product.name,
    'barcode': product.barcode,
    'description': product.description,
    'buying_price': product.buyingPrice,
    'category': product.category,
    'selling_price': product.sellingPrice,
    'quantity': product.quantity,
    'image_path': product.imagePath,
    'low_stock_threshold': product.reorderLevel,
    'shoe_sizes': product.shoeSizes == null
        ? null
        : jsonEncode(product.shoeSizes!.map((size) => size.toMap()).toList()),
    'size_type': product.sizeType,
    'expiration_date': product.expirationDate?.toIso8601String(),
    'created_at': product.createdAt.toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  Map<String, dynamic> _supplierSyncRecord(Supplier supplier) => {
    'id': supplier.id.toString(),
    'business_id': _businessId,
    'name': supplier.name,
    'contact_person': supplier.contactPerson,
    'email': supplier.email,
    'phone': supplier.phone,
    'address': supplier.address,
    'notes': supplier.notes,
    'is_active': supplier.isActive,
    'created_at': supplier.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _purchaseOrderSyncRecord(PurchaseOrder order) => {
    'id': order.id.toString(),
    'business_id': _businessId,
    'supplier_id': order.supplierId.toString(),
    'order_number': order.orderNumber,
    'order_date': order.orderDate.toIso8601String(),
    'expected_delivery': order.expectedDeliveryDate?.toIso8601String(),
    'status': order.status,
    'total_amount': order.totalAmount,
    'notes': order.notes,
    'created_by': order.approvedBy ?? 'system',
    'created_at': order.orderDate.toIso8601String(),
  };

  Map<String, dynamic> _purchaseOrderItemSyncRecord(
    PurchaseOrder order,
    PurchaseOrderItem item,
  ) => {
    'business_id': _businessId,
    'purchase_order_id': order.id.toString(),
    'order_id': order.id.toString(),
    'product_id': item.productId.toString(),
    'product_name': item.productName,
    'quantity': item.quantity,
    'received_quantity': item.receivedQuantity,
    'unit_price': item.unitPrice,
    'total_price': item.totalPrice,
  };

  Map<String, dynamic> _restockRecordSyncRecord(RestockRecord record) => {
    'business_id': _businessId,
    'product_id': record.productId.toString(),
    'product_name': record.productName,
    'quantity': record.quantity,
    'supplier_id': record.supplierId?.toString(),
    'supplier_name': record.supplierName,
    'delivery_receipt_no': record.deliveryReceiptNo,
    'damage_quantity': record.damageQuantity,
    'damage_reason': record.damageReason,
    'notes': record.notes,
    'referenced_by': record.referencedBy,
    'restock_date': record.restockDate.toIso8601String(),
  };

  /// Coalesce concurrent startup restores. This prevents overlapping SQLite
  /// writes and makes every caller wait for the same verified restore.
  Future<bool> pullAllData() async {
    final runningRestore = _restoreInFlight;
    if (runningRestore != null) return runningRestore;

    final restore = _pullAllDataOnce();
    _restoreInFlight = restore;
    try {
      return await restore;
    } finally {
      if (identical(_restoreInFlight, restore)) {
        _restoreInFlight = null;
      }
    }
  }

  /// Pull all data from the authoritative backend to the local database.
  Future<bool> _pullAllDataOnce() async {
    if (!isConfigured) {
      _lastError = 'Business not initialized. Please activate license first.';
      notifyListeners();
      return false;
    }

    // Snapshot the verified tenant before an await. A stale sign-out callback
    // must not turn a recoverable context change into a null-check crash.
    final verifiedBusinessId = _businessId;
    if (verifiedBusinessId == null || verifiedBusinessId.isEmpty) {
      _lastError = 'Business context is unavailable. Please sign in again.';
      notifyListeners();
      return false;
    }

    var restoreStage = 'requesting cloud records';
    await _beginSync();
    _lastError = null;
    _syncStats.clear();
    notifyListeners();

    try {
      debugPrint('📥 Starting restore from Supabase...');

      final db = DatabaseService();
      final payload = await _api.getJson(
        'sync/pull',
        queryParameters: {'businessId': verifiedBusinessId},
      );

      // Pull data in order (respecting foreign keys)
      await db.runWithoutCloudSync(() async {
        restoreStage = 'users';
        await _pullUsers(payload);
        restoreStage = 'customers';
        await _pullCustomers(db, payload);
        restoreStage = 'loyalty ledger';
        await _pullLoyaltyLedger(db, payload);
        restoreStage = 'cameras';
        await _pullCameras(db, payload);
        restoreStage = 'CCTV timestamps';
        await _pullCctvTimestamps(db, payload);
        restoreStage = 'attendance';
        await _pullAttendance(db, payload);
        restoreStage = 'activity logs';
        await _pullActivityLogs(db, payload);
        restoreStage = 'suppliers';
        await _pullSuppliers(db, payload);
        restoreStage = 'products';
        await _pullProducts(db, payload);
        restoreStage = 'sales';
        await _pullSales(db, payload);
        restoreStage = 'inventory movements';
        await _pullInventoryMovements(db, payload);
        restoreStage = 'purchase orders';
        await _pullPurchaseOrders(db, payload);
        restoreStage = 'damage reports';
        await _pullDamageReports(db, payload);
      });

      await _recordSyncSuccess();
      _finishSync();
      _initialCloudRestoreVerified = true;
      if (_pendingLocalPush) {
        _pendingLocalPush = false;
        queuePushAllData(delay: const Duration(seconds: 2));
      }
      notifyListeners();

      debugPrint('✅ Restore completed successfully');
      debugPrint('📊 Sync stats: $_syncStats');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Restore failed during $restoreStage: $e');
      debugPrintStack(stackTrace: stackTrace, label: 'Restore failure stack');
      debugPrint('❌ Restore failed: $e');
      _lastError = safeApiError(e);
      _finishSync();
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
      if (!isConfigured) {
        return;
      }
      if (_isSyncing) {
        // A local write schedules its own queued upload. Do not turn a slow
        // periodic pull into a full backup when there is no new local change.
        return;
      }

      try {
        // Poll cloud changes without re-uploading every product, sale, and
        // purchase-order item on every device on a short loop. Writes are
        // still pushed promptly by queuePushAllData after a local mutation.
        await pullAllData();
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

    if (!_initialCloudRestoreVerified) {
      _pendingLocalPush = true;
      return;
    }

    if (delay != null && delay.inMilliseconds > 0) {
      _queuedPushDelay = delay;
    }

    _queuedPushTimer?.cancel();
    _queuedPushTimer = Timer(_queuedPushDelay, () async {
      if (!isConfigured) {
        return;
      }
      if (_isSyncing) {
        // Do not lose a local write just because a pull or another push is in
        // progress. Schedule one follow-up upload instead.
        queuePushAllData(delay: _queuedPushDelay);
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
              'marketing_consent': c.marketingConsent ? 1 : 0,
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
      final sales = await db.getAllSales();
      final saleNumbersByLocalId = <int, String>{
        for (final sale in sales)
          if (sale.id != null) sale.id!: sale.saleNumber,
      };
      final entries = <Map<String, dynamic>>[];

      for (final customer in customers) {
        if (customer.id == null) continue;
        final ledger = await db.getLoyaltyLedger(customer.id!);
        for (final entry in ledger) {
          entries.add({
            'business_id': _businessId,
            // customerId and saleId are SQLite-only identifiers. The backend
            // resolves these stable references within the current tenant.
            'customer_code': customer.customerCode,
            'sale_number': entry.saleId == null
                ? null
                : saleNumbersByLocalId[entry.saleId!],
            'client_entry_id': entry.syncId,
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
      final pendingVersions = await db.pendingProductVersions();
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
              'expiration_date': p.expirationDate?.toIso8601String(),
              'created_at': p.createdAt.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'products': productData},
      );
      await db.acknowledgeProductVersions(pendingVersions);
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
      final customers = await db.getCustomers();
      final customerCodesByLocalId = <int, String>{
        for (final customer in customers)
          if (customer.id != null) customer.id!: customer.customerCode,
      };
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
              // SQLite customer IDs are local to this device. The backend
              // resolves this stable code within the authenticated business.
              'customer_code': s.customerId == null
                  ? null
                  : customerCodesByLocalId[s.customerId!],
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
      final cashiers = activeUsers
          .where((u) => u.role == UserRole.cashier)
          .toList();
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
      final pendingVersions = await db.pendingPurchaseOrderVersions();
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
            'business_id': _businessId,
            'purchase_order_id': orderId.toString(),
            'order_id': orderId.toString(),
            'product_id': item.productId.toString(),
            'product_name': item.productName,
            'quantity': item.quantity,
            'received_quantity': item.receivedQuantity,
            'unit_price': item.unitPrice,
            'total_price': item.totalPrice,
          });
        }
      }

      // A batch is limited by its serialized byte size, not just the number
      // of orders. An order can have many line items, so a 25-order batch can
      // still exceed a proxy limit. Headers are sent first; their items are
      // then sent in separate bounded requests after the parent orders exist.
      const maxBatchBytes = 256 * 1024;

      Future<void> pushSizedBatches(
        String collection,
        List<Map<String, dynamic>> records,
      ) async {
        var batch = <Map<String, dynamic>>[];

        int serializedSize(List<Map<String, dynamic>> candidate) => utf8
            .encode(
              jsonEncode({'businessId': _businessId, collection: candidate}),
            )
            .length;

        Future<void> sendCurrent() async {
          if (batch.isEmpty) return;
          await _api.postJson(
            'sync/push',
            body: {'businessId': _businessId, collection: batch},
          );
          batch = <Map<String, dynamic>>[];
        }

        for (final record in records) {
          final candidate = [...batch, record];
          if (batch.isNotEmpty && serializedSize(candidate) > maxBatchBytes) {
            await sendCurrent();
          }
          final single = [record];
          if (serializedSize(single) > maxBatchBytes) {
            throw StateError(
              'One purchase-order $collection record is too large to sync. Shorten its notes and retry.',
            );
          }
          batch.add(record);
        }
        await sendCurrent();
      }

      await pushSizedBatches('purchaseOrders', orderData);
      await pushSizedBatches('purchaseOrderItems', orderItems);
      await db.acknowledgePurchaseOrderVersions(pendingVersions);
      _syncStats['purchase_orders_pushed'] = orders.length;
      _syncStats['purchase_order_items_pushed'] = orderItems.length;
      debugPrint('✅ Pushed ${orders.length} purchase orders');
      debugPrint('✅ Pushed ${orderItems.length} purchase order items');
    } catch (e) {
      debugPrint('❌ Error pushing purchase orders: $e');
      rethrow;
    }
  }

  /// Restock records prove that a received purchase-order item was added to
  /// inventory. They must reach the central backend so SmartPlus can avoid
  /// sending a false "delivered stock not added" owner alert.
  Future<void> _pushRestockRecords() async {
    try {
      final db = DatabaseService();
      final records = await db.getAllRestockRecords();
      if (records.isEmpty) {
        _syncStats['restock_records_pushed'] = 0;
        return;
      }
      final payload = records
          .map(
            (record) => {
              'business_id': _businessId,
              'product_id': record.productId.toString(),
              'product_name': record.productName,
              'quantity': record.quantity,
              'supplier_id': record.supplierId?.toString(),
              'supplier_name': record.supplierName,
              'delivery_receipt_no': record.deliveryReceiptNo,
              'damage_quantity': record.damageQuantity,
              'damage_reason': record.damageReason,
              'notes': record.notes,
              'referenced_by': record.referencedBy,
              'restock_date': record.restockDate.toIso8601String(),
            },
          )
          .toList();
      await _api.postJson(
        'sync/push',
        body: {'businessId': _businessId, 'restockRecords': payload},
      );
      _syncStats['restock_records_pushed'] = records.length;
      debugPrint('Pushed ${records.length} restock records');
    } catch (error) {
      debugPrint('Error pushing restock records: $error');
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
          marketingConsent: _asBool(data['marketing_consent']),
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

      final customers = await db.getCustomers();
      final localCustomerIdsByCode = <String, int>{
        for (final customer in customers)
          if (customer.id != null) customer.customerCode: customer.id!,
      };
      final sales = await db.getAllSales();
      final localSaleIdsByNumber = <String, int>{
        for (final sale in sales)
          if (sale.id != null) sale.saleNumber: sale.id!,
      };

      final entries = <Map<String, dynamic>>[];
      for (final data in response) {
        final customerCode = data['customer_code']?.toString() ?? '';
        final localCustomerId = localCustomerIdsByCode[customerCode];
        if (localCustomerId == null) {
          debugPrint(
            'Skipping loyalty entry without a local customer for code $customerCode',
          );
          continue;
        }
        final saleNumber = data['sale_number']?.toString();
        entries.add({
          'id': null,
          'syncId':
              data['client_entry_id']?.toString() ??
              'legacy:$customerCode:${data['id']}',
          'customerId': localCustomerId,
          'saleId': saleNumber == null
              ? null
              : localSaleIdsByNumber[saleNumber],
          'entryType': data['entry_type']?.toString() ?? 'earn',
          'points': _asInt(data['points']),
          'balanceAfter': _asInt(data['balance_after']),
          'notes': data['notes']?.toString(),
          'createdAt': _asDateTime(data['created_at']).toIso8601String(),
        });
      }

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
          'description':
              data['description']?.toString() ?? data['label']?.toString(),
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
          ? List<Map<String, dynamic>>.from(
              payload['attendanceArchive'] as List,
            )
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
        groupedEntries
            .putIfAbsent(userId, () => <AttendanceEntry>[])
            .add(entry);
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
        archivesByUser.putIfAbsent(
          userId,
          () => <String, List<AttendanceEntry>>{},
        );
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
      _syncStats['attendance_schedule_pulled'] = scheduleResponse == null
          ? 0
          : 1;
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

  Future<void> _pullProducts(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
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
          expirationDate: data['expiration_date'] == null
              ? null
              : DateTime.tryParse(data['expiration_date'].toString()),
          shoeSizes: _parseShoeSizes(data['shoe_sizes']),
          sizeType: data['size_type']?.toString(),
        );
      }).toList();

      var preserved = 0;
      for (final product in products) {
        if (!await db.mergeSyncedProduct(product)) preserved++;
      }

      if (preserved > 0) {
        debugPrint(
          'Preserved $preserved product(s) with unsynced local sales.',
        );
      }

      _syncStats['products_pulled'] = products.length;
      debugPrint('✅ Pulled ${products.length} products');
    } catch (e) {
      debugPrint('❌ Error pulling products: $e');
      rethrow;
    }
  }

  Future<void> _pullSales(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
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

      final customers = await db.getCustomers();
      final localCustomerIdsByCode = <String, int>{
        for (final customer in customers)
          if (customer.id != null) customer.customerCode: customer.id!,
      };

      final sales = response.map((data) {
        final cloudSaleId = data['id']?.toString() ?? '';
        final saleNumber =
            data['sale_number']?.toString() ??
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
          customerId: localCustomerIdsByCode[data['customer_code']?.toString()],
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

  Future<void> _pullInventoryMovements(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = payload['inventoryMovements'] is List
          ? List<Map<String, dynamic>>.from(
              payload['inventoryMovements'] as List,
            )
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
      // Do not report a successful restore or push conflicting local IDs.
      rethrow;
    }
  }

  Future<void> _pullSuppliers(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
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

  Future<void> _pullPurchaseOrders(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = payload['purchaseOrders'] is List
          ? List<Map<String, dynamic>>.from(payload['purchaseOrders'] as List)
          : <Map<String, dynamic>>[];
      final responseItems = payload['purchaseOrderItems'] is List
          ? List<Map<String, dynamic>>.from(
              payload['purchaseOrderItems'] as List,
            )
          : <Map<String, dynamic>>[];

      final itemsByOrder = <String, List<Map<String, dynamic>>>{};
      for (final item in responseItems) {
        final orderId =
            item['purchase_order_id']?.toString() ??
            item['order_id']?.toString() ??
            '';
        itemsByOrder.putIfAbsent(orderId, () => []).add(item);
      }

      final orders = <PurchaseOrder>[];
      for (final data in response) {
        final cloudOrderKey = data['id']?.toString() ?? '';
        final orderNumber =
            data['order_number']?.toString() ??
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
            receivedQuantity: _asInt(
              itemData['received_quantity'] ?? itemData['receivedQuantity'],
            ),
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
      // Do not call this a successful restore. The caller keeps automatic
      // uploads paused until every business record, including order items,
      // has restored safely.
      rethrow;
    }
  }

  Future<void> _pullDamageReports(
    DatabaseService db,
    Map<String, dynamic> payload,
  ) async {
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
          reason:
              data['damage_type']?.toString() ??
              data['description']?.toString() ??
              'unknown',
          reportedBy: data['reported_by']?.toString() ?? 'unknown',
          reportDate: _asDateTime(data['reported_at']),
          returnStatus: status,
          responsiblePerson: data['resolution_notes']?.toString(),
        );
      }).toList();

      for (final report in reports) {
        // The remote ID is also the local SQLite primary key. Ignore an
        // already-restored report rather than failing the entire restore or
        // overwriting local signature/payment settlement details that the
        // compact cloud payload does not contain.
        await db.insertDamageReportIfAbsent(report);
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
          .map(
            (entry) =>
                ShoeSize.fromMap(Map<String, dynamic>.from(entry as Map)),
          )
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
    _initialCloudRestoreTimer?.cancel();
    _initialCloudRestoreTimer = null;
    _businessId = null;
    _initialCloudRestoreVerified = false;
    _pendingLocalPush = false;
    _initialCloudRestoreInFlight = null;
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
