import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monitoring_system/utils/currency_formatter.dart';

void main() {
  group('AppCurrency', () {
    test('formats pesos with grouped thousands and two decimal places', () {
      expect(AppCurrency.peso(0), '₱0.00');
      expect(AppCurrency.peso(999), '₱999.00');
      expect(AppCurrency.peso(100000), '₱100,000.00');
      expect(AppCurrency.peso(1234567.8), '₱1,234,567.80');
    });

    test('normalizes legacy package price labels', () {
      expect(AppCurrency.pesoFromText('₱1,999'), '₱1,999.00');
      expect(AppCurrency.pesoFromText('₱1,999.00'), '₱1,999.00');
    });
  });
}
