import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

class FontLoader {
  static Future<pw.Font> loadNotoSans() async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    return pw.Font.ttf(fontData);
  }

  static Future<pw.Font> loadNotoSansBold() async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    return pw.Font.ttf(fontData);
  }
}
