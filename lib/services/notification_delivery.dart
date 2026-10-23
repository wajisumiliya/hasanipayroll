class NotificationDelivery {
  final int sent;
  final String status;
  final List<String> errors;
  NotificationDelivery.fromJson(Map<String, dynamic> data)
      : sent = (data['sent'] as num?)?.toInt() ?? 0,
        status = data['pushStatus']?.toString() ?? 'unavailable',
        errors = (data['pushErrors'] as List? ?? [])
            .map((e) => e.toString())
            .toList();

  String get message {
    switch (status) {
      case 'sent':
        return 'Saved to inbox. Push accepted for $sent device(s).';
      case 'partial':
        return 'Saved to inbox. Push accepted for $sent device(s); some devices failed.';
      case 'not_configured':
        return 'Saved to inbox. Push unavailable: Firebase server credentials are missing.';
      case 'invalid_configuration':
        return 'Saved to inbox. Push unavailable: Firebase server configuration is invalid.';
      case 'authentication_failed':
        return 'Saved to inbox. Firebase authentication failed; check server credentials and network access.';
      case 'no_devices':
        return 'Saved to inbox. No registered device: the employee must sign in and allow notifications.';
      default:
        if (errors.contains('SENDER_ID_MISMATCH')) {
          return 'Saved to inbox. Push failed: the device and server use different Firebase projects.';
        }
        if (errors.contains('PERMISSION_DENIED')) {
          return 'Saved to inbox. Push failed: check Firebase API access and service-account permissions.';
        }
        return 'Saved to inbox. Push delivery failed${errors.isEmpty ? '.' : ': ${errors.join(', ')}.'}';
    }
  }
}
