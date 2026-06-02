import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MotionController {
  static final ValueNotifier<bool> reduceMotion = ValueNotifier(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    reduceMotion.value = prefs.getBool('reduce_motion') ?? false;
  }

  static Future<void> setReduceMotion(bool value) async {
    reduceMotion.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reduce_motion', value);
  }
}
