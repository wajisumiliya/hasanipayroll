import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/qr_attendance_service.dart';

void main() {
  test(
      'retry identifiers are unique UUIDs and timestamps show Malaysia 12-hour time',
      () {
    final ids = List.generate(100, (_) => QrAttendanceService.requestId());
    expect(ids.toSet().length, 100);
    expect(
        ids.every((id) => RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id)),
        isTrue);
    expect(QrAttendanceService.malaysiaTime('2026-10-31T16:05:06Z'),
        '01/11/2026 12:05:06 AM');
    expect(QrAttendanceService.malaysiaTime('2026-10-31T04:00:00Z'),
        '31/10/2026 12:00:00 PM');
  });
}
