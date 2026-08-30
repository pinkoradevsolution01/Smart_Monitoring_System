import 'package:intl/intl.dart';

/// Consistent currency presentation for all user-facing Philippine peso values.
///
/// Keep this formatter for display only. Stored values, form input, and CSV
/// exports remain plain numeric values so they can be parsed safely.
class AppCurrency {
  AppCurrency._();

  static final NumberFormat _amountFormat = NumberFormat('#,##0.00', 'en_PH');

  static String amount(num? value) => _amountFormat.format(value ?? 0);

  static String peso(num? value) => '₱${amount(value)}';

  static String php(num? value) => 'PHP ${amount(value)}';

  /// Formats legacy package prices such as `₱1,999` without changing the
  /// underlying package configuration values.
  static String pesoFromText(String value) {
    final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
    return parsed == null ? value : peso(parsed);
  }

  /// Reads a price label such as `₱1,999` or `₱1,999.00` as a number.
  static double? parsePriceText(String value) =>
      double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
}
