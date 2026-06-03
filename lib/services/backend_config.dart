/// Backend REST API configuration for MySQL-based sync and license services.
class BackendConfig {
  /// Set this to your Node.js backend URL, including `/api` if desired.
  /// Example: `http://localhost:3000/api`
  static const String apiBaseUrl = 'http://localhost:3000/api';

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
