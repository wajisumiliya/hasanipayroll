import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';
import 'package:hasani_payroll_portal/services/payroll_calculation_service.dart';

void main() {
  test('BLK011 receives RM100 on top of normal employer EPF', () {
    expect(
        PayrollCalculationService.employerEpfWithMonthlyTopUp(
            employeeId: 'BLK011', calculatedEmployer: 338),
        438);
    expect(
        PayrollCalculationService.employerEpfWithMonthlyTopUp(
            employeeId: ' blk011 ', calculatedEmployer: 52),
        152);
    expect(
        PayrollCalculationService.employerEpfWithMonthlyTopUp(
            employeeId: 'BLK011', calculatedEmployer: 0),
        100);
    expect(
        PayrollCalculationService.employerEpfWithMonthlyTopUp(
            employeeId: 'BLK012', calculatedEmployer: 338),
        338);
  });

  Future<PayrollGenerationItem> preview(String id, DateTime month,
          {bool epfEnabled = true,
          double basic = 2600,
          String epfCategory = 'normal'}) =>
      AttendancePayrollService.previewEmployeePayroll(
        employee: {'employee_id': id, 'name': 'Test employee'},
        month: month,
        attendance: const [],
        rosterRows: const [],
        salaryDefault: {
          'basic_salary': basic,
          'epf_category': epfCategory,
          'epf_enabled': epfEnabled,
          'socso_enabled': false,
          'eis_enabled': false,
        },
      );

  test('All 12 monthly previews add once without changing employee deductions',
      () async {
    for (var month = 1; month <= 12; month++) {
      final date = DateTime(2026, month);
      final result = await preview('BLK011', date);
      final repeated = await preview('BLK011', date);
      final other = await preview('BLK012', date);
      expect(result.calculated, isTrue);
      expect(result.generated, isFalse);
      expect(result.epfEmployer, 152);
      expect(repeated.epfEmployer, 152);
      expect(other.epfEmployer, 52);
      expect(result.epfEmployee, other.epfEmployee);
      expect(result.socsoEmployee, other.socsoEmployee);
      expect(result.eisEmployee, other.eisEmployee);
      expect(result.unpaidDeduction, other.unpaidDeduction);
    }
  });

  test('BLK011 monthly addition remains when normal EPF is disabled or zero',
      () async {
    final disabled =
        await preview('BLK011', DateTime(2026, 10), epfEnabled: false);
    final belowThreshold =
        await preview('BLK011', DateTime(2026, 11), basic: 400);
    expect(disabled.epfEmployee, 0);
    expect(disabled.epfEmployer, 100);
    expect(belowThreshold.epfEmployee, 0);
    expect(belowThreshold.epfEmployer, 100);
  });

  test('Scheduled EPF also adds RM100 to employer only', () async {
    final date = DateTime(2026, 10);
    final adjusted = await preview('BLK011', date, epfCategory: 'normal1');
    final baseline = await preview('BLK012', date, epfCategory: 'normal1');
    expect(adjusted.epfEmployer, baseline.epfEmployer + 100);
    expect(adjusted.epfEmployee, baseline.epfEmployee);
  });
}
