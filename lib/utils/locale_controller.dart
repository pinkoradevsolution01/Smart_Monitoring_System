import 'package:flutter/material.dart';

class LocaleController {
  // ValueNotifier holding current locale code (e.g. 'en' or 'fil')
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  static void setLocale(Locale l) {
    locale.value = l;
  }
}
