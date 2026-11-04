import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents, block;
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';

void main() {
  final month = DateTime(2026, 10);
  List<Map<String, dynamic>> rows({int off = 4, int length = 31}) =>
      List.generate(
          length,
          (i) => {
                'attendance_date': DateTime(2026, 10, i + 1).toIso8601String(),
                'status': i < off ? 'OFF' : 'Present',
                'net_working_minutes': i < off ? 0 : 450,
              });
  test('payroll preview creates no unused-OFF bonus, even for a complete month',
      () async {
    for (final id in ['TEST001', 'HED1016']) {
      final result = await AttendancePayrollService.previewEmployeePayroll(
          employee: {'employee_id': id, 'name': 'Test', 'address': ''},
          month: month,
          attendance: rows(),
          rosterRows: [],
          salaryDefault: {
            'basic_salary': 1700,
            'epf_category': 'normal1',
            'eis_applicable': true,
            'epf_enabled': false,
            'socso_enabled': false,
            'eis_enabled': false,
          });
      expect(result.calculated, true);
      expect(result.restDayBonusAmount, 0);
      expect(result.restDayBonusMinutes, 0);
      expect(result.overtimeAmount, 0);
      expect(result.overtimeDuration, 0);
    }
  });
  test('attendance sheet does not infer unused-OFF bonus hours or money',
      () async {
    final bytes = await AttendancePdfService.build(
        employeeId: 'TEST001',
        employeeName: 'Test',
        department: '',
        section: '',
        branchId: 'A',
        isForeignEmployee: false,
        month: month,
        basicSalary: 1700,
        approvedOtAmount: 0,
        days: List.generate(
            31,
            (i) => AttendancePrintDay(
                day: i + 1,
                workingIn: '',
                workingOut: '',
                morningIn: '',
                morningOut: '',
                afternoonIn: '',
                afternoonOut: '',
                eveningIn: '',
                eveningOut: '',
                status: i < 4 ? 'OFF' : 'Present',
                workMinutes: i < 4 ? 0 : 540,
                breakMinutes: i < 4 ? 0 : 90,
                netMinutes: i < 4 ? 0 : 450,
                overtimeMinutes: 0,
                lateMinutes: 0)));
    final text = pdfContents(bytes);
    expect(text, isNot(contains('OT / BONUS HOURS')));
    expect(block(text, 'APPROVED OT', 'DAY'), contains('00:00'));
    expect(block(text, 'NET HOURS', 'APPROVED OT'), contains('202:30'));
    expect(text, isNot(contains('RM 65.40')));
    expect(text, isNot(contains('Paid through Bonus,')));
    expect(text, isNot(contains('Unused fifth OFF')));
  });
}
