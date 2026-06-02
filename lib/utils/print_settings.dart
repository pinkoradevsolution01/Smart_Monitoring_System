import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrintSettings {
  static final ValueNotifier<String> paperSize = ValueNotifier('Thermal 48mm');

  /// Load saved paper size from SharedPreferences into the notifier.
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('default_receipt_paper_size');
    paperSize.value = saved ?? 'Thermal 48mm';
  }
}
