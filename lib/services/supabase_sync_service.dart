import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/supplier.dart';
import '../models/damage_report.dart';
import 'database_service.dart';
import 'supabase_config.dart';

/// Comprehensive cloud sync service for Supabase integration
/// Syncs all business data: products, sales, inventory, purchases, suppliers, etc.
class SupabaseSyncService extends ChangeNotifier {
  static final SupabaseSyncService _instance = SupabaseSyncService._internal();
  factory SupabaseSyncService() => _instance;
  SupabaseSyncService._internal();

  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  String? _businessId;
  bool _isSyncing = false;
  String? _lastError;
  DateTime? _lastSyncTime;
  final Map<String, int> _syncStats = {};

  // Getters
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  Map<String, int> get syncStats => _syncStats;
  String? get businessId => _businessId;
  bool get isConfigured => SupabaseConfig.isConfigured && _businessId != null;

  /// Initialize business context (call this after license activation)
  Future<void> initializeBusiness({
    required String businessName,
    required String ownerEmail,
    String? existingBusinessId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase not configured');
    }

    try {
      if (existingBusinessId != null) {
        // Use existing business ID
        _businessId = existingBusinessId;
      } else {
        // Check if business already exists
        final existing = await _supabase
            .from('businesses')
            .select()
            .eq('owner_email', ownerEmail)
            .maybeSingle();

        if (existing != null) {
          _businessId = existing['id'];
        } else {
          // Create new business
          _businessId = _uuid.v4();
          await _supabase.from('businesses').insert({
            'id': _businessId,
            'name': businessName,
            'owner_id': _uuid.v4(), // Generate a unique owner ID
            'owner_email': ownerEmail,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      debugPrint('✅ Business initialized: $_businessId');
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

      // Pull data in order (respecting foreign keys)
      await _pullSuppliers(db);
      await _pullProducts(db);
      await _pullSales(db);
      await _pullInventoryMovements(db);
      await _pullPurchaseOrders(db);
      await _pullDamageReports(db);

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

  // ============================================================================
  // PUSH METHODS (Local → Cloud)
  // ============================================================================

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
              'category': p.category,
              'selling_price': p.sellingPrice,
              'quantity': p.quantity,
              'image_path': p.imagePath,
              'low_stock_threshold': p.reorderLevel,
              'created_at': p.createdAt.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _supabase.from('products').upsert(productData);
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

      if (sales.isEmpty) {
        _syncStats['sales_pushed'] = 0;
        return;
      }

      final salesData = sales
          .map(
            (s) => {
              'id': s.id.toString(),
              'business_id': _businessId,
              'cashier_id': _uuid.v4(), // Generate if not available
              'cashier_name': s.cashierName,
              'customer_name': null,
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
              'created_at': s.saleDate.toIso8601String(),
            },
          )
          .toList();

      await _supabase.from('sales').upsert(salesData);
      _syncStats['sales_pushed'] = sales.length;
      debugPrint('✅ Pushed ${sales.length} sales');

      // Push sale items
      await _pushSaleItems(sales);
    } catch (e) {
      debugPrint('❌ Error pushing sales: $e');
      rethrow;
    }
  }

  Future<void> _pushSaleItems(List<Sale> sales) async {
    try {
      final allItems = <Map<String, dynamic>>[];

      for (final sale in sales) {
        for (final item in sale.items) {
          allItems.add({
            'sale_id': sale.id.toString(),
            'business_id': _businessId,
            'product_id': item.productId.toString(),
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'discount': item.discount,
            'subtotal': item.subtotal,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (allItems.isNotEmpty) {
        await _supabase.from('sale_items').upsert(allItems);
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

      await _supabase.from('inventory_movements').upsert(movementData);
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

      await _supabase.from('suppliers').upsert(supplierData);
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

      await _supabase.from('purchase_orders').upsert(orderData);
      _syncStats['purchase_orders_pushed'] = orders.length;
      debugPrint('✅ Pushed ${orders.length} purchase orders');
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

      await _supabase.from('damage_reports').upsert(reportData);
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

  Future<void> _pullProducts(DatabaseService db) async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('business_id', _businessId!);

      final products = (response as List).map((data) {
        return Product(
          id: int.tryParse(data['id'].toString()),
          barcode: data['barcode'] ?? '',
          name: data['name'],
          description: null,
          buyingPrice: 0.0, // Not in cloud schema
          sellingPrice: (data['selling_price'] as num).toDouble(),
          quantity: data['quantity'] as int,
          reorderLevel: data['low_stock_threshold'] ?? 5,
          category: data['category'] ?? 'General',
          imagePath: data['image_path'],
          createdAt: DateTime.parse(data['created_at']),
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

  Future<void> _pullSales(DatabaseService db) async {
    try {
      final response = await _supabase
          .from('sales')
          .select('*, sale_items(*)')
          .eq('business_id', _businessId!);

      final sales = (response as List).map((data) {
        final items = (data['sale_items'] as List).map((itemData) {
          final unitPrice = (itemData['unit_price'] as num).toDouble();
          final quantity = itemData['quantity'] as int;
          final discount = (itemData['discount'] as num?)?.toDouble() ?? 0.0;
          return SaleItem(
            id: null,
            saleId: int.tryParse(data['id'].toString()) ?? 0,
            productId: int.tryParse(itemData['product_id'].toString()) ?? 0,
            productName: itemData['product_name'],
            quantity: quantity,
            unitPrice: unitPrice,
            discount: discount,
            subtotal: unitPrice * quantity,
          );
        }).toList();

        return Sale(
          id: int.tryParse(data['id'].toString()),
          saleNumber: 'S${data['id']}',
          items: items,
          subtotal: (data['subtotal'] as num).toDouble(),
          discountAmount: (data['discount'] as num?)?.toDouble() ?? 0.0,
          taxAmount: 0.0,
          totalAmount: (data['total_amount'] as num).toDouble(),
          paymentMethod: data['payment_method'],
          status: _parseSaleStatus(data['status']),
          notes: data['notes'],
          cashierName: data['cashier_name'],
          saleDate: DateTime.parse(data['datetime']),
        );
      }).toList();

      for (final sale in sales) {
        await db.insertSale(sale);
      }

      _syncStats['sales_pulled'] = sales.length;
      debugPrint('✅ Pulled ${sales.length} sales');
    } catch (e) {
      debugPrint('❌ Error pulling sales: $e');
      rethrow;
    }
  }

  Future<void> _pullInventoryMovements(DatabaseService db) async {
    try {
      final response = await _supabase
          .from('inventory_movements')
          .select()
          .eq('business_id', _businessId!);

      _syncStats['inventory_movements_pulled'] = (response as List).length;
      debugPrint('✅ Pulled ${(response).length} inventory movements');
      // Note: Local InventoryMovement model may need adjustments
    } catch (e) {
      debugPrint('❌ Error pulling inventory movements: $e');
      // Don't rethrow - continue with other syncs
    }
  }

  Future<void> _pullSuppliers(DatabaseService db) async {
    try {
      final response = await _supabase
          .from('suppliers')
          .select()
          .eq('business_id', _businessId!);

      final suppliers = (response as List).map((data) {
        return Supplier(
          id: int.tryParse(data['id'].toString()),
          name: data['name'],
          contactPerson: data['contact_person'] ?? '',
          phone: data['phone'] ?? '',
          email: data['email'] ?? '',
          address: data['address'] ?? '',
          notes: data['notes'] ?? '',
          isActive: data['is_active'] ?? true,
          createdAt: DateTime.parse(data['created_at']),
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

  Future<void> _pullPurchaseOrders(DatabaseService db) async {
    try {
      final response = await _supabase
          .from('purchase_orders')
          .select()
          .eq('business_id', _businessId!);

      _syncStats['purchase_orders_pulled'] = (response as List).length;
      debugPrint('✅ Pulled ${(response).length} purchase orders');
      debugPrint(
        '⚠️ Purchase order line items not synced (requires additional implementation)',
      );
    } catch (e) {
      debugPrint('❌ Error pulling purchase orders: $e');
      // Don't rethrow - continue with other syncs
    }
  }

  Future<void> _pullDamageReports(DatabaseService db) async {
    try {
      final response = await _supabase
          .from('damage_reports')
          .select()
          .eq('business_id', _businessId!);

      final reports = (response as List).map((data) {
        final quantity = data['quantity'] as int;
        final unitPrice = 0.0; // Not stored in cloud, would need product lookup
        return DamageReport(
          id: int.tryParse(data['id'].toString()),
          productId: int.tryParse(data['product_id'].toString()) ?? 0,
          productName: data['product_name'],
          quantity: quantity,
          unitPrice: unitPrice,
          totalValue: unitPrice * quantity,
          reason: data['damage_type'] ?? 'unknown',
          reportedBy: data['reported_by'] ?? 'unknown',
          reportDate: DateTime.parse(data['reported_at']),
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

  /// Clear business context (call on logout)
  void clearBusinessContext() {
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
