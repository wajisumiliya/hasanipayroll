import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';

void main() {
  group('SOCSO First Category employer contribution lookup', () {
    test('preserves the historical RM2000 payroll mapping', () {
      expect(
        AttendancePayrollService.employerShareForEmployeeContribution(
          contribution: 'socso',
          employeeShare: 24.40,
        ),
        34.15,
      );
    });

    test('keeps adjacent contribution brackets correctly paired', () {
      expect(
        AttendancePayrollService.employerShareForEmployeeContribution(
          contribution: 'socso',
          employeeShare: 23.10,
        ),
        32.35,
      );
      expect(
        AttendancePayrollService.employerShareForEmployeeContribution(
          contribution: 'socso',
          employeeShare: 25.60,
        ),
        35.85,
      );
    });
  });
}
