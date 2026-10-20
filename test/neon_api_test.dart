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
          request: request, headers: {'content-type': 'application/json'});
    });
    final database = NeonApi.createDatabaseClient(httpClient: client);
    final rows = await database.from('employees').select('employee_id');
    expect(rows.single['employee_id'], 'FIX_E1');
    await database.dispose();
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

  test('photo upload sends bytes and authentication only to the app backend',
      () async {
    NeonApi.setAccessToken('private-session');
    final client = MockClient((request) async {
      expect(request.url.origin, Uri.parse(NeonApi.baseUrl).origin);
      expect(request.url.path, '/api/employee-photos/FIX_E1');
      expect(request.headers['Authorization'], 'Bearer private-session');
      expect(request.headers['Content-Type'], 'image/jpeg');
      expect(request.bodyBytes, [255, 216, 255, 217]);
      return http.Response('{"ok":true}', 200);
    });
    await NeonApi.photoRequest('FIX_E1',
        method: 'PUT',
        bytes: Uint8List.fromList([255, 216, 255, 217]),
        contentType: 'image/jpeg',
        client: client);
  });

  test(
      'photo read authenticates and returns bytes, missing photos use fallback',
      () async {
    NeonApi.setAccessToken('private-session');
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer private-session');
      return request.url.path.endsWith('FIX_MISSING')
          ? http.Response('', 404)
          : http.Response.bytes([1, 2, 3], 200);
    });
    expect(await NeonApi.photoRequest('FIX_E1', client: client), [1, 2, 3]);
    expect(await NeonApi.photoRequest('FIX_MISSING', client: client), null);
    NeonApi.setAccessToken(null);
    await expectLater(
        NeonApi.photoRequest('FIX_E1', client: client), throwsStateError);
  });
}
