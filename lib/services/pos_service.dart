import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/inventory_movement.dart';
import '../models/shoe_size.dart';
import 'database_service.dart';
import 'customer_service.dart';
import '../utils/currency_formatter.dart';
import 'supabase_sync_service.dart';
import 'demo_session_service.dart';

class POSService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  SupabaseSyncService get _syncService => GetIt.I<SupabaseSyncService>();

  final List<CartItem> _cart = [];
  List<Product> _products = [];
  List<Sale> _recentSales = [];

  bool get _isDemoSession => DemoSessionService.instance.isActive;

  // Never expose cached live records if a demo route is reached accidentally.
  List<CartItem> get cart => _isDemoSession ? const <CartItem>[] : _cart;
  List<Product> get products => _isDemoSession ? const <Product>[] : _products;
  List<Sale> get recentSales => _isDemoSession ? const <Sale>[] : _recentSales;
  DatabaseService get databaseService => _databaseService;

  double get cartSubtotal => cart.fold(0, (sum, item) => sum + item.subtotal);
  double get cartDiscount =>
      cart.fold(0, (sum, item) => sum + item.discountAmount);
  double get cartTotal => cart.fold(0, (sum, item) => sum + item.total);

  void _requireLiveDataAccess() {
    if (_isDemoSession) {
      throw StateError(
        'Production POS operations are disabled during Client Demonstration Mode.',
      );
    }
  }

  // Initialize the POS service
  Future<void> initialize() async {
    await loadProducts();
    // Owner dashboards, setup progress, and SmartPlus all rely on the recent
    // transaction cache. Load it on startup instead of waiting for a new sale.
    await loadRecentSales();
    await _checkAndPerformDailyBackup();
  }

  /// Check if daily backup is needed and create one
  Future<void> _checkAndPerformDailyBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupDate = prefs.getString('last_backup_date');
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Create backup if no backup today
      if (lastBackupDate != today) {
        debugPrint('📦 Creating daily backup...');
        await _databaseService.createBackup();
        await _databaseService.cleanupOldBackups(keepCount: 7);
        await prefs.setString('last_backup_date', today);
        debugPrint('✅ Daily backup completed');
      }
    } catch (e) {
      debugPrint('⚠️ Daily backup failed: $e');
    }
  }

  // Product operations
  Future<void> loadProducts() async {
    if (_isDemoSession) {
      notifyListeners();
      return;
    }
    _products = await _databaseService.getAllProducts();
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    _requireLiveDataAccess();
    await _databaseService.insertProduct(product);
    await loadProducts();
    _queueCloudSync();
  }

  Future<void> updateProduct(Product product) async {
    _requireLiveDataAccess();
    await _databaseService.updateProduct(product);
    await loadProducts();
    _queueCloudSync();
  }

  Future<void> deleteProduct(int id) async {
    _requireLiveDataAccess();
    await _databaseService.deleteProduct(id);
    await loadProducts();
    _queueCloudSync();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    if (_isDemoSession) return null;
    return _databaseService.getProductByBarcode(barcode);
  }

  Future<List<Product>> getLowStockProducts() async {
    if (_isDemoSession) return const <Product>[];
    return _databaseService.getLowStockProducts();
  }

  // Cart operations
  void addToCart(
    Product product, {
    int quantity = 1,
    ShoeSize? selectedShoeSize,
  }) {
    if (_isDemoSession) return;
    // For shoe products, check if same size already in cart
    final existingIndex = _cart.indexWhere(
      (item) =>
          item.product.id == product.id &&
          (selectedShoeSize == null ||
              item.selectedShoeSize?.usSize == selectedShoeSize.usSize),
    );

    if (existingIndex >= 0) {
      final existingItem = _cart[existingIndex];
      _cart[existingIndex] = CartItem(
        product: product,
        quantity: existingItem.quantity + quantity,
        discount: existingItem.discount,
        selectedShoeSize: selectedShoeSize ?? existingItem.selectedShoeSize,
      );
    } else {
      _cart.add(
        CartItem(
          product: product,
          quantity: quantity,
          selectedShoeSize: selectedShoeSize,
        ),
      );
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (_isDemoSession) return;
    if (index >= 0 && index < _cart.length) {
      _cart.removeAt(index);
      notifyListeners();
    }
  }

  void updateCartItem(int index, int quantity) {
    if (_isDemoSession) return;
    if (index >= 0 && index < _cart.length && quantity > 0) {
      final item = _cart[index];
      _cart[index] = item.copyWith(quantity: quantity);
      notifyListeners();
    }
  }

  void updateCartItemDiscount(int index, double discount) {
    if (_isDemoSession) return;
    if (index >= 0 &&
        index < _cart.length &&
        discount >= 0 &&
        discount <= 100) {
      final item = _cart[index];
      _cart[index] = item.copyWith(discount: discount);
      notifyListeners();
    }
  }

  void clearCart() {
    if (_isDemoSession) return;
    _cart.clear();
    notifyListeners();
  }

  // Sale operations
  Future<bool> processSale({
    required String paymentMethod,
    required String cashierName,
    double taxRate = 0.0,
    String? notes,
    String? referenceCode,
    String? imagePath,
    TransactionType transactionType = TransactionType.pos,
    bool isReservation = false,
    double? reservationFee,
    int? customerId,
    String? customerName,
    int loyaltyPointsEarned = 0,
    int loyaltyPointsRedeemed = 0,
    double loyaltyDiscountAmount = 0.0,
  }) async {
    _requireLiveDataAccess();
    if (_cart.isEmpty) return false;

    // Calculate totals
    final subtotal = cartSubtotal;
    final discountAmount = (cartDiscount + loyaltyDiscountAmount)
        .clamp(0.0, subtotal)
        .toDouble();

    if (loyaltyDiscountAmount > 0 &&
        subtotal < CustomerService.minPurchaseAmount) {
      throw Exception(
        'Loyalty redemption requires a minimum purchase of ${AppCurrency.peso(CustomerService.minPurchaseAmount)}.',
      );
    }

    final taxableAmount = subtotal - discountAmount;
    final taxAmount = taxableAmount * taxRate;
    final totalAmount = taxableAmount + taxAmount;

    // Generate sale number
    final saleNumber = 'SAL${DateTime.now().millisecondsSinceEpoch}';

    // Create sale items
    List<SaleItem> saleItems = [];
    for (var i = 0; i < _cart.length; i++) {
      final cartItem = _cart[i];
      final shoeSize = cartItem.selectedShoeSize?.usSize;
      debugPrint(
        '💾 Creating SaleItem: ${cartItem.product.name}, shoeSize: $shoeSize',
      );
      saleItems.add(
        SaleItem(
          saleId: 0, // Will be set by database
          productId: cartItem.product.id!,
          productName: cartItem.product.name,
          quantity: cartItem.quantity,
          unitPrice: cartItem.product.sellingPrice,
          discount: cartItem.discountAmount,
          subtotal: cartItem.subtotal,
          shoeSize: shoeSize,
        ),
      );
    }

    // Create sale object
    final sale = Sale(
      saleNumber: saleNumber,
      items: saleItems,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      status: isReservation ? SaleStatus.pending : SaleStatus.completed,
      notes: notes,
      cashierName: cashierName,
      saleDate: DateTime.now(),
      referenceCode: referenceCode,
      imagePath: imagePath,
      transactionType: transactionType,
      reservationFee: reservationFee,
      customerId: customerId,
      customerName: customerName,
      loyaltyPointsEarned: loyaltyPointsEarned,
      loyaltyPointsRedeemed: loyaltyPointsRedeemed,
    );

    try {
      if (customerId != null &&
          sale.status == SaleStatus.completed &&
          loyaltyPointsRedeemed > 0) {
        final redeemed = await CustomerService().redeemPoints(
          customerId: customerId,
          points: loyaltyPointsRedeemed,
          notes: sale.saleNumber,
        );
        if (!redeemed) {
          throw Exception('Unable to redeem loyalty points for this customer.');
        }
      }

      // Insert sale to database
      final saleId = await _databaseService.insertSale(sale);

      if (customerId != null &&
          sale.status == SaleStatus.completed &&
          loyaltyPointsEarned > 0) {
        await CustomerService().awardPoints(
          customerId: customerId,
          saleId: saleId,
          points: loyaltyPointsEarned,
          notes: sale.saleNumber,
        );
      }

      // Update inventory for each item
      for (final item in _cart) {
        debugPrint('\n🛒 Processing cart item:');
        debugPrint('   Product: ${item.product.name}');
        debugPrint('   Product ID: ${item.product.id}');
        debugPrint('   Has shoe variants: ${item.product.hasShoeVariants}');
        debugPrint(
          '   Selected shoe size: ${item.selectedShoeSize?.usSize ?? "null"}',
        );
        debugPrint('   Quantity: ${item.quantity}');

        // Get fresh product data from database to ensure we have latest shoeSizes
        final freshProduct = await _databaseService.getProductById(
          item.product.id!,
        );
        if (freshProduct == null) {
          throw Exception('Product not found: ${item.product.id}');
        }

        debugPrint(
          '   Fresh product has shoe variants: ${freshProduct.hasShoeVariants}',
        );
        debugPrint(
          '   Fresh product shoeSizes count: ${freshProduct.shoeSizes?.length ?? 0}',
        );

        int newQuantity;
        Product updatedProduct;

        // Handle shoe products with size variants
        if (freshProduct.hasShoeVariants && item.selectedShoeSize != null) {
          debugPrint('🔍 Updating shoe product: ${freshProduct.name}');
          debugPrint('   Selected size: ${item.selectedShoeSize!.usSize}');
          debugPrint('   Quantity to deduct: ${item.quantity}');

          // Update specific shoe size quantity
          final updatedShoeSizes = freshProduct.shoeSizes!.map((size) {
            if (size.usSize == item.selectedShoeSize!.usSize) {
              final oldQty = size.quantity;
              final newQty = size.quantity - item.quantity;
              debugPrint('   Size ${size.usSize}: $oldQty → $newQty');
              return ShoeSize(
                usSize: size.usSize,
                ukSize: size.ukSize,
                euSize: size.euSize,
                cmSize: size.cmSize,
                quantity: newQty,
              );
            }
            return size;
          }).toList();

          // Calculate new total quantity
          newQuantity = updatedShoeSizes.fold(
            0,
            (sum, size) => sum + size.quantity,
          );

          debugPrint('   New total quantity: $newQuantity');

          updatedProduct = Product(
            id: freshProduct.id,
            barcode: freshProduct.barcode,
            name: freshProduct.name,
            description: freshProduct.description,
            buyingPrice: freshProduct.buyingPrice,
            sellingPrice: freshProduct.sellingPrice,
            quantity: newQuantity,
            reorderLevel: freshProduct.reorderLevel,
            category: freshProduct.category,
            imagePath: freshProduct.imagePath,
            createdAt: freshProduct.createdAt,
            shoeSizes: updatedShoeSizes,
            sizeType: freshProduct.sizeType,
          );
        } else {
          // Regular product - just decrement quantity
          newQuantity = freshProduct.quantity - item.quantity;
          updatedProduct = Product(
            id: freshProduct.id,
            barcode: freshProduct.barcode,
            name: freshProduct.name,
            description: freshProduct.description,
            buyingPrice: freshProduct.buyingPrice,
            sellingPrice: freshProduct.sellingPrice,
            quantity: newQuantity,
            reorderLevel: freshProduct.reorderLevel,
            category: freshProduct.category,
            imagePath: freshProduct.imagePath,
            createdAt: freshProduct.createdAt,
            shoeSizes: freshProduct.shoeSizes,
            sizeType: freshProduct.sizeType,
          );
        }

        // Update product
        await _databaseService.updateProduct(updatedProduct);

        // Record inventory movement
        await _databaseService.recordInventoryMovement(
          InventoryMovement(
            productId: freshProduct.id!,
            quantityBefore: freshProduct.quantity,
            quantityAfter: newQuantity,
            quantityChanged: -item.quantity,
            movementType: 'sale',
            reference: saleNumber,
            reason: item.selectedShoeSize != null
                ? 'Sold via POS (Size: ${item.selectedShoeSize!.usSize})'
                : 'Sold via POS',
            movementDate: DateTime.now(),
          ),
        );
      }

      // Clear cart and reload products
      _cart.clear();
      await loadProducts();
      await loadRecentSales();
      _queueCloudSync();
      notifyListeners();
      debugPrint('✅ Sale completed successfully');
      return true;
    } catch (e, stackTrace) {
      // Log error for debugging
      debugPrint('❌ Error processing sale: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Reporting operations
  Future<void> loadRecentSales({int days = 7}) async {
    if (_isDemoSession) {
      notifyListeners();
      return;
    }
    final startDate = DateTime.now().subtract(Duration(days: days));
    final endDate = DateTime.now();
    final recent = await _databaseService.getAllSales(
      startDate: startDate,
      endDate: endDate,
    );
    _recentSales = recent..sort((a, b) => b.saleDate.compareTo(a.saleDate));
    notifyListeners();
  }

  /// Cancel a sale with owner authorization
  Future<bool> cancelSale({
    required int saleId,
    required String reason,
    required String cancelledBy,
  }) async {
    _requireLiveDataAccess();
    try {
      // Get the sale to cancel
      final sales = await _databaseService.getAllSales();
      final sale = sales.firstWhere(
        (s) => s.id == saleId,
        orElse: () => throw Exception('Sale not found'),
      );

      // Check if already cancelled
      if (sale.status == SaleStatus.cancelled) {
        return false;
      }

      // Restore inventory for each item
      for (final item in sale.items) {
        final product = await _databaseService.getProductById(item.productId);
        if (product != null) {
          final newQuantity = product.quantity + item.quantity;

          // Update product quantity
          await _databaseService.updateProduct(
            product.copyWith(quantity: newQuantity),
          );

          // Record inventory movement for the restoration
          await _databaseService.recordInventoryMovement(
            InventoryMovement(
              productId: product.id!,
              quantityBefore: product.quantity,
              quantityAfter: newQuantity,
              quantityChanged: item.quantity,
              movementType: 'adjustment',
              reference: sale.saleNumber,
              reason: 'Sale Cancelled: $reason',
              movementDate: DateTime.now(),
            ),
          );
        }
      }

      // Update sale status to cancelled
      final cancelledSale = sale.copyWith(
        status: SaleStatus.cancelled,
        cancelledReason: reason,
        cancelledBy: cancelledBy,
        cancelledAt: DateTime.now(),
      );

      await _databaseService.updateSale(cancelledSale);

      // Reload data
      await loadProducts();
      await loadRecentSales();
      _queueCloudSync();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error cancelling sale: $e');
      return false;
    }
  }

  Future<double> getDailySales(DateTime date) async {
    return _databaseService.getDailySales(date);
  }

  Future<int> getTotalTransactions(DateTime date) async {
    return _databaseService.getTotalTransactions(date);
  }

  Future<List<Sale>> getSalesReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _databaseService.getAllSales(startDate: startDate, endDate: endDate);
  }

  Future<double> getTotalRevenue(DateTime startDate, DateTime endDate) async {
    final sales = await _databaseService.getAllSales(
      startDate: startDate,
      endDate: endDate,
    );

    double total = 0;
    for (final sale in sales) {
      // Only count completed sales, exclude cancelled sales
      if (sale.status == SaleStatus.completed) {
        total += sale.totalAmount;
      }
    }
    return total;
  }

  Future<int> getTotalItemsSold(DateTime startDate, DateTime endDate) async {
    final sales = await _databaseService.getAllSales(
      startDate: startDate,
      endDate: endDate,
    );

    int total = 0;
    for (final sale in sales) {
      // Only count completed sales, exclude cancelled sales
      if (sale.status == SaleStatus.completed) {
        total += sale.itemCount;
      }
    }
    return total;
  }

  /// Clear all POS data (products, sales, cart)
  Future<void> clearAllData() async {
    _cart.clear();
    _products.clear();
    _recentSales.clear();

    // Clear all data from database
    await _databaseService.clearAllData();

    notifyListeners();
  }

  void _queueCloudSync() {
    if (!_syncService.isConfigured) {
      return;
    }
    _syncService.queuePushAllData();
  }
}
