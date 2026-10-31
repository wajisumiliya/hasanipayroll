import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_allowance_service.dart';

void main() {
  test('any monthly report removes eligibility, including unknown late minutes',
      () async {
    final result = await AttendanceAllowanceService.disqualifiedEmployees(
      employeeIds: ['MC1', 'UL1', 'LATE1', 'CLEAN'],
      loadLate: () async => {
        'reports': [
          {'employee_id': 'LATE1', 'count': 3, 'arrival_minutes': null},
          {'employee_id': 'OTHER', 'count': 4},
        ]
      },
      loadStatus: (status, ids) async => {
        'reports': [
          {'employee_id': status == 'MC' ? ' mc1 ' : 'UL1'},
        ]
      },
    );
    expect(result, {'MC1', 'UL1', 'LATE1'});
  });

  test(
      'a report failure stops eligibility calculation instead of paying allowance',
      () async {
    await expectLater(
        AttendanceAllowanceService.disqualifiedEmployees(
          employeeIds: ['E1'],
          loadLate: () async => {'reports': []},
          loadStatus: (status, ids) async =>
              throw StateError('Report unavailable'),
        ),
        throwsStateError);
  });

  test(
      'status lookups stay within report employee limit for large payroll runs',
      () async {
    final sizes = <int>[];
    await AttendanceAllowanceService.disqualifiedEmployees(
      employeeIds: List.generate(1001, (i) => 'E$i'),
      loadLate: () async => {'reports': []},
      loadStatus: (status, ids) async {
        sizes.add(ids.length);
        return {'reports': []};
      },
    );
    expect(sizes, [500, 500, 500, 500, 1, 1]);
  });
}
