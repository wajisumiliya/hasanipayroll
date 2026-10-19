import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/database_session.dart';

void main() {
  test('legacy database keeps its API token', () {
    expect(
      databaseSessionToken(
        usesNeon: false,
        accessToken: 'api-token',
        dataAccessToken: 'neon-token',
      ),
      'api-token',
    );
  });

  test('Neon uses the separately signed data token', () {
    expect(
      databaseSessionToken(
        usesNeon: true,
        accessToken: 'api-token',
        dataAccessToken: 'neon-token',
      ),
      'neon-token',
    );
  });

  test('Neon refuses to substitute an API token for a missing data token', () {
    for (final missing in <String?>[null, '', '   ']) {
      expect(
        () => databaseSessionToken(
          usesNeon: true,
          accessToken: 'api-token',
          dataAccessToken: missing,
        ),
        throwsStateError,
      );
    }
  });

  test('logout clears database authorization even when a data token remains',
      () {
    expect(
      databaseSessionToken(
        usesNeon: true,
        accessToken: null,
        dataAccessToken: 'neon-token',
      ),
      isNull,
    );
  });
}
