import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController {
  // ValueNotifier holding current locale code (e.g. 'en' or 'fil')
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));
  static const _preferenceKey = 'app_locale_code';
  static const _supportedCodes = {'en', 'fil'};

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_preferenceKey);
    if (code != null && _supportedCodes.contains(code)) {
      locale.value = Locale(code);
    }
  }

  static Future<void> setLocale(Locale l) async {
    final code = _supportedCodes.contains(l.languageCode)
        ? l.languageCode
        : 'en';
    final next = Locale(code);
    if (locale.value != next) {
      locale.value = next;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, code);
  }
}
