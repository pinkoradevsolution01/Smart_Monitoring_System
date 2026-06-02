import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Simple service to manage a developer account stored in SharedPreferences.
class DeveloperService extends ChangeNotifier {
  static final DeveloperService _instance = DeveloperService._internal();
  factory DeveloperService() => _instance;
  DeveloperService._internal() {
    _initialize();
  }

  static const String _prefsKey = 'developer_account';

  String _username = '';
  String _password = '';

  String get username => _username;
  String get password => _password;

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _username = (data['username'] as String?) ?? '';
        _password = (data['password'] as String?) ?? '';
        debugPrint('DeveloperService: loaded developer account for $_username');
      } else {
        // No modern developer_account found; attempt migration from legacy keys
        final legacyPw = prefs.getString('dev_password') ?? '';
        final legacyName = prefs.getString('dev_name') ?? prefs.getString('dev_email') ?? '';
        if (legacyPw.isNotEmpty) {
          _username = legacyName.isNotEmpty ? legacyName : 'Developer';
          _password = legacyPw;
          // Persist into new developer_account key
          final payload = jsonEncode({'username': _username, 'password': _password});
          await prefs.setString(_prefsKey, payload);
          debugPrint('DeveloperService: migrated legacy developer account for $_username');
        }
      }
    } catch (e) {
      debugPrint('DeveloperService: failed to load - $e');
    }
    notifyListeners();
  }

  Future<void> updateDeveloperAccount({required String username, required String password}) async {
    _username = username;
    _password = password;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({'username': _username, 'password': _password});
      await prefs.setString(_prefsKey, payload);
    } catch (e) {
      debugPrint('DeveloperService: failed to save - $e');
    }
    notifyListeners();
  }

  /// Authenticate supplied credentials against stored developer account.
  /// If no stored account exists, returns false.
  bool authenticate(String username, String password) {
    if (_username.isEmpty || _password.isEmpty) return false;
    return username.toLowerCase() == _username.toLowerCase() && password == _password;
  }
}
