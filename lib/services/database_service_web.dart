// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' show window;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get_it/get_it.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/purchase_order.dart';
import '../models/inventory_movement.dart';
import '../models/customer.dart';
import '../models/loyalty_ledger_entry.dart';
import 'backend_api_service.dart';
import 'backend_config.dart';
import 'supabase_sync_service.dart';

/// A lightweight web-backed DatabaseService that persists to window.localStorage.
/// This provides a compatible API for web builds when sqflite is not available.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  bool _suppressCloudSync = false;
  final ApiClient _api = ApiClient();

  static const _storageKey = 'pos_system_db_v1';

  Map<String, dynamic> _store = {
    'products': <Map<String, dynamic>>[],
    'sales': <Map<String, dynamic>>[],
    'purchase_orders': <Map<String, dynamic>>[],
    'purchase_order_items': <Map<String, dynamic>>[],
    'inventory_movements': <Map<String, dynamic>>[],
    'customers': <Map<String, dynamic>>[],
    'loyalty_ledger': <Map<String, dynamic>>[],
    'activity_logs': <Map<String, dynamic>>[],
    'cameras': <Map<String, dynamic>>[],
    'cctv_timestamps': <Map<String, dynamic>>[],
    'counters': {
      'product': 0,
      'sale': 0,
      'purchase_order': 0,
      'purchase_order_item': 0,
      'movement': 0,
      'customer': 0,
      'ledger': 0,
      'activity_log': 0,
      'camera': 0,
      'cctv_timestamp': 0,
    },
  };

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

  String? _currentBusinessId() {
    try {
      return GetIt.I.isRegistered<SupabaseSyncService>()
          ? GetIt.I<SupabaseSyncService>().businessId
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteRemoteRecord(String resource, dynamic id) async {
    if (!BackendConfig.useRestBackend) return;
    final businessId = _currentBusinessId();
    if (businessId == null || businessId.isEmpty) return;
    await _api.deleteJson(
      '$resource/$id',
      queryParameters: {'businessId': businessId},
    );
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

  Future<String> copyBackupToAppFolder(String sourcePath) async {
    throw UnsupportedError(
      'Local backup folders are not supported on web builds.',
    );
  }

  Future<String> ensureBackupDirectoryExists() async {
    return 'web';
  }

  Future<void> _load() async {
    final raw = window.localStorage[_storageKey];
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _store = decoded;
      _store.putIfAbsent('products', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('sales', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('purchase_orders', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('purchase_order_items', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('inventory_movements', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('customers', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('loyalty_ledger', () => <Map<String, dynamic>>[]);
      final counters = Map<String, dynamic>.from(
        _store['counters'] as Map? ?? const {},
      );
      counters.putIfAbsent('product', () => 0);
      counters.putIfAbsent('sale', () => 0);
      counters.putIfAbsent('purchase_order', () => 0);
      counters.putIfAbsent('purchase_order_item', () => 0);
      counters.putIfAbsent('movement', () => 0);
      counters.putIfAbsent('customer', () => 0);
      counters.putIfAbsent('ledger', () => 0);
      _store['counters'] = counters;

      final cleaned = _cleanupDuplicateSalesInStore();
      if (cleaned) {
        await _save();
      }
    } catch (_) {
      // ignore and keep defaults
    }
  }

  Future<void> _save() async {
    window.localStorage[_storageKey] = jsonEncode(_store);
  }

  int _nextId(String key) {
    final counters = Map<String, dynamic>.from(_store['counters'] as Map);
    final cur = (counters[key] as int?) ?? 0;
    final next = cur + 1;
    counters[key] = next;
    _store['counters'] = counters;
    return next;
  }

  void _bumpCounter(String key, int value) {
    final counters = Map<String, dynamic>.from(_store['counters'] as Map);
    final cur = (counters[key] as int?) ?? 0;
    if (value > cur) {
      counters[key] = value;
      _store['counters'] = counters;
    }
  }

  // -------------------- Product Operations --------------------

  Future<int> insertProduct(Product product) async {
    await _load();
    final id = _nextId('product');
    final map = product.toMap()..['id'] = id;
    final List products = List.from(_store['products'] as List);
    products.add(map);
    _store['products'] = products;
    await _save();
    _queueCloudSync();
    return id;
  }

  Future<List<Product>> getAllProducts() async {
    await _load();
    final List products = _store['products'] as List<dynamic>;
    return products
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Product?> getProductById(int id) async {
    await _load();
    final List products = _store['products'] as List<dynamic>;
    Map? match;
    for (final m in products) {
      final map = m as Map<String, dynamic>;
      if (map['id'] == id) {
        match = Map<String, dynamic>.from(map);
        break;
      }
    }
    if (match == null) return null;
    return Product.fromMap(match as Map<String, dynamic>);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    await _load();
    final List products = _store['products'] as List<dynamic>;
    Map? match;
    for (final m in products) {
      final map = m as Map<String, dynamic>;
      if ((map['barcode'] as String?) == barcode) {
        match = Map<String, dynamic>.from(map);
        break;
      }
    }
    if (match == null) return null;
    return Product.fromMap(match as Map<String, dynamic>);
  }

  Future<List<Product>> searchProducts(String query) async {
    await _load();
    final q = query.toLowerCase();
    final List products = _store['products'] as List<dynamic>;
    final results = products.where((m) {
      final name = (m['name'] as String?)?.toLowerCase() ?? '';
      final barcode = (m['barcode'] as String?)?.toLowerCase() ?? '';
      return name.contains(q) || barcode.contains(q);
    }).toList();
    return results
        .map((e) => Product.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> updateProduct(Product product) async {
    await _load();
    final List products = List.from(_store['products'] as List<dynamic>);
    final idx = products.indexWhere((m) => m['id'] == product.id);
    if (idx == -1) return 0;
    products[idx] = product.toMap();
    _store['products'] = products;
    await _save();
    _queueCloudSync();
    return 1;
  }

  Future<int> deleteProduct(int id) async {
    await _load();
    final List products = List.from(_store['products'] as List<dynamic>);
    final before = products.length;
    products.removeWhere((m) => m['id'] == id);
    _store['products'] = products;
    await _save();
    await _deleteRemoteRecord('products', id);
    _queueCloudSync();
    return before - products.length;
  }

  Future<List<Product>> getLowStockProducts() async {
    final all = await getAllProducts();
    return all.where((p) => p.quantity <= p.reorderLevel).toList();
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    final all = await getAllProducts();
    return all.where((p) => p.category == category).toList();
  }

  // -------------------- Customer & Loyalty Operations --------------------

  Future<Customer> insertCustomer(Customer customer) async {
    await _load();
    final id = _nextId('customer');
    final now = DateTime.now();
    final map = customer.copyWith(id: id, updatedAt: now).toMap();
    final List customers = List.from(_store['customers'] as List<dynamic>);
    customers.add(map);
    _store['customers'] = customers;
    await _save();
    _queueCloudSync();
    return Customer.fromMap(Map<String, dynamic>.from(map));
  }

  Future<Customer> updateCustomer(Customer customer) async {
    await _load();
    final updated = customer.copyWith(updatedAt: DateTime.now()).toMap();
    final List customers = List.from(_store['customers'] as List<dynamic>);
    final idx = customers.indexWhere((m) => m['id'] == customer.id);
    if (idx == -1) {
      throw StateError('Customer not found');
    }
    customers[idx] = updated;
    _store['customers'] = customers;
    await _save();
    _queueCloudSync();
    return Customer.fromMap(Map<String, dynamic>.from(updated));
  }

  Future<Customer> insertOrUpdateCustomer(Customer customer) async {
    await _load();
    final now = DateTime.now();
    final List customers = List.from(_store['customers'] as List<dynamic>);
    final idx = customer.id == null
        ? -1
        : customers.indexWhere((m) => m['id'] == customer.id);
    if (idx >= 0) {
      final updated = customer.copyWith(updatedAt: now).toMap();
      customers[idx] = updated;
      _store['customers'] = customers;
      await _save();
      _queueCloudSync();
      return Customer.fromMap(Map<String, dynamic>.from(updated));
    }

    final map = customer.copyWith(updatedAt: now).toMap();
    final id = customer.id ?? _nextId('customer');
    _bumpCounter('customer', id);
    final stored = {...map, 'id': id};
    customers.add(stored);
    _store['customers'] = customers;
    await _save();
    _queueCloudSync();
    return Customer.fromMap(Map<String, dynamic>.from(stored));
  }

  Future<List<Customer>> getCustomers({String? query}) async {
    await _load();
    final q = query?.trim().toLowerCase();
    final List customers = _store['customers'] as List<dynamic>;
    final filtered = customers.where((m) {
      if (q == null || q.isEmpty) return true;
      final map = m as Map<String, dynamic>;
      final fullName = (map['fullName'] as String?)?.toLowerCase() ?? '';
      final phoneNumber = (map['phoneNumber'] as String?)?.toLowerCase() ?? '';
      final email = (map['email'] as String?)?.toLowerCase() ?? '';
      final barcodeValue =
          (map['barcodeValue'] as String?)?.toLowerCase() ?? '';
      return fullName.contains(q) ||
          phoneNumber.contains(q) ||
          email.contains(q) ||
          barcodeValue.contains(q);
    }).toList();
    return filtered
        .map((e) => Customer.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    await _load();
    final List customers = _store['customers'] as List<dynamic>;
    for (final m in customers) {
      final map = m as Map<String, dynamic>;
      if (map['id'] == id) {
        return Customer.fromMap(Map<String, dynamic>.from(map));
      }
    }
    return null;
  }

  Future<Customer?> getCustomerByBarcode(String barcodeValue) async {
    await _load();
    final List customers = _store['customers'] as List<dynamic>;
    for (final m in customers) {
      final map = m as Map<String, dynamic>;
      if ((map['barcodeValue'] as String?) == barcodeValue) {
        return Customer.fromMap(Map<String, dynamic>.from(map));
      }
    }
    return null;
  }

  Future<Customer?> getCustomerByName(String fullName) async {
    await _load();
    final target = fullName.trim().toLowerCase();
    final List customers = _store['customers'] as List<dynamic>;
    for (final m in customers) {
      final map = m as Map<String, dynamic>;
      if (((map['fullName'] as String?) ?? '').toLowerCase() == target) {
        return Customer.fromMap(Map<String, dynamic>.from(map));
      }
    }
    return null;
  }

  Future<void> deactivateCustomer(int id) async {
    final customer = await getCustomerById(id);
    if (customer == null) return;
    await updateCustomer(customer.copyWith(isActive: false));
  }

  Future<void> deleteCustomer(int id) async {
    await _load();
    _store['loyalty_ledger'] = (_store['loyalty_ledger'] as List<dynamic>)
        .where((item) => (item['customerId'] as int?) != id)
        .toList();
    _store['customers'] = (_store['customers'] as List<dynamic>)
        .where((item) => (item['id'] as int?) != id)
        .toList();
    await _save();
      await _deleteRemoteRecord('customers', id);
    _queueCloudSync();
  }

  Future<List<LoyaltyLedgerEntry>> getLoyaltyLedger(int customerId) async {
    await _load();
    final List entries = _store['loyalty_ledger'] as List<dynamic>;
    final filtered = entries
        .where((m) => (m['customerId'] as int?) == customerId)
        .toList();
    filtered.sort(
      (a, b) => ((b['createdAt'] as String?) ?? '').compareTo(
        (a['createdAt'] as String?) ?? '',
      ),
    );
    return filtered
        .map(
          (e) =>
              LoyaltyLedgerEntry.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> replaceLoyaltyLedgerEntries(
    List<Map<String, dynamic>> entries,
  ) async {
    await _load();
    _store['loyalty_ledger'] = entries;
    var maxId = 0;
    for (final entry in entries) {
      final id = int.tryParse(entry['id']?.toString() ?? '') ?? 0;
      if (id > maxId) maxId = id;
    }
    if (maxId > 0) {
      _bumpCounter('ledger', maxId);
    }
    await _save();
  }

  Future<void> awardCustomerPoints({
    required int customerId,
    int? saleId,
    required int points,
    String? notes,
  }) async {
    if (points <= 0) return;
    final customer = await getCustomerById(customerId);
    if (customer == null) return;
    final updated = customer.copyWith(
      pointsBalance: customer.pointsBalance + points,
      lifetimePoints: customer.lifetimePoints + points,
      updatedAt: DateTime.now(),
    );
    await updateCustomer(updated);
    final ledgerId = _nextId('ledger');
    final entry = LoyaltyLedgerEntry(
      id: ledgerId,
      customerId: customerId,
      saleId: saleId,
      entryType: LoyaltyEntryType.earn,
      points: points,
      balanceAfter: updated.pointsBalance,
      notes: notes,
    );
    final List entries = List.from(_store['loyalty_ledger'] as List<dynamic>);
    entries.add(entry.toMap());
    _store['loyalty_ledger'] = entries;
    await _save();
    _queueCloudSync();
  }

  Future<bool> redeemCustomerPoints({
    required int customerId,
    required int points,
    String? notes,
  }) async {
    if (points <= 0) return false;
    final customer = await getCustomerById(customerId);
    if (customer == null || customer.pointsBalance < points) return false;
    final updated = customer.copyWith(
      pointsBalance: customer.pointsBalance - points,
      updatedAt: DateTime.now(),
    );
    await updateCustomer(updated);
    final ledgerId = _nextId('ledger');
    final entry = LoyaltyLedgerEntry(
      id: ledgerId,
      customerId: customerId,
      saleId: null,
      entryType: LoyaltyEntryType.redeem,
      points: -points,
      balanceAfter: updated.pointsBalance,
      notes: notes,
    );
    final List entries = List.from(_store['loyalty_ledger'] as List<dynamic>);
    entries.add(entry.toMap());
    _store['loyalty_ledger'] = entries;
    await _save();
    _queueCloudSync();
    return true;
  }

  // -------------------- Sale Operations --------------------

  Future<int> insertSale(Sale sale) async {
    await _load();
    final saleId = _nextId('sale');
    final saleMap = sale.toMap()..['id'] = saleId;
    // Ensure items have no separate persistent id, they are embedded here
    final List sales = List.from(_store['sales'] as List<dynamic>);
    sales.add(saleMap);
    _store['sales'] = sales;

    // Decrease product quantities and record movements
    final products = List.from(_store['products'] as List<dynamic>);
    for (final item in (sale.items)) {
      final pid = item.productId;
      final pIdx = products.indexWhere((p) => p['id'] == pid);
      if (pIdx != -1) {
        final beforeQty = (products[pIdx]['quantity'] as int?) ?? 0;
        final afterQty = beforeQty - item.quantity;
        products[pIdx]['quantity'] = afterQty;
        // record movement
        final movementId = _nextId('movement');
        final movement = InventoryMovement(
          id: movementId,
          productId: pid,
          quantityBefore: beforeQty,
          quantityAfter: afterQty,
          quantityChanged: -item.quantity,
          movementType: 'sale',
          reference: sale.saleNumber,
          reason: 'Sale ${sale.saleNumber}',
          movementDate: DateTime.now(),
        );
        final movements = List.from(
          _store['inventory_movements'] as List<dynamic>,
        );
        movements.add(movement.toMap());
        _store['inventory_movements'] = movements;
      }
    }
    _store['products'] = products;
    await _save();
    _queueCloudSync();
    return saleId;
  }

  List<Sale> _dedupeSalesByNumber(List<Sale> sales) {
    final Map<String, Sale> unique = {};
    for (final sale in sales) {
      unique.putIfAbsent(sale.saleNumber, () => sale);
    }
    return unique.values.toList();
  }

  bool _cleanupDuplicateSalesInStore() {
    final salesSource = (_store['sales'] as List<dynamic>?) ?? <dynamic>[];
    final rawSales = List<Map<String, dynamic>>.from(
      salesSource.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (rawSales.length < 2) {
      return false;
    }

    rawSales.sort((a, b) {
      final aDate = DateTime.tryParse(a['saleDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['saleDate']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = bDate.compareTo(aDate);
      if (dateCompare != 0) return dateCompare;

      final aId = (a['id'] as num?)?.toInt() ?? 0;
      final bId = (b['id'] as num?)?.toInt() ?? 0;
      return bId.compareTo(aId);
    });

    final unique = <String, Map<String, dynamic>>{};
    for (final sale in rawSales) {
      final saleNumber = sale['saleNumber']?.toString();
      if (saleNumber == null || saleNumber.isEmpty) {
        continue;
      }
      unique.putIfAbsent(saleNumber, () => sale);
    }

    final cleanedSales = unique.values.toList();
    final changed = cleanedSales.length != rawSales.length;
    if (changed) {
      _store['sales'] = cleanedSales;
      debugPrint(
        '🧹 Removed ${rawSales.length - cleanedSales.length} duplicate sale record(s) from local storage',
      );
    }
    return changed;
  }

  Future<Sale?> getSaleById(int id) async {
    await _load();
    final List sales = _store['sales'] as List<dynamic>;
    Map<String, dynamic>? saleMap;
    for (final m in sales) {
      final map = m as Map<String, dynamic>;
      if (map['id'] == id) {
        saleMap = Map<String, dynamic>.from(map);
        break;
      }
    }
    if (saleMap == null) return null;
    final items =
        (saleMap['items'] as List?)
            ?.map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final sale = Sale.fromMap(saleMap).copyWith(items: items);
    return sale;
  }

  Future<List<Sale>> getAllSales({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _load();
    final List sales = _store['sales'] as List<dynamic>;
    final results = sales
        .map(
          (e) => Sale.fromMap(
            Map<String, dynamic>.from(e as Map<String, dynamic>),
          ),
        )
        .toList();
    if (startDate != null && endDate != null) {
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

      final filtered = results.where((s) {
        final d = s.saleDate;
        return (d.isAfter(adjustedStart) ||
                d.isAtSameMomentAs(adjustedStart)) &&
            (d.isBefore(adjustedEnd) || d.isAtSameMomentAs(adjustedEnd));
      }).toList();
      filtered.sort((a, b) => b.saleDate.compareTo(a.saleDate));
      return _dedupeSalesByNumber(filtered);
    }
    results.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return _dedupeSalesByNumber(results);
  }

  Future<List<Sale>> getSalesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return getAllSales(startDate: startDate, endDate: endDate);
  }

  Future<double> getDailySales(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final sales = await getAllSales(startDate: start, endDate: end);
    double total = 0.0;
    for (final s in sales) {
      if (s.status == SaleStatus.completed) {
        total += s.totalAmount;
      }
    }
    return total;
  }

  Future<int> getTotalTransactions(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final sales = await getAllSales(startDate: start, endDate: end);
    return sales.where((sale) => sale.status == SaleStatus.completed).length;
  }

  Future<double> getSalesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    double total = 0.0;
    for (final s in sales) {
      if (s.status == SaleStatus.completed) {
        total += s.totalAmount;
      }
    }
    return total;
  }

  Future<int> getTransactionCountForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    return sales.where((sale) => sale.status == SaleStatus.completed).length;
  }

  // -------------------- Purchase Order Operations --------------------

  String generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(6);
    return 'PO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$timestamp';
  }

  Future<int> insertPurchaseOrder(PurchaseOrder order) async {
    await _load();
    final orderId = _nextId('purchase_order');
    final orderMap = order.toMap()..['id'] = orderId;
    final orders = List.from(_store['purchase_orders'] as List<dynamic>);
    orders.add(orderMap);
    _store['purchase_orders'] = orders;

    final items = List.from(_store['purchase_order_items'] as List<dynamic>);
    for (final item in order.items) {
      final itemId = item.id ?? _nextId('purchase_order_item');
      final itemMap = item.copyWith(id: itemId, orderId: orderId).toMap();
      items.add(itemMap);
    }
    _store['purchase_order_items'] = items;
    await _save();
    _queueCloudSync();
    return orderId;
  }

  Future<int> insertOrUpdatePurchaseOrder(PurchaseOrder order) async {
    await _load();
    final orders = List.from(_store['purchase_orders'] as List<dynamic>);
    final idx = orders.indexWhere((m) => m['orderNumber'] == order.orderNumber);
    if (idx >= 0) {
      final existingId = orders[idx]['id'] as int;
      orders[idx] = order.copyWith(id: existingId).toMap();
      final items = List.from(_store['purchase_order_items'] as List<dynamic>)
          .where((m) => m['orderId'] != existingId)
          .toList();
      for (final item in order.items) {
        final itemId = item.id ?? _nextId('purchase_order_item');
        items.add(item.copyWith(id: itemId, orderId: existingId).toMap());
      }
      _store['purchase_orders'] = orders;
      _store['purchase_order_items'] = items;
      await _save();
      _queueCloudSync();
      return existingId;
    }
    return insertPurchaseOrder(order);
  }

  Future<List<PurchaseOrderItem>> getPurchaseOrderItems(int orderId) async {
    await _load();
    final List items = _store['purchase_order_items'] as List<dynamic>;
    return items
        .where((m) => (m as Map)['orderId'] == orderId)
        .map((e) => PurchaseOrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    await _load();
    final List orders = _store['purchase_orders'] as List<dynamic>;
    final results = <PurchaseOrder>[];
    for (final order in orders) {
      final map = Map<String, dynamic>.from(order as Map);
      final items = await getPurchaseOrderItems(map['id'] as int);
      results.add(PurchaseOrder.fromMap(map).copyWith(items: items));
    }
    results.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    return results;
  }

  Future<PurchaseOrder?> getPurchaseOrderById(int id) async {
    await _load();
    final List orders = _store['purchase_orders'] as List<dynamic>;
    for (final order in orders) {
      final map = Map<String, dynamic>.from(order as Map);
      if (map['id'] == id) {
        final items = await getPurchaseOrderItems(id);
        return PurchaseOrder.fromMap(map).copyWith(items: items);
      }
    }
    return null;
  }

  Future<PurchaseOrder?> getPurchaseOrderByNumber(String orderNumber) async {
    await _load();
    final List orders = _store['purchase_orders'] as List<dynamic>;
    for (final order in orders) {
      final map = Map<String, dynamic>.from(order as Map);
      if (map['orderNumber'] == orderNumber) {
        final items = await getPurchaseOrderItems(map['id'] as int);
        return PurchaseOrder.fromMap(map).copyWith(items: items);
      }
    }
    return null;
  }

  Future<List<PurchaseOrder>> getPurchaseOrdersBySupplier(int supplierId) async {
    final orders = await getAllPurchaseOrders();
    return orders.where((order) => order.supplierId == supplierId).toList();
  }

  Future<List<PurchaseOrder>> getPurchaseOrdersByStatus(String status) async {
    final orders = await getAllPurchaseOrders();
    return orders.where((order) => order.status == status).toList();
  }

  Future<int> updatePurchaseOrder(PurchaseOrder order) async {
    await _load();
    final orders = List.from(_store['purchase_orders'] as List<dynamic>);
    final idx = orders.indexWhere((m) => m['id'] == order.id);
    if (idx == -1) return 0;
    orders[idx] = order.toMap();
    final items = List.from(_store['purchase_order_items'] as List<dynamic>)
        .where((m) => m['orderId'] != order.id)
        .toList();
    for (final item in order.items) {
      final itemId = item.id ?? _nextId('purchase_order_item');
      items.add(item.copyWith(id: itemId, orderId: order.id!).toMap());
    }
    _store['purchase_orders'] = orders;
    _store['purchase_order_items'] = items;
    await _save();
    _queueCloudSync();
    return order.id!;
  }

  Future<int> approvePurchaseOrder(
    int orderId,
    String approvedBy,
    String signatureData,
  ) async {
    await _load();
    final orders = List.from(_store['purchase_orders'] as List<dynamic>);
    final idx = orders.indexWhere((m) => m['id'] == orderId);
    if (idx == -1) return 0;
    final updated = Map<String, dynamic>.from(orders[idx] as Map)
      ..['status'] = 'approved'
      ..['approvedBy'] = approvedBy
      ..['signatureData'] = signatureData
      ..['approvalDate'] = DateTime.now().toIso8601String();
    orders[idx] = updated;
    _store['purchase_orders'] = orders;
    await _save();
    _queueCloudSync();
    return orderId;
  }

  Future<int> updatePurchaseOrderStatus(int orderId, String status) async {
    await _load();
    final orders = List.from(_store['purchase_orders'] as List<dynamic>);
    final idx = orders.indexWhere((m) => m['id'] == orderId);
    if (idx == -1) return 0;
    final updated = Map<String, dynamic>.from(orders[idx] as Map)..['status'] = status;
    orders[idx] = updated;
    _store['purchase_orders'] = orders;
    await _save();
    _queueCloudSync();
    return orderId;
  }

  Future<int> deletePurchaseOrder(int id) async {
    await _load();
    final orders = List.from(_store['purchase_orders'] as List<dynamic>);
    orders.removeWhere((m) => m['id'] == id);
    final items = List.from(_store['purchase_order_items'] as List<dynamic>)
        .where((m) => m['orderId'] != id)
        .toList();
    _store['purchase_orders'] = orders;
    _store['purchase_order_items'] = items;
    await _save();
    _queueCloudSync();
    return 1;
  }

  // -------------------- Inventory Movements --------------------

  Future<void> recordInventoryMovement(InventoryMovement movement) async {
    await _load();
    final movements = List.from(_store['inventory_movements'] as List<dynamic>);
    final id = movement.id ?? _nextId('movement');
    final map = movement.toMap()..['id'] = id;
    movements.add(map);
    _store['inventory_movements'] = movements;
    await _save();
  }

  Future<List<InventoryMovement>> getProductMovements(int productId) async {
    await _load();
    final List movements = _store['inventory_movements'] as List<dynamic>;
    final results = movements
        .where((m) => (m as Map)['productId'] == productId)
        .toList();
    results.sort(
      (a, b) =>
          (b['movementDate'] as String).compareTo(a['movementDate'] as String),
    );
    return results
        .map(
          (e) => InventoryMovement.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<InventoryMovement>> getProductMovementsByDateRange(
    int productId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final all = await getProductMovements(productId);
    return all
        .where(
          (m) =>
              m.movementDate.isAfter(
                startDate.subtract(const Duration(seconds: 1)),
              ) &&
              m.movementDate.isBefore(endDate.add(const Duration(seconds: 1))),
        )
        .toList();
  }

  Future<List<InventoryMovement>> getAllMovementsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    await _load();
    final List movements = _store['inventory_movements'] as List<dynamic>;
    final results = movements
        .map(
          (e) => InventoryMovement.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .where(
          (m) =>
              m.movementDate.isAfter(
                startDate.subtract(const Duration(seconds: 1)),
              ) &&
              m.movementDate.isBefore(endDate.add(const Duration(seconds: 1))),
        )
        .toList();
      results.sort((a, b) => b.movementDate.compareTo(a.movementDate));
      return results;
  }

  /// Replace all inventory movements with a restored set from cloud sync.
  /// The cloud backend stores a reduced movement payload, so quantityBefore
  /// and quantityAfter are approximated from the available quantity change.
  Future<void> replaceInventoryMovements(
    List<Map<String, dynamic>> movements,
  ) async {
    await _load();
    _store['inventory_movements'] = List<Map<String, dynamic>>.from(
      movements.map((movement) => Map<String, dynamic>.from(movement)),
    );
    await _save();
  }

  // -------------------- Camera Operations --------------------

  Future<int> insertCamera(Map<String, dynamic> camera) async {
    await _load();
    final id = camera['id'] is int
        ? camera['id'] as int
        : int.tryParse(camera['id']?.toString() ?? '') ?? _nextId('camera');
    _bumpCounter('camera', id);
    final cameras = List<Map<String, dynamic>>.from(
      (_store['cameras'] as List<dynamic>?) ?? [],
    );
    cameras.add({...camera, 'id': id});
    _store['cameras'] = cameras;
    await _save();
    _queueCloudSync();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCameras() async {
    await _load();
    return List<Map<String, dynamic>>.from(
      (_store['cameras'] as List<dynamic>?) ?? [],
    );
  }

  Future<int> updateCamera(int id, Map<String, dynamic> data) async {
    await _load();
    final cameras = List<Map<String, dynamic>>.from(
      (_store['cameras'] as List<dynamic>?) ?? [],
    );
    final index = cameras.indexWhere((c) => c['id'] == id);
    if (index >= 0) {
      cameras[index] = {...cameras[index], ...data};
      _store['cameras'] = cameras;
      await _save();
      _queueCloudSync();
      return 1;
    }
    return 0;
  }

  Future<int> deleteCamera(int id) async {
    await _load();
    final cameras = List<Map<String, dynamic>>.from(
      (_store['cameras'] as List<dynamic>?) ?? [],
    );
    cameras.removeWhere((c) => c['id'] == id);
    _store['cameras'] = cameras;
    await _save();
    await _deleteRemoteRecord('cameras', id);
    _queueCloudSync();
    return 1;
  }

  // -------------------- CCTV Timestamp Operations --------------------

  Future<int> insertCCTVTimestamp(Map<String, dynamic> timestamp) async {
    await _load();
    final id = timestamp['id'] is int
        ? timestamp['id'] as int
        : int.tryParse(timestamp['id']?.toString() ?? '') ??
            _nextId('cctv_timestamp');
    _bumpCounter('cctv_timestamp', id);
    final timestamps = List<Map<String, dynamic>>.from(
      (_store['cctv_timestamps'] as List<dynamic>?) ?? [],
    );
    timestamps.add({...timestamp, 'id': id});
    _store['cctv_timestamps'] = timestamps;
    await _save();
    _queueCloudSync();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllCCTVTimestamps() async {
    await _load();
    return List<Map<String, dynamic>>.from(
      (_store['cctv_timestamps'] as List<dynamic>?) ?? [],
    );
  }

  Future<int> deleteCCTVTimestamp(int id) async {
    await _load();
    final timestamps = List<Map<String, dynamic>>.from(
      (_store['cctv_timestamps'] as List<dynamic>?) ?? [],
    );
    timestamps.removeWhere((t) => t['id'] == id);
    _store['cctv_timestamps'] = timestamps;
    await _save();
    _queueCloudSync();
    return 1;
  }

  Future<int> deleteAllCCTVTimestamps() async {
    await _load();
    _store['cctv_timestamps'] = <Map<String, dynamic>>[];
    await _save();
    _queueCloudSync();
    return 1;
  }

  Future<int> updateCCTVTimestamp(int id, Map<String, dynamic> data) async {
    await _load();
    final timestamps = List<Map<String, dynamic>>.from(
      (_store['cctv_timestamps'] as List<dynamic>?) ?? [],
    );
    final index = timestamps.indexWhere((t) => t['id'] == id);
    if (index >= 0) {
      timestamps[index] = {...timestamps[index], ...data};
      _store['cctv_timestamps'] = timestamps;
      await _save();
      _queueCloudSync();
      return 1;
    }
    return 0;
  }

  // -------------------- Activity Log Operations --------------------

  Future<int> insertActivityLog(
    String type,
    String message, {
    Map<String, dynamic>? meta,
  }) async {
    await _load();
    final id = _nextId('activity_log');
    final logs = List<Map<String, dynamic>>.from(
      (_store['activity_logs'] as List<dynamic>?) ?? [],
    );
    logs.add({
      'id': id,
      'type': type,
      'message': message,
      'meta': meta != null ? jsonEncode(meta) : null,
      'createdAt': DateTime.now().toIso8601String(),
      'sent': 0,
    });
    _store['activity_logs'] = logs;
    await _save();
    _queueCloudSync();
    return id;
  }

  Future<void> replaceActivityLogs(List<Map<String, dynamic>> logs) async {
    await _load();
    _store['activity_logs'] = logs;
    var maxId = 0;
    for (final log in logs) {
      final id = int.tryParse(log['id']?.toString() ?? '') ?? 0;
      if (id > maxId) maxId = id;
    }
    if (maxId > 0) {
      _bumpCounter('activity_log', maxId);
    }
    await _save();
  }

  Future<List<Map<String, dynamic>>> fetchActivityLogs({
    String? type,
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    await _load();
    final logs = List<Map<String, dynamic>>.from(
      (_store['activity_logs'] as List<dynamic>?) ?? [],
    );
    final filtered = logs.where((row) {
      if (type != null && type.isNotEmpty && row['type'] != type) {
        return false;
      }
      final createdAt = DateTime.tryParse((row['createdAt'] ?? '').toString());
      if (createdAt == null) return false;
      if (from != null && createdAt.isBefore(from)) return false;
      if (to != null && createdAt.isAfter(to)) return false;
      return true;
    }).toList();
    filtered.sort(
      (a, b) => (b['createdAt'] ?? '').toString().compareTo(
        (a['createdAt'] ?? '').toString(),
      ),
    );
    return filtered.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> fetchUnsentActivityLogs({
    int limit = 200,
  }) async {
    await _load();
    final logs = List<Map<String, dynamic>>.from(
      (_store['activity_logs'] as List<dynamic>?) ?? [],
    );
    return logs.where((row) => (row['sent'] as int? ?? 0) == 0).take(limit).toList();
  }

  Future<void> markActivityLogsSent(List<int> ids) async {
    if (ids.isEmpty) return;
    await _load();
    final logs = List<Map<String, dynamic>>.from(
      (_store['activity_logs'] as List<dynamic>?) ?? [],
    );
    for (var i = 0; i < logs.length; i++) {
      if (ids.contains(logs[i]['id'])) {
        logs[i] = {...logs[i], 'sent': 1};
      }
    }
    _store['activity_logs'] = logs;
    await _save();
  }

  // -------------------- Damage Report Operations --------------------

  Future<int> insertDamageReport(Map<String, dynamic> report) async {
    await _load();
    final id = _nextId('damage_report');
    final reports = List<Map<String, dynamic>>.from(
      (_store['damage_reports'] as List<dynamic>?) ?? [],
    );
    reports.add({...report, 'id': id});
    _store['damage_reports'] = reports;
    await _save();
    return id;
  }

  Future<List<Map<String, dynamic>>> getAllDamageReports() async {
    await _load();
    return List<Map<String, dynamic>>.from(
      (_store['damage_reports'] as List<dynamic>?) ?? [],
    );
  }

  Future<List<Map<String, dynamic>>> getDamageReportsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final all = await getAllDamageReports();
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

    return all.where((report) {
      final dateStr = report['reportDate'] as String?;
      if (dateStr == null) return false;
      final date = DateTime.parse(dateStr);
      return (date.isAfter(adjustedStart) ||
              date.isAtSameMomentAs(adjustedStart)) &&
          (date.isBefore(adjustedEnd) || date.isAtSameMomentAs(adjustedEnd));
    }).toList();
  }

  // -------------------- Management --------------------

  Future<void> closeDatabase() async {
    // Nothing to do for localStorage
    return;
  }

  Future<void> resetDatabase() async {
    _store = {
      'products': <Map<String, dynamic>>[],
      'sales': <Map<String, dynamic>>[],
      'inventory_movements': <Map<String, dynamic>>[],
      'customers': <Map<String, dynamic>>[],
      'loyalty_ledger': <Map<String, dynamic>>[],
      'activity_logs': <Map<String, dynamic>>[],
      'cameras': <Map<String, dynamic>>[],
      'cctv_timestamps': <Map<String, dynamic>>[],
      'damage_reports': <Map<String, dynamic>>[],
      'counters': {
        'product': 0,
        'sale': 0,
        'movement': 0,
        'customer': 0,
        'ledger': 0,
        'activity_log': 0,
        'camera': 0,
        'cctv_timestamp': 0,
        'damage_report': 0,
      },
    };
    await _save();
  }

  Future<void> resetAllData() async {
    await resetDatabase();
  }

  Future<void> resetSalesData() async {
    await _load();
    _store['sales'] = <Map<String, dynamic>>[];
    _store['counters']['sale'] = 0;
    await _save();
  }
}
