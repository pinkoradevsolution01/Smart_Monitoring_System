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
    final data = await getJson(path, queryParameters: queryParameters);
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Expected JSON object response from GET $path');
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final data = await postJson(path, body: body);
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Expected JSON object response from POST $path');
  }

  Future<dynamic> getJson(
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

  Future<dynamic> postJson(
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

  Future<dynamic> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _client.patch(
      uri,
      headers: BackendConfig.defaultHeaders,
      body: body == null ? null : jsonEncode(body),
    );
    return _processResponse(response);
  }

  Future<dynamic> deleteJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = _buildUri(path, queryParameters);
    final response = await _client.delete(
      uri,
      headers: BackendConfig.defaultHeaders,
    );
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        final preview = response.body.length > 160
            ? response.body.substring(0, 160)
            : response.body;
        throw Exception(
          'Backend returned non-JSON success response (${response.request?.url}): $preview',
        );
      }
    }

    final url = response.request?.url.toString() ?? 'unknown url';
    String message = 'Server responded with status $statusCode from $url';
    if (response.body.isNotEmpty) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic> && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {
        final preview = response.body.length > 240
            ? response.body.substring(0, 240)
            : response.body;
        message = 'Non-JSON error response from $url: $preview';
      }
    }

    throw Exception(message);
  }
}
