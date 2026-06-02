import 'package:http/http.dart' as http;

class PlatformHttpClient {
  final http.Client _client;
  PlatformHttpClient({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) {
    return _client.get(uri, headers: headers);
  }

  void close() => _client.close();
}
