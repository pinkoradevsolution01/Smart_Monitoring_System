import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Backend REST API configuration for MySQL-based sync and license services.
class BackendConfig {
  static String? _resolvedApiBaseUrl;
  static const String backendApiBaseUrlPrefsKey = 'backend_api_base_url';
  static const String backendApiBaseUrlsPrefsKey = 'backend_api_base_urls';
  static const String _defaultDropletApiBaseUrl =
      'http://152.42.185.35:3000/api';

  /// Set this to your Node.js backend URL, including `/api` if desired.
  ///
  /// Override it at build time with:
  /// `--dart-define=BACKEND_API_BASE_URL=http://192.168.1.9:3000/api`
  /// For auto-detect across multiple LAN servers, use:
  /// `--dart-define=BACKEND_API_BASE_URLS=http://192.168.1.5:3000/api,http://192.168.1.9:3000/api`
  ///
  /// Common values:
  /// - Windows/macOS/Linux desktop: `http://localhost:3000/api`
  /// - Android emulator: `http://10.0.2.2:3000/api`
  /// - Physical phone on the same LAN: `http://192.168.1.9:3000/api`
  /// - Public Droplet: `http://152.42.185.35:3000/api`
  ///
  /// If you are testing on a physical iPhone/iPad, pass the laptop IP
  /// explicitly with `--dart-define` because `localhost` points to the device
  /// itself instead of the development laptop.
  static const String _envApiBaseUrl = String.fromEnvironment(
    'BACKEND_API_BASE_URL',
    defaultValue: '',
  );
  static const String _envApiBaseUrls = String.fromEnvironment(
    'BACKEND_API_BASE_URLS',
    defaultValue: '',
  );

  static void setResolvedApiBaseUrl(String baseUrl) {
    _resolvedApiBaseUrl = _normalizeBaseUrl(baseUrl);
  }

  static String? get resolvedApiBaseUrl => _resolvedApiBaseUrl;

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  }

  static List<String> _splitBaseUrls(String rawBaseUrls) {
    return rawBaseUrls
        .split(RegExp(r'[,\n; ]+'))
        .map(_normalizeBaseUrl)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> get configuredApiBaseUrls {
    if (_envApiBaseUrls.trim().isNotEmpty) {
      return _splitBaseUrls(_envApiBaseUrls);
    }

    if (_envApiBaseUrl.trim().isNotEmpty) {
      return [_normalizeBaseUrl(_envApiBaseUrl)];
    }

    return [_normalizeBaseUrl(_defaultApiBaseUrl)];
  }

  static String get _defaultApiBaseUrl {
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.windows:
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.android:
        case TargetPlatform.iOS:
        case TargetPlatform.fuchsia:
          // Default to the deployed Droplet so physical devices can connect
          // immediately. Override with BACKEND_API_BASE_URL when developing
          // against a local backend or a different server.
          return _defaultDropletApiBaseUrl;
      }
    }

    return _defaultDropletApiBaseUrl;
  }

  static String get apiBaseUrl {
    if (_resolvedApiBaseUrl != null && _resolvedApiBaseUrl!.isNotEmpty) {
      return _resolvedApiBaseUrl!;
    }
    if (_envApiBaseUrls.trim().isNotEmpty) {
      final configuredUrls = _splitBaseUrls(_envApiBaseUrls);
      if (configuredUrls.isNotEmpty) {
        return configuredUrls.first;
      }
    }
    if (_envApiBaseUrl.isNotEmpty) {
      return _normalizeBaseUrl(_envApiBaseUrl);
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
