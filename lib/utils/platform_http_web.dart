import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

class PlatformHttpClient {
  final BrowserClient _client;
  PlatformHttpClient({BrowserClient? client})
    : _client = client ?? BrowserClient();

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) {
    return _client.get(uri, headers: headers);
  }

  void close() => _client.close();
}
