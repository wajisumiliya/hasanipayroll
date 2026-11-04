import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';
import 'package:hasani_payroll_portal/services/attendance_batch_print_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents, block;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AttendancePrintDay unpaid(int day,
          {String status = 'UL-UNPAID', bool flag = false, int? assigned}) =>
      AttendancePrintDay(
        day: day,
        workingIn: '',
        workingOut: '',
        morningIn: '',
        morningOut: '',
        afternoonIn: '',
        afternoonOut: '',
        eveningIn: '',
        eveningOut: '',
        status: status,
        workMinutes: 0,
        breakMinutes: 0,
        netMinutes: 0,
        overtimeMinutes: 0,
        lateMinutes: 0,
        assignedNetMinutes: assigned,
        isUnpaid: flag,
      );
  Future<String> print(List<AttendancePrintDay> days,
          {double salary = 1700,
          double? savedSalary,
          double? savedDeduction = 0,
          bool foreign = true,
          DateTime? month}) async =>
      pdfContents(await AttendancePdfService.build(
        employeeId: 'HED2016',
        employeeName: 'Test',
        department: '',
        section: '',
        branchId: 'A',
        isForeignEmployee: foreign,
        month: month ?? DateTime(2026, 10),
        days: days,
        basicSalary: salary,
        payrollBasicSalary: savedSalary,
        unpaidDeductionAmount: savedDeduction,
      ));

  test('stale zero payroll deduction cannot mask two unpaid attendance days',
      () async {
    final text = await print(
        [unpaid(1, assigned: 480), unpaid(2, assigned: 600)],
        savedSalary: 1700);
    final summary = block(text, 'UNPAID HOURS', 'NET HOURS');
    expect(summary, contains('21:00'));
    expect(summary, contains('RM 109.68'));
    expect(text, contains('saved payroll deduction: RM 0.00'));
    expect(text, contains('Printing does not change payroll.'));
  });

  test('historical payroll salary takes precedence over current default',
      () async {
    final text = await print([unpaid(1)],
        salary: 3100, savedSalary: 1700, savedDeduction: 54.84);
    expect(block(text, 'UNPAID HOURS', 'NET HOURS'), contains('RM 54.84'));
    expect(text, contains('Saved payroll salary basis.'));
    expect(text, isNot(contains('Review and save payroll')));
  });

  test('assigned unpaid hours and monetary calendar divisor are independent',
      () async {
    final text = await print(
        [unpaid(1, assigned: 480), unpaid(2, assigned: 600)],
        salary: 1500, foreign: false, month: DateTime(2026, 11));
    final summary = block(text, 'UNPAID HOURS', 'NET HOURS');
    expect(summary, contains('18:00'));
    expect(summary, contains('RM 100.00'));
    expect(text, contains('Current salary default estimate.'));
  });

  test('unpaid flag and legacy statuses use the same membership as payroll',
      () async {
    for (final status in ['UL', 'UL-UNPAID', 'UNPAID', 'UNPAID LEAVE']) {
      final text = await print([unpaid(1, status: status, flag: true)],
          salary: 3100, foreign: false);
      final summary = block(text, 'UNPAID HOURS', 'NET HOURS');
      expect(summary, contains('07:30'));
      expect(summary, contains('RM 100.00'));
    }
    final flagged =
        await print([unpaid(1, status: '', flag: true)], salary: 3100);
    expect(block(flagged, 'UNPAID HOURS', 'NET HOURS'), contains('RM 100.00'));
    final paid = await print([unpaid(1, status: 'MC')], savedDeduction: 10);
    expect(block(paid, 'UNPAID HOURS', 'NET HOURS'), contains('RM 0.00'));
    expect(paid, contains('saved payroll deduction: RM 10.00'));
  });

  test('missing salary is marked unverified instead of fabricating money',
      () async {
    final text = await print([unpaid(1)], salary: 0, savedDeduction: 80);
    expect(block(text, 'UNPAID HOURS', 'NET HOURS'), contains('RM 80.00'));
    expect(text, contains('basic salary is unavailable'));
  });

  test('batch and single unpaid deductions use the same historical salary',
      () async {
    final text = pdfContents(await AttendanceBatchPrintService.build(data: {
      'employees': [
        {
          'employee_id': 'HED2016',
          'name': 'Test',
          'branch_id': 'A',
          'address': 'FRN'
        }
      ],
      'salaries': [
        {
          'employee_id': 'HED2016',
          'basic_salary': 3100,
          'epf_category': 'normal'
        }
      ],
      'payroll': [
        {
          'employee_id': 'HED2016',
          'basic_salary': 1700,
          'overtime': 0,
          'unpaid_deduction': 0
        }
      ],
      'attendance': [
        for (var day = 1; day <= 2; day++)
          {
            'employee_id': 'HED2016',
            'attendance_date': '2026-10-0$day',
            'status': 'UL-UNPAID'
          }
      ],
      'monthly_rosters': [],
      'daily_rosters': [],
    }, employeeIds: [
      'HED2016'
    ], month: DateTime(2026, 10), branchName: 'A'));
    final summary = block(text, 'UNPAID HOURS', 'NET HOURS');
    expect(summary, contains('21:00'));
    expect(summary, contains('RM 109.68'));
    expect(text, contains('saved payroll deduction: RM 0.00'));
  });
}
