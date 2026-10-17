import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_monitoring_system/models/purchase_order.dart';
import 'package:smart_monitoring_system/services/database_service_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late DatabaseService service;
  final order = PurchaseOrder(
    orderNumber: 'PO-TEST',
    supplierId: 1,
    supplierName: 'Supplier',
    orderDate: DateTime(2026),
    status: 'pending',
    totalAmount: 100,
    notes: '[SmartPlus action:one]',
    items: [
      PurchaseOrderItem(
        orderId: 0,
        productId: 2,
        productName: 'Item',
        quantity: 5,
        unitPrice: 20,
        totalPrice: 100,
      ),
    ],
  );

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    service = DatabaseService();
    DatabaseService.setDatabaseForTesting(db);
    final columns = order
        .toMap()
        .keys
        .where((key) => key != 'id')
        .map((key) => '"$key"')
        .join(', ');
    await db.execute(
      'CREATE TABLE purchase_orders (id INTEGER PRIMARY KEY AUTOINCREMENT, $columns)',
    );
    await db.execute(
      'CREATE TABLE purchase_order_items (id INTEGER PRIMARY KEY AUTOINCREMENT, orderId, productId, productName, quantity, receivedQuantity, unitPrice, totalPrice)',
    );
  });

  tearDown(() async {
    DatabaseService.setDatabaseForTesting(null);
    await db.close();
  });

  test(
    'unsynced approval survives restore and stale acknowledgements',
    () async {
      final id = await service.insertPurchaseOrder(order);
      final pending = await service.pendingPurchaseOrderVersions();
      expect(pending, {'PO-TEST': 1});
      await service.approvePurchaseOrder(id, 'Owner', 'signature');
      await service.acknowledgePurchaseOrderVersions(pending);
      expect(await service.pendingPurchaseOrderVersions(), {'PO-TEST': 2});
      await service.insertOrUpdatePurchaseOrder(order);
      expect((await service.getPurchaseOrderById(id))!.status, 'approved');
      await service.acknowledgePurchaseOrderVersions({'PO-TEST': 2});
      expect(await service.pendingPurchaseOrderVersions(), isEmpty);
      await service.insertOrUpdatePurchaseOrder(
        order.copyWith(status: 'received'),
      );
      expect((await service.getPurchaseOrderById(id))!.status, 'received');
    },
  );
}
