import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// One session for the existing authenticated Node API and its Neon adapter.
/// Object-storage requests intentionally never receive this session token.
class NeonApi {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://hasaniworkhub.onrender.com',
  );
  static String get baseUrl =>
      _configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
  static String? _accessToken;
  static int sessionVersion = 0;
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

  static Future<void> objectRequest(
    Map<String, dynamic> signed, {
    required String method,
    Uint8List? bytes,
    http.Client? client,
  }) async {
    final uri = Uri.parse(signed['url'].toString());
    if (uri.scheme != 'https' ||
        !uri.host.endsWith('.r2.cloudflarestorage.com')) {
      throw StateError('Invalid photo storage endpoint.');
    }
    final request = http.Request(method, uri);
    final headers = signed['headers'];
    if (headers is Map) {
      request.headers.addAll(headers
          .map((key, value) => MapEntry(key.toString(), value.toString())));
    }
    if (bytes != null) request.bodyBytes = bytes;
    final transport = client ?? http.Client();
    try {
      final response =
          await transport.send(request).timeout(const Duration(seconds: 45));
      await response.stream.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw StateError('Photo storage request failed.');
    } finally {
      if (client == null) transport.close();
    }
  }
}
