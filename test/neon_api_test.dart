import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hasani_payroll_portal/services/neon_api.dart';

void main() {
  tearDown(() => NeonApi.setAccessToken(null));

  test('database queries use the Node endpoint and its backend JWT', () async {
    NeonApi.setAccessToken('backend-jwt');
    final client = MockClient((request) async {
      expect(request.url.origin, Uri.parse(NeonApi.baseUrl).origin);
      expect(request.url.path, '/api/data/employees');
      expect(request.headers['Authorization'], 'Bearer backend-jwt');
      expect(request.headers.containsKey('apikey'), false);
      return http.Response('[{"employee_id":"FIX_E1"}]', 200,
          headers: {'content-type': 'application/json'});
    });
    final database = NeonApi.createDatabaseClient(httpClient: client);
    final rows = await database.from('employees').select('employee_id');
    expect(rows.single['employee_id'], 'FIX_E1');
    client.close();
  });

  test('Neon API sends the current backend session token', () async {
    NeonApi.setAccessToken('backend-session');
    final client = MockClient((request) async {
      expect(request.url.path, '/api/notifications/send');
      expect(request.headers['Authorization'], 'Bearer backend-session');
      expect(jsonDecode(request.body), {'title': 'Hello'});
      return http.Response('{"ok":true,"inbox":1}', 200);
    });
    final result = await NeonApi.jsonRequest('/api/notifications/send',
        body: {'title': 'Hello'}, client: client);
    expect(result['inbox'], 1);
  });

  test('clearing the session blocks authenticated API calls', () async {
    NeonApi.setAccessToken(null);
    await expectLater(NeonApi.jsonRequest('/api/admin/users', method: 'GET'),
        throwsStateError);
  });

  test('photo upload never forwards the backend bearer token to R2', () async {
    NeonApi.setAccessToken('private-session');
    final client = MockClient((request) async {
      expect(request.headers.containsKey('Authorization'), false);
      expect(request.headers['Content-Type'], 'image/jpeg');
      expect(request.bodyBytes, [1, 2, 3]);
      return http.Response('', 200);
    });
    await NeonApi.objectRequest({
      'url':
          'https://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com/photos/one?signature=fixture',
      'headers': {'Content-Type': 'image/jpeg'},
    }, method: 'PUT', bytes: Uint8List.fromList([1, 2, 3]), client: client);
  });

  test('photo upload rejects an unexpected storage host', () async {
    await expectLater(
        NeonApi.objectRequest({
          'url': 'https://example.invalid/photo',
          'headers': <String, String>{},
        }, method: 'PUT'),
        throwsStateError);
  });
}
