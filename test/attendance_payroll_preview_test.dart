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
  test('FRN full month with one OFF adds one basic/28 day to OT', () async {
    final rows = List<Map<String, dynamic>>.generate(
        31,
        (i) => {
              'attendance_date':
                  '2026-10-${(i + 1).toString().padLeft(2, '0')}',
              'status': i == 0 ? 'OFF' : 'Present',
              'net_working_minutes': i == 0 ? 0 : 630,
            });
    final result = await preview(rows, address: 'FRN');
    expect(result.overtimeAmount, 92.9);
    final excluded = await preview(rows, address: 'FRN', id: 'HED1016');
    expect(excluded.overtimeAmount, 0);
    final partial = await preview(rows.sublist(0, 15), address: 'FRN');
    expect(partial.overtimeAmount, 0);
  });

  test('printed deductible hours and payroll use the same net shortage',
      () async {
    const employee = <String, dynamic>{
      'employee_id': 'TEST001',
      'name': 'Test',
      'branch_id': 'A'
    };
    const roster = <String, dynamic>{
      'employee_id': 'TEST001',
      'branch_id': 'A',
      'week_number': 1,
      'shift_start': '09:00',
      'shift_end': '17:30',
      'break_minutes': 60
    };
    final rows = <Map<String, dynamic>>[
      {
        'attendance_date': '2026-10-01',
        'status': 'Present',
        'check_in': '09:00',
        'check_out': '16:15',
        'net_working_minutes': 375
      }
    ];
    final minutes = AttendancePayrollService.attendanceShortageMinutes(
        employee: employee,
        salaryDefault: salary,
        attendance: rows,
        rosterRows: [roster]);
    final result = await AttendancePayrollService.previewEmployeePayroll(
        employee: employee,
        month: DateTime(2026, 10),
        attendance: rows,
        salaryDefault: salary,
        rosterRows: [roster]);
    expect(minutes, 60);
    expect(result.shortageMinutes, minutes);
    expect(result.lateDeduction, 13.3);
    final madeUp = <Map<String, dynamic>>[
      {
        'attendance_date': '2026-10-01',
        'status': 'Present',
        'check_in': '09:30',
        'check_out': '18:00',
        'net_working_minutes': 450
      }
    ];
    expect(
        AttendancePayrollService.attendanceShortageMinutes(
            employee: employee,
            salaryDefault: salary,
            attendance: madeUp,
            rosterRows: [roster]),
        0);
    expect(
        AttendancePayrollService.attendanceShortageMinutes(
            employee: {...employee, 'address': 'FRN'},
            salaryDefault: salary,
            attendance: rows,
            rosterRows: [roster]),
        0);
  });
}
