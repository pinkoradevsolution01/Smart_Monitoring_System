import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Utility to inspect database schema and data
class DatabaseInspector {
  static Future<void> inspectDatabase() async {
    final db = DatabaseService();
    final database = await db.database;

    debugPrint('═══════════════════════════════════════');
    debugPrint('📊 DATABASE INSPECTION REPORT');
    debugPrint('═══════════════════════════════════════');

    // Check database version
    final version = await database.getVersion();
    debugPrint('✅ Database Version: $version');

    // Check sale_items table schema
    debugPrint('\n📋 sale_items TABLE SCHEMA:');
    final tableInfo = await database.rawQuery('PRAGMA table_info(sale_items)');
    for (final column in tableInfo) {
      debugPrint(
        '   Column: ${column['name']} | Type: ${column['type']} | Nullable: ${column['notnull'] == 0 ? "YES" : "NO"}',
      );
    }

    // Check if shoeSize column exists
    final hasShoeSizeColumn = tableInfo.any((col) => col['name'] == 'shoeSize');
    if (hasShoeSizeColumn) {
      debugPrint('✅ shoeSize column EXISTS');
    } else {
      debugPrint('❌ shoeSize column MISSING - Run migration!');
    }

    // Check recent sales
    debugPrint('\n📦 RECENT SALES WITH ITEMS:');
    final sales = await database.rawQuery('''
      SELECT s.id, s.saleNumber, s.saleDate, 
             COUNT(si.id) as itemCount
      FROM sales s
      LEFT JOIN sale_items si ON s.id = si.saleId
      GROUP BY s.id
      ORDER BY s.saleDate DESC
      LIMIT 5
    ''');

    for (final sale in sales) {
      debugPrint('\n   Sale #${sale['saleNumber']} (ID: ${sale['id']})');
      debugPrint('   Date: ${sale['saleDate']}');
      debugPrint('   Items: ${sale['itemCount']}');

      // Get items for this sale
      final items = await database.rawQuery(
        '''
        SELECT productName, quantity, shoeSize
        FROM sale_items
        WHERE saleId = ?
      ''',
        [sale['id']],
      );

      for (final item in items) {
        final shoeSize = item['shoeSize'];
        if (shoeSize != null && shoeSize.toString().isNotEmpty) {
          debugPrint(
            '      ✅ ${item['productName']} x${item['quantity']} - Size: $shoeSize',
          );
        } else {
          debugPrint(
            '      ❌ ${item['productName']} x${item['quantity']} - NO SIZE',
          );
        }
      }
    }

    // Check products with shoe sizes
    debugPrint('\n👟 PRODUCTS WITH SHOE SIZES:');
    final products = await database.rawQuery('''
      SELECT id, name, sizeType, shoeSizes
      FROM products
      WHERE shoeSizes IS NOT NULL AND shoeSizes != ''
      LIMIT 10
    ''');

    if (products.isEmpty) {
      debugPrint('   ❌ No shoe products found in database');
    } else {
      for (final product in products) {
        debugPrint('   ${product['name']} (ID: ${product['id']})');
        debugPrint('      Type: ${product['sizeType']}');
        debugPrint('      Sizes: ${product['shoeSizes']}');
      }
    }

    debugPrint('\n═══════════════════════════════════════');
    debugPrint('📊 END OF INSPECTION REPORT');
    debugPrint('═══════════════════════════════════════\n');
  }

  /// Check if a specific sale has shoe size data
  static Future<void> inspectSale(int saleId) async {
    final db = DatabaseService();
    final database = await db.database;

    debugPrint('\n🔍 INSPECTING SALE ID: $saleId');

    final sale = await database.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
    );
    if (sale.isEmpty) {
      debugPrint('❌ Sale not found');
      return;
    }

    final saleData = sale.first;
    debugPrint('Sale #${saleData['saleNumber']}');
    debugPrint('Date: ${saleData['saleDate']}');
    debugPrint('Cashier: ${saleData['cashierName']}');
    debugPrint('Total: ${saleData['totalAmount']}');

    final items = await database.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
    debugPrint('\nItems (${items.length}):');
    for (final item in items) {
      debugPrint('  - ${item['productName']}');
      debugPrint('    Quantity: ${item['quantity']}');
      debugPrint('    Price: ${item['unitPrice']}');
      debugPrint('    shoeSize: ${item['shoeSize'] ?? "NULL"}');
    }
  }
}
