import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/models/sale.dart';
import 'package:smart_monitoring_system/models/sale_item.dart';

void main() {
  test('Sale serialization preserves items and counts', () {
    final item1 = SaleItem(
      id: 1,
      saleId: 0,
      productId: 100,
      productName: 'Widget A',
      quantity: 2,
      unitPrice: 50.0,
      discount: 0.0,
      subtotal: 100.0,
    );

    final item2 = SaleItem(
      id: 2,
      saleId: 0,
      productId: 101,
      productName: 'Widget B',
      quantity: 1,
      unitPrice: 75.0,
      discount: 0.0,
      subtotal: 75.0,
    );

    final sale = Sale(
      saleNumber: 'TEST123',
      items: [item1, item2],
      subtotal: 175.0,
      discountAmount: 0.0,
      taxAmount: 0.0,
      totalAmount: 175.0,
      paymentMethod: 'cash',
      status: SaleStatus.completed,
      notes: null,
      cashierName: 'Tester',
      saleDate: DateTime.parse('2025-11-26T12:34:56'),
    );

    final map = sale.toMap();
    final restored = Sale.fromMap(map);

    expect(restored.saleNumber, sale.saleNumber);
    expect(restored.items.length, 2);
    expect(restored.itemCount, 3);
    expect(restored.totalAmount, sale.totalAmount);
  });
}
