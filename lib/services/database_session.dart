/// Choose the credential for the configured database without falling back to
/// a token intended for a different service.
String? databaseSessionToken({
  required bool usesNeon,
  required String? accessToken,
  required String? dataAccessToken,
}) {
  if (accessToken == null || accessToken.trim().isEmpty) return null;
  if (!usesNeon) return accessToken;
  if (dataAccessToken == null || dataAccessToken.trim().isEmpty) {
    throw StateError(
      'Neon database access is not configured on the payroll server. '
      'Configure DATA_API_JWT_PRIVATE_KEY and sign in again.',
    );
  }
  return dataAccessToken;
}
