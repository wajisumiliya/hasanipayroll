import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';

void main() {
  group('SOCSO First Category employer contribution lookup', () {
    test('pairs RM7.75 employee share with RM19.40 employer share', () {
      expect(
        AttendancePayrollService.employerShareForEmployeeContribution(
          contribution: 'socso',
          employeeShare: 7.75,
        ),
        19.40,
      );
    });

    test('keeps adjacent contribution brackets correctly paired', () {
      expect(
        AttendancePayrollService.employerShareForEmployeeContribution(
          contribution: 'socso',
          employeeShare: 7.25,
        ),
        18.10,
      );
      expect(
        AttendancePayrollService.employerShareForEmployeeContribution(
          contribution: 'socso',
          employeeShare: 8.25,
        ),
        20.60,
      );
    });
  });
}
