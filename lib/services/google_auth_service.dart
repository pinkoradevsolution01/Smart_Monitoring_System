import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpRequest, HttpServer, Platform, Process;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_api_service.dart';

/// Google authentication helper backed by the Node/MySQL backend.
///
/// Desktop platforms use a browser-based OAuth code flow so Windows/Linux/macOS
/// can keep their current UX. Web/mobile use the Google Sign-In plugin and then
/// exchange the Google ID token with the backend for an app session.
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  static const int _callbackPort = 54321;
  static const String _sessionTokenKey = 'backend_access_token';
  static const String _sessionUserKey = 'backend_user';

  final ApiClient _api = ApiClient();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Map<String, dynamic>? _currentUser;
  String? _accessToken;

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  String get _callbackUrl => 'http://localhost:$_callbackPort/auth/callback';

  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isSignedIn => _accessToken != null && _currentUser != null;

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      if (_isDesktop) {
        return await _signInWithDesktopBrowserFlow();
      }
      return await _signInWithGoogleSignIn();
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _signInWithGoogleSignIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      debugPrint('❌ Google sign in cancelled or failed');
      return null;
    }

    final auth = await account.authentication;
    if (auth.idToken == null) {
      debugPrint('❌ Google Sign-In did not return an ID token');
      return null;
    }

    final response = await _api.postJson(
      'auth/google',
      body: {'idToken': auth.idToken},
    );
    return _storeBackendSession(response);
  }

  Future<Map<String, dynamic>?> _signInWithDesktopBrowserFlow() async {
    HttpServer? callbackServer;
    final completer = Completer<String>();

    try {
      callbackServer = await HttpServer.bind('localhost', _callbackPort);
      debugPrint('✅ Local callback server started on port $_callbackPort');

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
        debugPrint('❌ Backend did not return a Google auth URL');
        return null;
      }

      await _openUrlInBrowser(authUrl);
      debugPrint('⏳ Browser opened. Please complete authentication...');

      final code = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('OAuth callback timeout'),
      );

      final exchangeResponse = await _api.postJson(
        'auth/google/exchange',
        body: {'code': code, 'redirectUri': _callbackUrl},
      );

      return _storeBackendSession(exchangeResponse);
    } finally {
      await callbackServer?.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _storeBackendSession(dynamic response) async {
    if (response is! Map<String, dynamic>) {
      debugPrint('❌ Invalid backend auth response');
      return null;
    }

    if (response['success'] != true) {
      debugPrint('❌ Backend auth failed: ${response['message']}');
      return null;
    }

    final token = response['token']?.toString();
    final user = response['user'];
    if (token == null || user is! Map) {
      debugPrint('❌ Backend auth response missing token or user');
      return null;
    }

    _accessToken = token;
    _currentUser = Map<String, dynamic>.from(user);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, token);
    await prefs.setString(_sessionUserKey, jsonEncode(_currentUser));

    debugPrint('✅ Signed in as: ${_currentUser?['email']}');
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
      if (!_isDesktop) {
        await _googleSignIn.signOut();
      }
      await clearSession();
      debugPrint('✅ Signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
    }
  }

  Future<void> storeSession() async {
    try {
      if (_accessToken == null || _currentUser == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionTokenKey, _accessToken!);
      await prefs.setString(_sessionUserKey, jsonEncode(_currentUser));
      debugPrint('✅ Session stored');
    } catch (e) {
      debugPrint('❌ Error storing session: $e');
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
      debugPrint('✅ Session restored: ${_currentUser?['email']}');
      return true;
    } catch (e) {
      debugPrint('❌ Error restoring session: $e');
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
      debugPrint('✅ Session cleared');
    } catch (e) {
      debugPrint('❌ Error clearing session: $e');
    }
  }

  Future<void> _openUrlInBrowser(String url) async {
    if (!_isDesktop) return;

    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url]);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [url]);
    }
  }
}
