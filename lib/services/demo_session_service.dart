import 'package:flutter/foundation.dart';

/// Isolated, process-memory-only state for Client Demonstration Mode.
///
/// This deliberately has no database, preferences, API, or sync dependency.
/// It is also used by the data and sync layers as a hard safety boundary.
class DemoSessionService extends ChangeNotifier {
  DemoSessionService._();

  static final DemoSessionService instance = DemoSessionService._();

  bool _isActive = false;
  String? _role;
  int _completedSales = 12;
  final List<DemoProduct> _products = [];

  bool get isActive => _isActive;
  String? get role => _role;
  int get completedSales => _completedSales;
  List<DemoProduct> get products => List.unmodifiable(_products);
  double get demoRevenue => _completedSales * 248.75;

  void start(String role) {
    _isActive = true;
    _role = role;
    _completedSales = 12;
    _products
      ..clear()
      ..addAll(const [
        DemoProduct(id: 'demo-1', name: 'Classic T-Shirt', price: 299, stock: 24),
        DemoProduct(id: 'demo-2', name: 'Everyday Tote Bag', price: 450, stock: 7),
        DemoProduct(id: 'demo-3', name: 'Canvas Sneakers', price: 1299, stock: 0),
        DemoProduct(id: 'demo-4', name: 'Insulated Bottle', price: 375, stock: 15),
      ]);
    notifyListeners();
  }

  /// Simulates a sale only inside the in-memory demonstration dataset.
  void simulateSale() {
    if (!_isActive) return;
    final product = _products.firstWhere(
      (item) => item.stock > 0,
      orElse: () => _products.first,
    );
    if (product.stock <= 0) return;
    final index = _products.indexWhere((item) => item.id == product.id);
    _products[index] = product.copyWith(stock: product.stock - 1);
    _completedSales++;
    notifyListeners();
  }

  /// Simulates a stock adjustment only inside the in-memory dataset.
  void restock(String productId) {
    if (!_isActive) return;
    final index = _products.indexWhere((item) => item.id == productId);
    if (index < 0) return;
    final product = _products[index];
    _products[index] = product.copyWith(stock: product.stock + 5);
    notifyListeners();
  }

  /// Removes every demo-only record when leaving the preview.
  void end() {
    _isActive = false;
    _role = null;
    _completedSales = 0;
    _products.clear();
    notifyListeners();
  }
}

class DemoProduct {
  final String id;
  final String name;
  final double price;
  final int stock;

  const DemoProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });

  DemoProduct copyWith({int? stock}) => DemoProduct(
    id: id,
    name: name,
    price: price,
    stock: stock ?? this.stock,
  );
}
