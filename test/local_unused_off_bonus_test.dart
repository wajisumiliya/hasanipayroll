import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents, block;
import 'package:hasani_payroll_portal/services/payroll_calculation_service.dart';
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
  int days(List<Map<String, dynamic>> attendance,
          {bool local = true, DateTime? now}) =>
      PayrollCalculationService.localUnusedOffBonusDays(
          month: month,
          isLocalEmployee: local,
          attendance: attendance,
          now: now ?? DateTime.utc(2026, 11, 1));

  test('only four OFF days in complete local 31-day month earn one day', () {
    expect(days(rows()), 1);
    expect(days(rows(off: 5)), 0);
    expect(days(rows(off: 3)), 0);
    expect(days(rows(), local: false), 0);
    expect(days(rows(length: 30)), 0);
    expect(days([...rows(), rows().last]), 0);
    expect(days(rows(), now: DateTime.utc(2026, 10, 15)), 0);
    final absent = rows();
    absent.last = {
      ...absent.last,
      'status': 'Absent',
      'net_working_minutes': 0
    };
    expect(days(absent), 0);
    expect(
        PayrollCalculationService.localUnusedOffBonusDays(
            month: DateTime(2026, 11),
            isLocalEmployee: true,
            attendance: rows(),
            now: DateTime.utc(2026, 12, 1)),
        0);
  });

  test('normal daily rate follows existing ten-sen payroll rounding', () {
    expect(
        PayrollCalculationService.localUnusedOffBonusAmount(
            basicSalary: 1700, bonusDays: 1),
        65.4);
    expect(
        PayrollCalculationService.localUnusedOffBonusAmount(
            basicSalary: 1700, bonusDays: 0),
        0);
  });

  test(
      'payroll preview separates bonus from approved OT, even OT-excluded staff',
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
      expect(result.restDayBonusAmount, 65.4);
      expect(result.restDayBonusMinutes, 450);
      expect(result.overtimeAmount, 0);
      expect(result.overtimeDuration, 0);
    }
  });
  test('attendance sheet credits bonus hours separately from OT money',
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
    expect(block(text, 'APPROVED OT', 'Unused fifth OFF'), contains('00:00'));
    expect(block(text, 'NET HOURS', 'APPROVED OT'), contains('202:30'));
    expect(text, contains('RM 65.40'));
    expect(text, contains('Paid through Bonus,'));
  });
}
