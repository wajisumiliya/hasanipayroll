import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';

void main() {
  // No database client is initialized: these calls must neither read nor write
  // payroll when the sheet inputs have already been loaded.
  const salary = <String, dynamic>{
    'basic_salary': 2600,
    'epf_category': 'normal1',
    'eis_applicable': true,
    'epf_enabled': false,
    'socso_enabled': false,
    'eis_enabled': false,
  };
  Future<PayrollGenerationItem> preview(List<Map<String, dynamic>> rows,
          {String id = 'TEST001', String address = ''}) =>
      AttendancePayrollService.previewEmployeePayroll(
        employee: {'employee_id': id, 'name': 'Test', 'address': address},
        month: DateTime(2026, 10),
        attendance: rows,
        salaryDefault: salary,
        rosterRows: const [],
      );

  test('pre-payroll print calculates unpaid and approved OT without saving',
      () async {
    final result = await preview([
      {'attendance_date': '2026-10-01', 'status': 'UL-UNPAID'},
      {
        'attendance_date': '2026-10-02',
        'status': 'Present',
        'net_working_minutes': 510,
        'approved_ot_minutes': 60,
      },
    ]);
    expect(result.calculated, isTrue);
    expect(result.generated, isFalse);
    expect(result.unpaidDays, 1);
    expect(result.unpaidDeduction, 83.87);
    expect(result.overtimeDuration, 1);
    expect(result.overtimeAmount, 20);
  });

  test('print estimate does not pay unapproved OT or ordinary absence',
      () async {
    final result = await preview([
      {'attendance_date': '2026-10-01', 'status': 'Absent'},
      {
        'attendance_date': '2026-10-02',
        'status': 'Present',
        'net_working_minutes': 600,
        'overtime_minutes': 150,
      },
    ]);
    expect(result.unpaidDeduction, 0);
    expect(result.overtimeAmount, 0);
  });

  test('foreign staff preview retains explicit unpaid and no shortage rule',
      () async {
    final result = await preview([
      {'attendance_date': '2026-10-01', 'status': 'UNPAID'},
      {
        'attendance_date': '2026-10-02',
        'status': 'Present',
        'net_working_minutes': 300,
      },
    ], address: 'FRN');
    expect(result.unpaidDeduction, 83.87);
    expect(result.lateDeduction, 0);
    expect(result.generated, isFalse);
  });
}
