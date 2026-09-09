import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_service.dart';
import 'backend_config.dart';

class DeveloperAccount {
  final String id;
  final String displayName;
  final String email;
  final String authMethod;
  final String? googleSub;
  final String? avatarUrl;
  final bool isActive;

  DeveloperAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.authMethod,
    this.googleSub,
    this.avatarUrl,
    required this.isActive,
  });

  factory DeveloperAccount.fromMap(Map<String, dynamic> map) {
    return DeveloperAccount(
      id: map['id']?.toString() ?? 'primary',
      displayName: map['displayName']?.toString() ?? 'Developer',
      email: map['email']?.toString() ?? 'developer@smartmonitoring.com',
      authMethod: map['authMethod']?.toString() ?? 'password',
      googleSub: map['googleSub']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      isActive:
          map['isActive'] == true ||
          (map['isActive'] is num && (map['isActive'] as num).toInt() == 1),
    );
  }
}

/// Backend-backed service for the developer account.
/// The account data now lives in MySQL so multiple devices share one identity.
class DeveloperService extends ChangeNotifier {
  static const String _sessionTokenKey = 'backend_access_token';
  static final DeveloperService _instance = DeveloperService._internal();
  factory DeveloperService() => _instance;
  DeveloperService._internal() {
    _loadAccount();
  }

  final ApiClient _api = ApiClient();

  DeveloperAccount? _account;
  bool _isLoading = false;

  String get username => _account?.email ?? '';
  String get password => '';
  String get displayName => _account?.displayName ?? '';
  bool get hasDeveloperAccount => _account != null;
  bool get isLoading => _isLoading;
  bool get isConfigured => BackendConfig.useRestBackend;

  DeveloperAccount? get account => _account;

  /// Returns true when the given email matches the registered developer identity.
  bool isDeveloperEmail(String email) {
    final accountEmail = _account?.email.trim().toLowerCase();
    if (accountEmail == null || accountEmail.isEmpty) return false;
    return accountEmail == email.trim().toLowerCase();
  }

  Future<void> _loadAccount() async {
    if (!isConfigured) return;

    _isLoading = true;
    try {
      final response = await _api.getJson('developer/account');
      if (response is Map<String, dynamic> && response['account'] is Map) {
        _account = DeveloperAccount.fromMap(
          Map<String, dynamic>.from(response['account'] as Map),
        );
      }
    } catch (e) {
      debugPrint('DeveloperService: failed to load account - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DeveloperAccount?> refreshDeveloperAccount() async {
    await _loadAccount();
    return _account;
  }

  Future<bool> authenticate(String username, String password) async {
    if (!isConfigured) return false;

    try {
      final response = await _api.postJson(
        'developer/login',
        body: {'username': username, 'password': password},
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final token = response['token']?.toString();
        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionTokenKey, token);
        }
        if (response['account'] is Map) {
          _account = DeveloperAccount.fromMap(
            Map<String, dynamic>.from(response['account'] as Map),
          );
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('DeveloperService: authenticate failed - $e');
      return false;
    }
  }

  Future<bool> authenticateWithGoogle({
    required String email,
    required String name,
    required String googleSub,
    String? avatarUrl,
  }) async {
    if (!isConfigured) return false;

    // Log Google credentials for debugging
    debugPrint('=== GOOGLE SIGN-IN DEBUG ===');
    debugPrint('Email: $email');
    debugPrint('Name: $name');
    debugPrint('Google Sub: $googleSub');
    debugPrint('Avatar URL: $avatarUrl');
    debugPrint('============================');

    try {
      // Try register endpoint first (auto-creates account on first login)
      final response = await _api.postJson(
        'developer/google/register',
        body: {
          'email': email,
          'name': name,
          'googleSub': googleSub,
          'avatarUrl': avatarUrl,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final token = response['token']?.toString();
        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionTokenKey, token);
        }
        if (response['account'] is Map) {
          _account = DeveloperAccount.fromMap(
            Map<String, dynamic>.from(response['account'] as Map),
          );
          notifyListeners();
        }
        return true;
      }

      // Capture backend error message for better debugging
      final errorMsg = response is Map<String, dynamic>
          ? (response['message'] ?? response['error'] ?? 'Unknown error')
          : 'Invalid response format';
      debugPrint('DeveloperService: google authenticate failed - $errorMsg');
      return false;
    } catch (e) {
      debugPrint('DeveloperService: google authenticate failed - $e');
      return false;
    }
  }

  Future<void> updateDeveloperAccount({
    required String username,
    String? password,
    String? email,
    String authMethod = 'password',
    String? googleSub,
    String? avatarUrl,
  }) async {
    if (!isConfigured) {
      throw Exception('Backend not configured');
    }

    final body = <String, dynamic>{
      'displayName': username,
      'email':
          email ??
          (username.contains('@') ? username : 'developer@smartmonitoring.com'),
      'authMethod': authMethod,
      'avatarUrl': avatarUrl,
    };

    if (authMethod == 'google') {
      body['googleSub'] = googleSub ?? password;
    } else if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }

    final response = await _api.putJson('developer/account', body: body);
    if (response is Map<String, dynamic> && response['account'] is Map) {
      _account = DeveloperAccount.fromMap(
        Map<String, dynamic>.from(response['account'] as Map),
      );
      notifyListeners();
      return;
    }

    throw Exception('Failed to update developer account');
  }
}
