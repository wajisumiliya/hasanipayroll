import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/models/payroll.dart';
import 'package:hasani_payroll_portal/services/payroll_calculation_service.dart';
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';
import 'package:hasani_payroll_portal/services/pdf_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FRN daily rates match the requested examples in every calendar month', () {
    for (final year in [2024, 2026]) {
      for (var month = 1; month <= 12; month++) {
        for (final example in {1700.0: 60.7, 2000.0: 71.4}.entries) {
          expect(PayrollCalculationService.unpaidDailyRate(
            basicSalary: example.key, month: DateTime(year, month),
            isForeignEmployee: true,
          ), example.value, reason: '$year-$month salary ${example.key}');
        }
      }
    }
  });

  test('FRN zero salary remains zero and local calendar rates stay unchanged', () {
    expect(PayrollCalculationService.unpaidDailyRate(
      basicSalary: 0, month: DateTime(2026, 10), isForeignEmployee: true,
    ), 0);
    for (var month = 1; month <= 12; month++) {
      final days = DateTime(2026, month + 1, 0).day;
      expect(PayrollCalculationService.unpaidDailyRate(
        basicSalary: 1700, month: DateTime(2026, month),
      ), 1700 / days);
    }
  });

  test('payroll preview multiplies rounded FRN rate by unpaid days in all months', () async {
    for (var month = 1; month <= 12; month++) {
      for (final salary in {1700.0: 121.4, 2000.0: 142.8}.entries) {
        // No database is initialized: fully preloaded previews must stay read-only.
        final result = await AttendancePayrollService.previewEmployeePayroll(
          employee: {'employee_id': 'TEST-FRN', 'name': 'Test', 'address': 'FRN'},
          month: DateTime(2026, month),
          attendance: [for (var day = 1; day <= 2; day++)
            {'attendance_date': DateTime(2026, month, day).toIso8601String(),
              'status': 'UL-UNPAID'}],
          salaryDefault: {'basic_salary': salary.key, 'epf_category': 'normal',
            'epf_enabled': false, 'socso_enabled': false, 'eis_enabled': false},
          rosterRows: [],
        );
        expect(result.calculated, true);
        expect(result.generated, false);
        expect(result.unpaidDays, 2);
        expect(result.unpaidDeduction, salary.value);
      }
    }
  });

  test('legacy salary-address FRN marker also selects the fixed 28-day rule', () async {
    final result = await AttendancePayrollService.previewEmployeePayroll(
      employee: {'employee_id': 'TEST-FRN', 'name': 'Test', 'address': ''},
      month: DateTime(2024, 2),
      attendance: [{'attendance_date': '2024-02-01', 'status': 'UNPAID'}],
      salaryDefault: {'basic_salary': 1700, 'address': 'FRN', 'epf_category': 'normal',
        'epf_enabled': false, 'socso_enabled': false, 'eis_enabled': false},
      rosterRows: [],
    );
    expect(result.unpaidDeduction, 60.7);
  });

  test('payslip unpaid hours use FRN rates and preserve recorded historical days', () async {
    const employee = Employee(employeeId: 'TEST-FRN', name: 'Test',
      designation: '', department: '', email: '', newIcNo: '', bankCode: '',
      bankAccount: '', address: 'FRN');
    for (final legacy in [false, true]) {
      final payroll = PayrollRecord.fromJson({
        'id': 'P1', 'employee_id': 'TEST-FRN', 'period': '2026-10-01',
        'basic_salary': 1700, 'unpaid_deduction': legacy ? 548.39 : 607,
        'remarks': legacy ? 'Unpaid days: 10. Unpaid deduction: 548.39.' : null,
      });
      final text = pdfContents(await PdfService.buildPayslip(employee: employee, p: payroll));
      expect(text, contains('UNPAID 105.00 HRS'));
    }
  });
}
