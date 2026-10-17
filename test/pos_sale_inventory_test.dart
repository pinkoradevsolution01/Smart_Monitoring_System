import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_monitoring_system/models/product.dart';
import 'package:smart_monitoring_system/models/sale.dart';
import 'package:smart_monitoring_system/models/sale_item.dart';
import 'package:smart_monitoring_system/services/database_service_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late DatabaseService service;
  final product = Product(
    id: 2,
    barcode: 'p2',
    name: 'Aspire',
    buyingPrice: 1,
    sellingPrice: 2,
    quantity: 50,
    reorderLevel: 5,
    category: 'test',
    createdAt: DateTime(2026),
  );
  Sale sale(String number, int quantity) => Sale(
    saleNumber: number,
    items: [
      SaleItem(
        saleId: 0,
        productId: 2,
        productName: 'Aspire',
        quantity: quantity,
        unitPrice: 2,
        discount: 0,
        subtotal: quantity * 2,
      ),
    ],
    subtotal: quantity * 2,
    discountAmount: 0,
    taxAmount: 0,
    totalAmount: quantity * 2,
    paymentMethod: 'cash',
    status: SaleStatus.completed,
    cashierName: 'test',
    saleDate: DateTime(2026),
  );

  setUp(() async {
    service = DatabaseService();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DatabaseService.setDatabaseForTesting(db);
    final productColumns = product
        .toMap()
        .keys
        .where((key) => key != 'id')
        .map((key) => '"$key"')
        .join(', ');
    final saleColumns = sale('example', 1)
        .toMap()
        .keys
        .where((key) => key != 'id' && key != 'items')
        .map((key) => '"$key"')
        .join(', ');
    await db.execute(
      'CREATE TABLE products (id INTEGER PRIMARY KEY, $productColumns)',
    );
    await db.execute(
      'CREATE TABLE sales (id INTEGER PRIMARY KEY AUTOINCREMENT, $saleColumns)',
    );
    await db.execute(
      'CREATE TABLE sale_items (id INTEGER PRIMARY KEY AUTOINCREMENT, saleId, productId, productName, quantity, unitPrice, discount, subtotal, shoeSize)',
    );
    await db.execute(
      'CREATE TABLE inventory_movements (id INTEGER PRIMARY KEY AUTOINCREMENT, productId, quantityBefore, quantityAfter, quantityChanged, movementType, reference, reason, movementDate)',
    );
    await db.insert('products', product.toMap());
  });

  tearDown(() async {
    DatabaseService.setDatabaseForTesting(null);
    await db.close();
  });

  test('24-unit sale commits stock, sale and movement together', () async {
    await service.commitPosSale(sale('SAL24', 24));
    expect((await service.getProductById(2))!.quantity, 26);
    final movements = await service.getProductMovements(2);
    expect(movements.single.quantityChanged, -24);
    expect(movements.single.quantityBefore, 50);
    expect(movements.single.quantityAfter, 26);
    expect(movements.single.reference, 'SAL24');
    expect(await service.pendingProductVersions(), {2: 1});
  });

  test('insufficient stock rolls back all sale and inventory writes', () async {
    await expectLater(
      service.commitPosSale(sale('TOO-MANY', 51)),
      throwsStateError,
    );
    expect((await service.getProductById(2))!.quantity, 50);
    expect(await db.query('sales'), isEmpty);
    expect(await db.query('sale_items'), isEmpty);
    expect(await db.query('inventory_movements'), isEmpty);
  });

  test('later stock edits are not cleared by an older upload', () async {
    await service.commitPosSale(sale('SAL24', 24));
    final oldVersions = await service.pendingProductVersions();
    final current = (await service.getProductById(2))!;
    await service.updateProduct(current.copyWith(quantity: 30));
    await service.acknowledgeProductVersions(oldVersions);
    expect(await service.pendingProductVersions(), {2: 2});
    expect(await service.mergeSyncedProduct(product), isFalse);
    expect((await service.getProductById(2))!.quantity, 30);
  });

  test(
    'cloud pull cannot replace an unsynced sale and old acknowledgements cannot clear newer changes',
    () async {
      await service.commitPosSale(sale('SAL24', 24));
      final oldVersions = await service.pendingProductVersions();
      expect(await service.mergeSyncedProduct(product), isFalse);
      expect((await service.getProductById(2))!.quantity, 26);
      await service.commitPosSale(sale('SAL2', 2));
      await service.acknowledgeProductVersions(oldVersions);
      expect(await service.pendingProductVersions(), {2: 2});
      expect((await service.getProductById(2))!.quantity, 24);
      await service.acknowledgeProductVersions({2: 2});
      expect(await service.pendingProductVersions(), isEmpty);
    },
  );
}
