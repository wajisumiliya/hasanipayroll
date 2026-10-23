import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/notification_service.dart';
import 'package:hasani_payroll_portal/services/notification_delivery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('unavailable notification plugins cannot block a logged-out startup',
      () async {
    await NotificationService.initialize();
  });
  test('inbox success never claims push success when Firebase is missing', () {
    final result = NotificationDelivery.fromJson({
      'ok': true,
      'inbox': 1,
      'sent': 0,
      'pushStatus': 'not_configured',
    });
    expect(result.message, contains('Saved to inbox'));
    expect(result.message, contains('credentials are missing'));
    expect(result.message, isNot(contains('Push accepted')));
  });
  test('project mismatch gives an actionable result without provider payloads',
      () {
    final result = NotificationDelivery.fromJson({
      'sent': 0,
      'pushStatus': 'failed',
      'pushErrors': ['SENDER_ID_MISMATCH'],
    });
    expect(result.message, contains('different Firebase projects'));
  });
  test('partial delivery reports only the accepted devices', () {
    final result = NotificationDelivery.fromJson({
      'sent': 2,
      'pushStatus': 'partial',
    });
    expect(result.message, contains('2 device(s)'));
    expect(result.message, contains('some devices failed'));
  });
}
