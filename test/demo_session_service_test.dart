import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/services/demo_session_service.dart';

void main() {
  final demo = DemoSessionService.instance;

  tearDown(demo.end);

  test('demo records are isolated in memory and cleared at session end', () {
    demo.start('cashier');

    expect(demo.isActive, isTrue);
    expect(demo.products, isNotEmpty);
    expect(demo.completedSales, 12);

    final firstStock = demo.products.first.stock;
    demo.simulateSale();

    expect(demo.completedSales, 13);
    expect(demo.products.first.stock, firstStock - 1);

    demo.end();

    expect(demo.isActive, isFalse);
    expect(demo.role, isNull);
    expect(demo.products, isEmpty);
    expect(demo.completedSales, 0);
  });
}
