import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/pos_service.dart';
import 'package:get_it/get_it.dart';

/// Comprehensive diagnostic tool for shoe size feature
class ShoeSizeDiagnostic {
  static Future<String> runFullDiagnostic() async {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('🔍 SHOE SIZE FEATURE DIAGNOSTIC');
    buffer.writeln('═══════════════════════════════════════\n');

    try {
      final db = DatabaseService();
      final database = await db.database;

      // 1. Check database version
      final versionResult = await database.rawQuery('PRAGMA user_version');
      final version = versionResult.first['user_version'] as int;
      buffer.writeln('1️⃣ DATABASE VERSION');
      buffer.writeln('   Version: $version');
      if (version >= 17) {
        buffer.writeln(
          '   ✅ PASS - Version 17+ (shoeSize column should exist)',
        );
      } else {
        buffer.writeln('   ❌ FAIL - Version is less than 17!');
        buffer.writeln('   → Action: Restart app to trigger migration');
      }

      // 2. Check table schema
      buffer.writeln('\n2️⃣ TABLE SCHEMA');
      final tableInfo = await database.rawQuery(
        'PRAGMA table_info(sale_items)',
      );
      final hasShoeSizeColumn = tableInfo.any(
        (col) => col['name'] == 'shoeSize',
      );

      if (hasShoeSizeColumn) {
        buffer.writeln(
          '   ✅ PASS - shoeSize column exists in sale_items table',
        );
      } else {
        buffer.writeln('   ❌ FAIL - shoeSize column MISSING!');
        buffer.writeln('   → Action: Delete database and restart app');
      }

      // 3. Check for shoe products
      buffer.writeln('\n3️⃣ SHOE PRODUCTS');
      final products = await database.rawQuery('''
        SELECT id, name, sizeType, shoeSizes
        FROM products
        WHERE shoeSizes IS NOT NULL AND shoeSizes != ''
      ''');

      buffer.writeln('   Found ${products.length} shoe products');
      if (products.isEmpty) {
        buffer.writeln('   ⚠️  WARNING - No shoe products found');
        buffer.writeln('   → Action: Create a shoe product in Manage Products');
      } else {
        buffer.writeln('   ✅ PASS - Shoe products exist:');
        for (final product in products.take(3)) {
          buffer.writeln('      - ${product['name']} (${product['sizeType']})');
        }
      }

      // 4. Check recent sales
      buffer.writeln('\n4️⃣ RECENT SALES (Last 5)');
      final sales = await database.rawQuery('''
        SELECT s.id, s.saleNumber, s.saleDate
        FROM sales s
        ORDER BY s.saleDate DESC
        LIMIT 5
      ''');

      buffer.writeln('   Found ${sales.length} recent sales');

      int salesWithShoeSize = 0;
      int salesWithoutShoeSize = 0;

      for (final sale in sales) {
        final saleId = sale['id'] as int;
        final items = await database.rawQuery(
          '''
          SELECT productName, shoeSize
          FROM sale_items
          WHERE saleId = ?
        ''',
          [saleId],
        );

        bool hasShoeSize = items.any((item) {
          final size = item['shoeSize'];
          return size != null && size.toString().isNotEmpty;
        });

        if (hasShoeSize) {
          salesWithShoeSize++;
          buffer.writeln('   ✅ Sale #${sale['saleNumber']} HAS shoe sizes');
          for (final item in items) {
            if (item['shoeSize'] != null &&
                item['shoeSize'].toString().isNotEmpty) {
              buffer.writeln(
                '      - ${item['productName']}: Size ${item['shoeSize']}',
              );
            }
          }
        } else {
          salesWithoutShoeSize++;
          buffer.writeln('   ❌ Sale #${sale['saleNumber']} NO shoe sizes');
        }
      }

      buffer.writeln(
        '\n   Summary: $salesWithShoeSize with sizes, $salesWithoutShoeSize without',
      );

      if (salesWithShoeSize == 0) {
        buffer.writeln('   ⚠️  WARNING - No sales have shoe size data');
        buffer.writeln('   → Action: Make a NEW sale with a shoe product');
      }

      // 5. Check POSService loaded sales
      buffer.writeln('\n5️⃣ POS SERVICE LOADED SALES');
      final pos = GetIt.I<POSService>();
      buffer.writeln('   Loaded sales count: ${pos.recentSales.length}');

      int loadedWithShoes = 0;
      for (final sale in pos.recentSales) {
        final hasShoes = sale.items.any((item) => item.shoeSize != null);
        if (hasShoes) {
          loadedWithShoes++;
          buffer.writeln(
            '   ✅ Sale ${sale.saleNumber} has shoe items in memory:',
          );
          for (final item in sale.items.where((i) => i.shoeSize != null)) {
            buffer.writeln(
              '      - ${item.productName}: Size ${item.shoeSize}',
            );
          }
        }
      }

      buffer.writeln(
        '   Sales with shoes in memory: $loadedWithShoes/${pos.recentSales.length}',
      );

      if (loadedWithShoes == 0 && salesWithShoeSize > 0) {
        buffer.writeln(
          '   ⚠️  WARNING - Database has shoe sizes but POSService doesn\'t',
        );
        buffer.writeln('   → Action: Call pos.loadRecentSales() or refresh');
      }

      // 6. Final verdict
      buffer.writeln('\n═══════════════════════════════════════');
      buffer.writeln('📊 DIAGNOSTIC SUMMARY');
      buffer.writeln('═══════════════════════════════════════');

      bool allPass =
          version >= 17 &&
          hasShoeSizeColumn &&
          products.isNotEmpty &&
          salesWithShoeSize > 0 &&
          loadedWithShoes > 0;

      if (allPass) {
        buffer.writeln('✅ ALL CHECKS PASSED');
        buffer.writeln('Shoe sizes should be visible in the UI.');
        buffer.writeln('\nIf you still can\'t see them:');
        buffer.writeln(
          '1. Make sure you\'re looking at a NEW sale (not old ones)',
        );
        buffer.writeln(
          '2. Check that the sale list is showing the right sales',
        );
        buffer.writeln('3. Try refreshing the sales report');
      } else {
        buffer.writeln('❌ ISSUES FOUND\n');

        if (version < 17) {
          buffer.writeln('⚠️  Database version is old - restart app');
        }
        if (!hasShoeSizeColumn) {
          buffer.writeln(
            '⚠️  shoeSize column missing - delete database and restart',
          );
        }
        if (products.isEmpty) {
          buffer.writeln(
            '⚠️  No shoe products - create one in Manage Products',
          );
        }
        if (salesWithShoeSize == 0) {
          buffer.writeln('⚠️  No sales with shoe sizes - make a NEW sale');
        }
        if (loadedWithShoes == 0 && salesWithShoeSize > 0) {
          buffer.writeln('⚠️  Data in DB but not loaded - refresh sales list');
        }
      }

      buffer.writeln('═══════════════════════════════════════\n');
    } catch (e, stackTrace) {
      buffer.writeln('❌ ERROR DURING DIAGNOSTIC:');
      buffer.writeln(e.toString());
      buffer.writeln('\nStack trace:');
      buffer.writeln(stackTrace.toString());
    }

    final result = buffer.toString();
    debugPrint(result);
    return result;
  }

  /// Quick check if shoe sizes should be visible
  static Future<bool> shouldShoeSizesBeVisible() async {
    try {
      final db = DatabaseService();
      final database = await db.database;

      final versionResult = await database.rawQuery('PRAGMA user_version');
      final version = versionResult.first['user_version'] as int;
      if (version < 17) return false;

      final tableInfo = await database.rawQuery(
        'PRAGMA table_info(sale_items)',
      );
      final hasShoeSizeColumn = tableInfo.any(
        (col) => col['name'] == 'shoeSize',
      );
      if (!hasShoeSizeColumn) return false;

      final salesWithShoes = await database.rawQuery('''
        SELECT COUNT(DISTINCT si.saleId) as count
        FROM sale_items si
        WHERE si.shoeSize IS NOT NULL AND si.shoeSize != ''
      ''');

      final count = salesWithShoes.first['count'] as int;
      return count > 0;
    } catch (e) {
      debugPrint('Error checking shoe size visibility: $e');
      return false;
    }
  }
}
