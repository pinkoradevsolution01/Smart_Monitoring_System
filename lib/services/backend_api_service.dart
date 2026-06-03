import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_config.dart';

class ApiClient {
  final http.Client _client;

  ApiClient([http.Client? client]) : _client = client ?? http.Client();

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final baseUrl = BackendConfig.apiBaseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$baseUrl/$normalizedPath');
    return uri.replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final response = await _client.get(
      uri,
      headers: BackendConfig.defaultHeaders,
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _client.post(
      uri,
      headers: BackendConfig.defaultHeaders,
      body: body == null ? null : jsonEncode(body),
    );
    return _processResponse(response);
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Unexpected JSON response: ${response.body}');
      }
    }

    String message = 'Server responded with status $statusCode';
    if (response.body.isNotEmpty) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {
        message = response.body;
      }
    }

    throw Exception(message);
  }
}
