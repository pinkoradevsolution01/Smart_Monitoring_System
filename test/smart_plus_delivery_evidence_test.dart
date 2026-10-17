import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/models/purchase_order.dart';
import 'package:smart_monitoring_system/models/restock_record.dart';
import 'package:smart_monitoring_system/services/smart_plus_notification_service.dart';

void main() {
  PurchaseOrder order(int received) => PurchaseOrder(
    orderNumber: 'PO-1',
    supplierId: 1,
    supplierName: 'Supplier',
    orderDate: DateTime(2026),
    status: 'completed',
    totalAmount: 10,
    items: [
      PurchaseOrderItem(
        orderId: 1,
        productId: 2,
        productName: 'Item',
        quantity: 5,
        receivedQuantity: received,
        unitPrice: 2,
        totalPrice: 10,
      ),
    ],
  );
  RestockRecord record(
    int quantity, {
    String reference = 'Purchase Order PO-1',
  }) => RestockRecord(
    productId: 2,
    productName: 'Item',
    quantity: quantity,
    referencedBy: reference,
  );

  test('full receipt and order-linked stock close stale order alerts', () {
    expect(isPurchaseOrderFullyRestocked(order(5), [record(5)]), isTrue);
  });
  test('partial, missing, and unrelated restocks do not hide alerts', () {
    expect(isPurchaseOrderFullyRestocked(order(4), [record(5)]), isFalse);
    expect(isPurchaseOrderFullyRestocked(order(5), [record(4)]), isFalse);
    expect(
      isPurchaseOrderFullyRestocked(order(5), [
        record(5, reference: 'Purchase Order PO-10'),
      ]),
      isFalse,
    );
  });
  test('multiple lines for one product require enough stock for all lines', () {
    final first = order(5);
    final repeated = first.copyWith(items: [...first.items, first.items.first]);
    expect(isPurchaseOrderFullyRestocked(repeated, [record(5)]), isFalse);
    expect(isPurchaseOrderFullyRestocked(repeated, [record(10)]), isTrue);
  });
}
