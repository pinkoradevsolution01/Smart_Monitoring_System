import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpRequest, HttpServer, Platform, Process;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backend_api_service.dart';
import 'backend_config.dart';

enum GoogleAuthProfile {
  owner,
  developer,
}

/// Google authentication helper backed by the Node/MySQL backend.
///
/// All platforms use the backend-backed browser OAuth flow so we avoid Android
/// Google Sign-In client/SHA-1 configuration issues and keep the backend as the
/// source of truth for sessions.
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  static const int _callbackPort = 54321;
  static const String _sessionTokenKey = 'backend_access_token';
  static const String _sessionUserKey = 'backend_user';

  final ApiClient _api = ApiClient();

  Map<String, dynamic>? _currentUser;
  String? _accessToken;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  String get _callbackUrl => 'http://localhost:$_callbackPort/auth/callback';

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isSignedIn => _accessToken != null && _currentUser != null;

  Future<Map<String, dynamic>?> signInWithGoogle({
    GoogleAuthProfile profile = GoogleAuthProfile.developer,
  }) async {
    try {
      if (BackendConfig.googleWebClientId.isEmpty) {
        debugPrint(
          'WARNING: GOOGLE_WEB_CLIENT_ID is not configured. Backend-backed Google Sign-In may fail until a web client ID is supplied.',
        );
      }

      return await _signInWithBackendBrowserFlow(profile: profile);
    } on http.ClientException catch (e) {
      debugPrint(
        'ERROR: Backend connection failed while signing in: $e\n'
        'Check that the laptop backend is running and reachable from the phone at '
        '${BackendConfig.apiBaseUrl}. If needed, allow TCP port 3000 through Windows Firewall.',
      );
      return null;
    } on PlatformException catch (e) {
      final message = '${e.code} ${e.message ?? ''} ${e.details ?? ''}';
      if (message.contains('ApiException: 10')) {
        debugPrint(
          'ERROR: Google Sign-In rejected the app configuration. '
          'The app is now expected to use the backend browser OAuth flow, '
          'so this error usually means the old native Google Sign-In path is '
          'still running from a stale build. Rebuild the app after flutter pub get.',
        );
      }
      debugPrint(
        'ERROR: Google sign in platform error: $message',
      );
      return null;
    } catch (e) {
      debugPrint('ERROR: Google sign in error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _signInWithBackendBrowserFlow({
    required GoogleAuthProfile profile,
  }) async {
    HttpServer? callbackServer;
    final completer = Completer<String>();

    try {
      await _api.getJson('health');
      callbackServer = await HttpServer.bind('localhost', _callbackPort);
      debugPrint('OK: Local callback server started on port $_callbackPort');

      callbackServer.listen((HttpRequest request) async {
        final uri = request.uri;
        request.response.headers.set(
          'Content-Type',
          'text/html; charset=utf-8',
        );
        request.response.write('''
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <title>Authentication Successful</title>
          </head>
          <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
            <h1 style="color: #4CAF50;">Authentication Successful!</h1>
            <p>You can close this window and return to the app.</p>
          </body>
          </html>
        ''');
        await request.response.close();

        final code = uri.queryParameters['code'];
        if (code != null && !completer.isCompleted) {
          completer.complete(code);
        }
      });

      final authUrlResponse = await _api.getJson(
        'auth/google/url',
        queryParameters: {'redirectUri': _callbackUrl},
      );
      final authUrl = authUrlResponse is Map<String, dynamic>
          ? authUrlResponse['authUrl']?.toString()
          : null;

      if (authUrl == null || authUrl.isEmpty) {
        debugPrint('ERROR: Backend did not return a Google auth URL');
        return null;
      }

      await _openUrlInBrowser(authUrl);
      debugPrint('WAITING: Browser opened. Please complete authentication...');

      final code = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('OAuth callback timeout'),
      );

      final exchangeResponse = await _api.postJson(
        'auth/google/exchange',
        body: {'code': code, 'redirectUri': _callbackUrl},
      );

      return _storeBackendSession(exchangeResponse);
    } on http.ClientException catch (e) {
      debugPrint(
        'ERROR: Failed to contact backend during Google code exchange: $e\n'
        'This usually means the phone cannot reach the laptop backend at '
        '${BackendConfig.apiBaseUrl}.',
      );
      return null;
    } finally {
      await callbackServer?.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _storeBackendSession(dynamic response) async {
    if (response is! Map<String, dynamic>) {
      debugPrint('ERROR: Invalid backend auth response');
      return null;
    }

    if (response['success'] != true) {
      debugPrint('ERROR: Backend auth failed: ${response['message']}');
      return null;
    }

    final token = response['token']?.toString();
    final user = response['user'];
    if (token == null || user is! Map) {
      debugPrint('ERROR: Backend auth response missing token or user');
      return null;
    }

    _accessToken = token;
    _currentUser = Map<String, dynamic>.from(user);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, token);
    await prefs.setString(_sessionUserKey, jsonEncode(_currentUser));

    debugPrint('OK: Signed in as: ${_currentUser?['email']}');
    return {
      'id': _currentUser?['id'] ?? '',
      'email': _currentUser?['email'] ?? '',
      'name': _currentUser?['fullName'] ?? _currentUser?['email'] ?? 'User',
      'avatar_url': _currentUser?['avatarUrl'],
      'token': token,
    };
  }

  Future<void> signOut() async {
    try {
      await clearSession();
      debugPrint('OK: Signed out successfully');
    } catch (e) {
      debugPrint('ERROR: Sign out error: $e');
    }
  }

  Future<void> storeSession() async {
    try {
      if (_accessToken == null || _currentUser == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionTokenKey, _accessToken!);
      await prefs.setString(_sessionUserKey, jsonEncode(_currentUser));
      debugPrint('OK: Session stored');
    } catch (e) {
      debugPrint('ERROR: Error storing session: $e');
    }
  }

  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_sessionTokenKey);
      final userJson = prefs.getString(_sessionUserKey);

      if (token == null ||
          token.isEmpty ||
          userJson == null ||
          userJson.isEmpty) {
        return false;
      }

      _accessToken = token;
      _currentUser = Map<String, dynamic>.from(jsonDecode(userJson) as Map);
      debugPrint('OK: Session restored: ${_currentUser?['email']}');
      return true;
    } catch (e) {
      debugPrint('ERROR: Error restoring session: $e');
      return false;
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionTokenKey);
      await prefs.remove(_sessionUserKey);
      _accessToken = null;
      _currentUser = null;
      debugPrint('OK: Session cleared');
    } catch (e) {
      debugPrint('ERROR: Error clearing session: $e');
    }
  }

  Future<void> _openUrlInBrowser(String url) async {
    if (_isDesktop) {
      if (Platform.isWindows) {
        await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.start('open', [url]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [url]);
      }
      return;
    }

    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Failed to launch browser for Google sign-in');
    }
  }
}
