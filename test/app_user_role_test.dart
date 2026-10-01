import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/app_service.dart';

void main() {
  group('attendance-only admin role', () {
    test('uses the attendance scope returned by the backend', () {
      const user = app_user(
        username: 'account',
        role: 'ADMIN',
        staffScope: ' Attendance ',
      );

      expect(user.isAttendanceAdmin, isTrue);
    });

    test('keeps a restored legacy account session attendance-only', () {
      const user = app_user(username: 'account', role: 'admin');

      expect(user.isAttendanceAdmin, isTrue);
    });

    test('does not restrict the normal admin account', () {
      const user = app_user(username: 'admin', role: 'admin');

      expect(user.isAttendanceAdmin, isFalse);
    });
  });
}
