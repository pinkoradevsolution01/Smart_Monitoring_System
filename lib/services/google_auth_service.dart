import 'dart:async';
import 'dart:io' show Platform, HttpServer, HttpRequest;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper service for Google Authentication with Supabase
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if running on desktop platform
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Port for local OAuth callback server
  static const int _callbackPort = 54321;

  /// Local callback URL for desktop OAuth
  String get _callbackUrl => 'http://localhost:$_callbackPort/auth/callback';

  /// Sign in with Google OAuth
  /// Returns user data if successful, null otherwise
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      debugPrint('🔐 Starting Google OAuth flow...');
      debugPrint(
        '   Platform: ${kIsWeb
            ? "Web"
            : _isDesktop
            ? "Desktop"
            : "Mobile"}',
      );

      // For desktop: Start local callback server
      HttpServer? callbackServer;
      final Completer<Map<String, String>> callbackCompleter = Completer();

      if (_isDesktop) {
        try {
          // Start HTTP server to capture OAuth callback
          callbackServer = await HttpServer.bind('localhost', _callbackPort);
          debugPrint('✅ Local callback server started on port $_callbackPort');

          // Listen for OAuth callback
          callbackServer.listen((HttpRequest request) async {
            final uri = request.uri;
            debugPrint('📥 Received callback: ${uri.path}');

            // Send response to browser with UTF-8 encoding
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
                <script>window.close();</script>
              </body>
              </html>
            ''');
            await request.response.close();

            // Extract callback parameters
            if (!callbackCompleter.isCompleted) {
              callbackCompleter.complete(uri.queryParameters);
            }
          });
        } catch (e) {
          debugPrint('⚠️ Failed to start callback server: $e');
          debugPrint('   Port $_callbackPort might be in use');
        }
      }

      try {
        // Open OAuth in browser
        final response = await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: _isDesktop ? _callbackUrl : null,
          authScreenLaunchMode: LaunchMode.externalApplication,
          // Force Google to show account chooser so users can pick a different
          // Google account instead of automatically reusing an existing signed-in owner.
          queryParams: {
            'prompt': 'select_account',
          },
        );

        if (!response) {
          debugPrint('❌ Google sign in cancelled or failed');
          return null;
        }

        debugPrint('⏳ Browser opened. Please complete authentication...');

        // Wait for callback or timeout
        final authenticated = _isDesktop
            ? await _waitForCallback(callbackCompleter)
            : await _waitForAuthStateChange();

        if (authenticated != true) {
          debugPrint(
            '❌ No user after Google sign in - authentication timed out or failed',
          );
          return null;
        }

        final user = _supabase.auth.currentUser;
        if (user == null) {
          debugPrint('❌ No user after Google sign in');
          return null;
        }

        debugPrint('✅ Google sign in successful: ${user.email}');

        return {
          'id': user.id,
          'email': user.email ?? '',
          'name':
              user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email?.split('@')[0] ??
              'User',
          'avatar_url':
              user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
        };
      } finally {
        // Clean up callback server
        await callbackServer?.close();
        if (_isDesktop) {
          debugPrint('🛑 Callback server stopped');
        }
      }
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      return null;
    }
  }

  /// Sign out from Supabase
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('✅ Signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
    }
  }

  /// Get current user session
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => _supabase.auth.currentUser != null;

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Wait for auth state change after OAuth redirect (Web platform)
  /// Returns true if user is authenticated, false if timeout
  Future<bool?> _waitForAuthStateChange() async {
    try {
      // Wait up to 60 seconds for auth callback
      final result = await _supabase.auth.onAuthStateChange
          .firstWhere(
            (state) => state.event == AuthChangeEvent.signedIn,
            orElse: () => throw TimeoutException('Auth timeout'),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException('Auth callback timeout'),
          );

      return result.session != null;
    } catch (e) {
      debugPrint('⚠️ Auth state change error: $e');
      return null;
    }
  }

  /// Wait for OAuth callback from local server (Desktop platform)
  Future<bool?> _waitForCallback(
    Completer<Map<String, String>> completer,
  ) async {
    try {
      debugPrint('⏳ Waiting for OAuth callback...');

      // Wait up to 2 minutes for user to complete auth
      final params = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('OAuth callback timeout'),
      );

      debugPrint('✅ Callback received with params: ${params.keys.join(", ")}');

      // OAuth returns an authorization code that needs to be exchanged for tokens
      final code = params['code'];

      if (code != null) {
        debugPrint('🔄 Exchanging authorization code for session...');

        try {
          // Exchange the authorization code for a session
          await _supabase.auth.exchangeCodeForSession(code);

          // Session is automatically set by Supabase
          final user = _supabase.auth.currentUser;
          if (user != null) {
            debugPrint('✅ Session established via code exchange');
            debugPrint('   User: ${user.email}');
            return true;
          } else {
            debugPrint('⚠️ Code exchange succeeded but no user');
            return false;
          }
        } catch (e) {
          debugPrint('❌ Failed to exchange code for session: $e');
          return false;
        }
      }

      // Fallback: Check for direct token in callback (rare)
      final accessToken = params['access_token'];
      final refreshToken = params['refresh_token'];

      if (accessToken != null && refreshToken != null) {
        try {
          await _supabase.auth.setSession(refreshToken);
          debugPrint('✅ Session established from callback tokens');
          return true;
        } catch (e) {
          debugPrint('❌ Failed to set session: $e');
          return false;
        }
      }

      debugPrint('⚠️ No authorization code or tokens found in callback');
      debugPrint('   Available params: ${params.keys.join(", ")}');
      return false;
    } catch (e) {
      debugPrint('⚠️ Callback wait error: $e');
      return null;
    }
  }

  /// Store auth session for persistence
  Future<void> storeSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('supabase_access_token', session.accessToken);
        await prefs.setString(
          'supabase_refresh_token',
          session.refreshToken ?? '',
        );
        debugPrint('✅ Session stored');
      }
    } catch (e) {
      debugPrint('❌ Error storing session: $e');
    }
  }

  /// Restore auth session
  Future<bool> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('supabase_access_token');
      final refreshToken = prefs.getString('supabase_refresh_token');

      if (accessToken != null && refreshToken != null) {
        // Session is automatically restored by Supabase
        final user = _supabase.auth.currentUser;
        if (user != null) {
          debugPrint('✅ Session restored: ${user.email}');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error restoring session: $e');
      return false;
    }
  }

  /// Clear stored session
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase_access_token');
      await prefs.remove('supabase_refresh_token');
      debugPrint('✅ Session cleared');
    } catch (e) {
      debugPrint('❌ Error clearing session: $e');
    }
  }
}
