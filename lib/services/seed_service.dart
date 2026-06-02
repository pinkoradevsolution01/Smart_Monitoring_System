import '../models/product.dart';
import 'database_service.dart';

/// SeedService provides a convenient method to populate the database with sample products
/// for development and testing purposes. This allows developers and testers to quickly
/// set up a working POS system without manually adding each product.
class SeedService {
  static final DatabaseService _db = DatabaseService();

  /// Seeds the database with sample products.
  /// Returns true if seeding was successful, false otherwise.
  static Future<bool> seedSampleProducts() async {
    try {
      // Check if products already exist to avoid duplicates
      final existing = await _db.getAllProducts();
      if (existing.isNotEmpty) {
        // ignore: avoid_print
        print(
          'Database already has ${existing.length} products. Skipping seed.',
        );
        return false;
      }

      // Sample product data
      final sampleProducts = [
        Product(
          barcode: 'RTW001',
          name: 'Classic T-Shirt',
          description: 'High-quality cotton t-shirt',
          buyingPrice: 150.0,
          sellingPrice: 299.0,
          quantity: 50,
          reorderLevel: 10,
          category: 'Clothing',
          createdAt: DateTime.now(),
        ),
        Product(
          barcode: 'RTW002',
          name: 'Casual Jeans',
          description: 'Blue denim jeans',
          buyingPrice: 250.0,
          sellingPrice: 599.0,
          quantity: 30,
          reorderLevel: 8,
          category: 'Clothing',
          createdAt: DateTime.now(),
        ),
        Product(
          barcode: 'RTW003',
          name: 'Summer Dress',
          description: 'Lightweight floral dress',
          buyingPrice: 300.0,
          sellingPrice: 749.0,
          quantity: 20,
          reorderLevel: 5,
          category: 'Clothing',
          createdAt: DateTime.now(),
        ),
        Product(
          barcode: 'ACC001',
          name: 'Sports Cap',
          description: 'Adjustable sports cap',
          buyingPrice: 80.0,
          sellingPrice: 199.0,
          quantity: 100,
          reorderLevel: 20,
          category: 'Accessories',
          createdAt: DateTime.now(),
        ),
        Product(
          barcode: 'ACC002',
          name: 'Crossbody Bag',
          description: 'Practical crossbody shoulder bag',
          buyingPrice: 200.0,
          sellingPrice: 449.0,
          quantity: 15,
          reorderLevel: 3,
          category: 'Accessories',
          createdAt: DateTime.now(),
        ),
        Product(
          barcode: 'SHOE001',
          name: 'Running Shoes',
          description: 'Comfortable running footwear',
          buyingPrice: 350.0,
          sellingPrice: 899.0,
          quantity: 25,
          reorderLevel: 5,
          category: 'Footwear',
          createdAt: DateTime.now(),
        ),
        Product(
          barcode: 'SHOE002',
          name: 'Casual Sneakers',
          description: 'Versatile everyday sneakers',
          buyingPrice: 300.0,
          sellingPrice: 749.0,
          quantity: 35,
          reorderLevel: 8,
          category: 'Footwear',
          createdAt: DateTime.now(),
        ),
        Product(
          barcode: 'ACC003',
          name: 'Leather Belt',
          description: 'Premium quality leather belt',
          buyingPrice: 120.0,
          sellingPrice: 299.0,
          quantity: 40,
          reorderLevel: 10,
          category: 'Accessories',
          createdAt: DateTime.now(),
        ),
      ];

      // Insert all sample products
      for (final product in sampleProducts) {
        await _db.insertProduct(product);
      }

      // ignore: avoid_print
      print('Successfully seeded ${sampleProducts.length} sample products');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('Error seeding database: $e');
      return false;
    }
  }

  /// Clear all products from the database (use with caution - mainly for testing)
  static Future<void> clearAllProducts() async {
    try {
      final products = await _db.getAllProducts();
      for (final product in products) {
        await _db.deleteProduct(product.id!);
      }
      // ignore: avoid_print
      print('Cleared all products from database');
    } catch (e) {
      // ignore: avoid_print
      print('Error clearing products: $e');
    }
  }
}
