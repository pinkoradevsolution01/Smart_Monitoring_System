// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' show window;

import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/inventory_movement.dart';
import '../models/customer.dart';
import '../models/loyalty_ledger_entry.dart';

/// A lightweight web-backed DatabaseService that persists to window.localStorage.
/// This provides a compatible API for web builds when sqflite is not available.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const _storageKey = 'pos_system_db_v1';

  Map<String, dynamic> _store = {
    'products': <Map<String, dynamic>>[],
    'sales': <Map<String, dynamic>>[],
    'inventory_movements': <Map<String, dynamic>>[],
    'customers': <Map<String, dynamic>>[],
    'loyalty_ledger': <Map<String, dynamic>>[],
    'counters': {
      'product': 0,
      'sale': 0,
      'movement': 0,
      'customer': 0,
      'ledger': 0,
    },
  };

  Future<void> _load() async {
    final raw = window.localStorage[_storageKey];
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _store = decoded;
      _store.putIfAbsent('products', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('sales', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('inventory_movements', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('customers', () => <Map<String, dynamic>>[]);
      _store.putIfAbsent('loyalty_ledger', () => <Map<String, dynamic>>[]);
      final counters = Map<String, dynamic>.from(
        _store['counters'] as Map? ?? const {},
      );
      counters.putIfAbsent('product', () => 0);
      counters.putIfAbsent('sale', () => 0);
      counters.putIfAbsent('movement', () => 0);
      counters.putIfAbsent('customer', () => 0);
      counters.putIfAbsent('ledger', () => 0);
      _store['counters'] = counters;
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

  // -------------------- Product Operations --------------------

  Future<int> insertProduct(Product product) async {
    await _load();
    final id = _nextId('product');
    final map = product.toMap()..['id'] = id;
    final List products = List.from(_store['products'] as List);
    products.add(map);
    _store['products'] = products;
    await _save();
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
    return 1;
  }

  Future<int> deleteProduct(int id) async {
    await _load();
    final List products = List.from(_store['products'] as List<dynamic>);
    final before = products.length;
    products.removeWhere((m) => m['id'] == id);
    _store['products'] = products;
    await _save();
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
    return Customer.fromMap(Map<String, dynamic>.from(updated));
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
    return saleId;
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

      return results.where((s) {
        final d = s.saleDate;
        return (d.isAfter(adjustedStart) ||
                d.isAtSameMomentAs(adjustedStart)) &&
            (d.isBefore(adjustedEnd) || d.isAtSameMomentAs(adjustedEnd));
      }).toList();
    }
    results.sort((a, b) => b.saleDate.compareTo(a.saleDate));
    return results;
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
      total += s.totalAmount;
    }
    return total;
  }

  Future<int> getTotalTransactions(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final sales = await getAllSales(startDate: start, endDate: end);
    return sales.length;
  }

  Future<double> getSalesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    double total = 0.0;
    for (final s in sales) {
      total += s.totalAmount;
    }
    return total;
  }

  Future<int> getTransactionCountForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sales = await getAllSales(startDate: startDate, endDate: endDate);
    return sales.length;
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

  // -------------------- Camera Operations --------------------

  Future<int> insertCamera(Map<String, dynamic> camera) async {
    await _load();
    final id = _nextId('camera');
    final cameras = List<Map<String, dynamic>>.from(
      (_store['cameras'] as List<dynamic>?) ?? [],
    );
    cameras.add({...camera, 'id': id});
    _store['cameras'] = cameras;
    await _save();
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
    return 1;
  }

  // -------------------- CCTV Timestamp Operations --------------------

  Future<int> insertCCTVTimestamp(Map<String, dynamic> timestamp) async {
    await _load();
    final id = _nextId('cctv_timestamp');
    final timestamps = List<Map<String, dynamic>>.from(
      (_store['cctv_timestamps'] as List<dynamic>?) ?? [],
    );
    timestamps.add({...timestamp, 'id': id});
    _store['cctv_timestamps'] = timestamps;
    await _save();
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
    return 1;
  }

  Future<int> deleteAllCCTVTimestamps() async {
    await _load();
    _store['cctv_timestamps'] = <Map<String, dynamic>>[];
    await _save();
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
      return 1;
    }
    return 0;
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
      'cameras': <Map<String, dynamic>>[],
      'cctv_timestamps': <Map<String, dynamic>>[],
      'damage_reports': <Map<String, dynamic>>[],
      'counters': {
        'product': 0,
        'sale': 0,
        'movement': 0,
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
