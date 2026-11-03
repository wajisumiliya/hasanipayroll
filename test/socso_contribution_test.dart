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

  group('BGR015 configured SOCSO contributions', () {
    Future<PayrollGenerationItem> preview({
      int month = 1,
      bool enabled = true,
      String category = 'type1',
      double basicSalary = 1700,
    }) =>
        AttendancePayrollService.previewEmployeePayroll(
          employee: {'employee_id': 'BGR015', 'name': 'Test employee'},
          month: DateTime(2026, month),
          attendance: [],
          rosterRows: [],
          salaryDefault: {
            'basic_salary': basicSalary,
            'epf_category': 'normal',
            'eis_applicable': false,
            'socso_enabled': enabled,
            'socso_category': category,
          },
        );

    test('has no fixed employee deduction override', () {
      expect(AttendancePayrollService.fixedSocsoEmployeeFor('bgr015'), isNull);
    });

    test('uses the configured Type 1 schedule before and after August', () async {
      for (final month in [1, 10]) {
        final result = await preview(month: month);
        expect(result.calculated, true);
        expect(result.generated, false);
        expect(result.socsoEmployee, 20.60);
        expect(result.socsoEmployer, 28.85);
      }
    });

    test('still respects disabled SOCSO and the eligibility threshold', () async {
      for (final result in [
        await preview(enabled: false),
        await preview(basicSalary: 400),
      ]) {
        expect(result.calculated, true);
        expect(result.socsoEmployee, 0);
        expect(result.socsoEmployer, 0);
      }
    });

    test('still respects employer-only Type 2', () async {
      final result = await preview(category: 'type2');
      expect(result.calculated, true);
      expect(result.socsoEmployee, 0);
      expect(result.socsoEmployer, 20.60);
    });
  });
}
