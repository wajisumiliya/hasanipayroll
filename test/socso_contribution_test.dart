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

  group('Fixed SOCSO employee deductions', () {
    test('carries August values forward for configured employees', () {
      expect(AttendancePayrollService.fixedSocsoEmployeeFor('BAS028'), 0);
      expect(
        AttendancePayrollService.fixedSocsoEmployeeFor('hed-temp-019'),
        6.75,
      );
      expect(AttendancePayrollService.fixedSocsoEmployeeFor('LKW012'), 7.75);
      expect(AttendancePayrollService.fixedSocsoEmployeeFor('LKW038'), 8.25);
      expect(AttendancePayrollService.fixedSocsoEmployeeFor('BAJ010'), 9.75);
    });

    test('does not override employees outside the configured list', () {
      expect(AttendancePayrollService.fixedSocsoEmployeeFor('HED2073'), isNull);
    });
  });
}
