import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Backend REST API configuration for MySQL-based sync and license services.
class BackendConfig {
  /// Set this to your Node.js backend URL, including `/api` if desired.
  ///
  /// Override it at build time with:
  /// `--dart-define=BACKEND_API_BASE_URL=http://<your-pc-ip>:3000/api`
  ///
  /// Common values:
  /// - Windows/macOS/Linux desktop: `http://localhost:3000/api`
  /// - Android emulator: `http://10.0.2.2:3000/api`
  /// - Physical device on same LAN: `http://<your-pc-lan-ip>:3000/api`
  static const String _envApiBaseUrl = String.fromEnvironment(
    'BACKEND_API_BASE_URL',
    defaultValue: '',
  );
  static String get _defaultApiBaseUrl {
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
          return 'http://localhost:3000/api';
        case TargetPlatform.android:
          return 'http://10.0.2.2:3000/api';
        case TargetPlatform.iOS:
          return 'http://localhost:3000/api';
        case TargetPlatform.fuchsia:
          break;
      }
    }

    return 'http://localhost:3000/api';
  }

  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) {
      return _envApiBaseUrl;
    }
    return _defaultApiBaseUrl;
  }

  /// Google OAuth web client ID used by `google_sign_in` to request an ID token
  /// on Android/iOS. Pass this at build time with:
  /// `--dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com`
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Optional API key header for backend authentication.
  static const String apiKey = '';

  static bool get useRestBackend => apiBaseUrl.isNotEmpty;

  static Map<String, String> get defaultHeaders {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) {
      headers['x-api-key'] = apiKey;
    }
    return headers;
  }
}
