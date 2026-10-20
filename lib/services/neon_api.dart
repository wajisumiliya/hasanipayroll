import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:postgrest/postgrest.dart';

/// One session for the existing authenticated Node API and its Neon adapter.
/// Employee photo bytes use this same authenticated backend.
class NeonApi {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hasaniworkhub.onrender.com',
  );
  static String get baseUrl =>
      _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  static String? _accessToken;
  static int sessionVersion = 0;
  static PostgrestClient createDatabaseClient({http.Client? httpClient}) {
    final database = PostgrestClient(
      '$baseUrl/api/data',
      httpClient: httpClient,
    );
    database.setAuth(_accessToken);
    return database;
  }

  static void setAccessToken(String? token) {
    if (token != _accessToken) sessionVersion++;
    _accessToken = token;
  }

  static Future<Map<String, dynamic>> jsonRequest(
    String path, {
    String method = 'POST',
    Map<String, dynamic>? body,
    http.Client? client,
  }) async {
    if (!path.startsWith('/api/')) throw ArgumentError('Invalid API path');
    final token = _accessToken;
    if (token == null || token.isEmpty)
      throw StateError('Please sign in again.');
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (body != null) request.body = jsonEncode(body);
    final transport = client ?? http.Client();
    try {
      final response = await http.Response.fromStream(
        await transport.send(request).timeout(const Duration(seconds: 45)),
      );
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is! Map) throw StateError('Invalid server response.');
      final data = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['ok'] == false) {
        throw StateError(data['message']?.toString() ?? 'Request failed.');
      }
      return data;
    } finally {
      if (client == null) transport.close();
    }
  }

  static Future<Uint8List?> photoRequest(
    String employeeId, {
    String method = 'GET',
    Uint8List? bytes,
    String? contentType,
    http.Client? client,
  }) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Please sign in again.');
    }
    final request = http.Request(
      method,
      Uri.parse('$baseUrl/api/employee-photos/${Uri.encodeComponent(employeeId)}'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    if (contentType != null) request.headers['Content-Type'] = contentType;
    if (bytes != null) request.bodyBytes = bytes;
    final transport = client ?? http.Client();
    try {
      final response = await http.Response.fromStream(
        await transport.send(request).timeout(const Duration(seconds: 45)),
      );
      if (method == 'GET' && response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Unable to $method employee photo (${response.statusCode}).');
      }
      return method == 'GET' ? response.bodyBytes : null;
    } finally {
      if (client == null) transport.close();
    }
  }
}
