/// Backend REST API configuration for MySQL-based sync and license services.
class BackendConfig {
  /// Set this to your Node.js backend URL, including `/api` if desired.
  /// Example: `http://localhost:3000/api`
  static const String apiBaseUrl = 'http://192.168.1.9:3000/api';

  /// Google OAuth web client ID used by `google_sign_in` to request an ID token
  /// on Android/iOS. Pass this at build time with:
  /// `--dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com`
  static const String googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

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
