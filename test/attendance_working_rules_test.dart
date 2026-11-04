import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_working_rules.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';
import 'package:hasani_payroll_portal/services/attendance_batch_print_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents, block;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  int target(String id, DateTime month, {int off = 2, bool foreign = true}) =>
      AttendanceWorkingRules.monthlyTarget(
          employeeId: id,
          month: month,
          offDays: off,
          isForeignEmployee: foreign);
  int breaks(int actual,
          {bool foreign = true, int work = 720, String status = 'Present'}) =>
      AttendanceWorkingRules.breakMinutes(
          isForeignEmployee: foreign,
          workMinutes: work,
          actualMinutes: actual,
          status: status);

  test('all FRN monthly targets use confirmed decimal hours regardless of OFFs',
      () {
    for (var month = 1; month <= 12; month++) {
      final days = DateTime(2026, month + 1, 0).day;
      if (days != 30 && days != 31) continue;
      for (final id in ['HED2016', 'OTHER-FRN']) {
        for (final off in [0, 1, 2, 4, 5]) {
          expect(target(id, DateTime(2026, month), off: off),
              days == 31 ? 17922 : 17304);
        }
      }
    }
    // Preserve the explicitly named employee's override even without a marker.
    expect(target(' hed2016 ', DateTime(2026, 11), foreign: false), 17304);
    expect(
        target('OTHER', DateTime(2026, 10), foreign: false, off: 4), 27 * 450);
    // February targets were not changed by the 30/31-day request.
    expect(target('HED2016', DateTime(2026, 2)), 26 * 630);
    expect(target('OTHER-FRN', DateTime(2024, 2)), 27 * 630);
  });

  test('FRN marker may come from employee or legacy salary address', () {
    expect(AttendanceWorkingRules.isForeign('FRN'), true);
    expect(AttendanceWorkingRules.isForeign('', 'foreign'), true);
    expect(AttendanceWorkingRules.isForeign(null, null), false);
    expect(AttendanceWorkingRules.isForeign('LOCAL'), false);
  });

  test('only worked FRN breaks strictly below one hour become 90 minutes', () {
    for (final actual in [0, 1, 30, 59]) {
      expect(breaks(actual), 90);
      expect(breaks(actual, foreign: false), actual);
      expect(breaks(actual, work: 0), actual);
    }
    for (final actual in [60, 61, 89, 90, 120]) {
      expect(breaks(actual), actual);
    }
    for (final status in ['MC', 'AL', 'PH-OFF']) {
      expect(breaks(0, status: status), 0);
    }
    expect(breaks(breaks(30)), 90); // Saving/reprinting cannot apply twice.
  });

  AttendancePrintDay day(
          {int actualBreak = 30, int gross = 720, String status = 'Present'}) =>
      AttendancePrintDay(
        day: 1,
        workingIn: '09:00',
        workingOut: '21:00',
        morningIn: '13:00',
        morningOut: '13:30',
        afternoonIn: '',
        afternoonOut: '',
        eveningIn: '',
        eveningOut: '',
        status: status,
        workMinutes: gross,
        breakMinutes: actualBreak,
        netMinutes: gross - actualBreak,
        overtimeMinutes: 0,
        lateMinutes: 0,
      );

  test('single A4 uses adjusted FRN breaks and recalculates net hours',
      () async {
    final text = pdfContents(await AttendancePdfService.build(
      employeeId: 'HED2016',
      employeeName: 'Special employee',
      department: '',
      section: '',
      branchId: 'A',
      isForeignEmployee: true,
      month: DateTime(2026, 10),
      days: [day()],
    ));
    expect(block(text, 'ASSIGNED HOURS', 'GROSS WORK'), contains('298:42'));
    expect(block(text, 'BREAK HOURS', 'LATE HOURS'), contains('01:30'));
    expect(block(text, 'NET HOURS', 'APPROVED OT'), contains('10:30'));
    expect(text, contains('13:30')); // Actual clock evidence is retained.
  });

  test('30-day target prints 288:24 while local breaks stay actual', () async {
    final text = pdfContents(await AttendancePdfService.build(
      employeeId: 'HED2016',
      employeeName: 'Test',
      department: '',
      section: '',
      branchId: 'A',
      isForeignEmployee: false,
      month: DateTime(2026, 11),
      days: [day()],
    ));
    expect(block(text, 'ASSIGNED HOURS', 'GROSS WORK'), contains('288:24'));
    expect(block(text, 'BREAK HOURS', 'LATE HOURS'), contains('00:30'));
    expect(block(text, 'NET HOURS', 'APPROVED OT'), contains('11:30'));
  });

  test('batch uses salary FRN marker and matches single A4 break and net',
      () async {
    final text = pdfContents(await AttendanceBatchPrintService.build(
      data: {
        'employees': [
          {'employee_id': 'HED2016', 'name': 'Test', 'branch_id': 'A'}
        ],
        'salaries': [
          {'employee_id': 'HED2016', 'address': 'FRN', 'epf_category': 'normal'}
        ],
        'payroll': [
          {'employee_id': 'HED2016', 'overtime': 0}
        ],
        'attendance': [
          {
            'employee_id': 'HED2016',
            'attendance_date': '2026-10-01',
            'check_in': '09:00',
            'check_out': '21:00',
            'status': 'Present',
            'morning_in': '13:00',
            'morning_out': '13:30',
            'net_working_minutes': 690
          }
        ],
        'monthly_rosters': [],
        'daily_rosters': [],
      },
      employeeIds: ['HED2016'],
      month: DateTime(2026, 10),
      branchName: 'A',
    ));
    expect(block(text, 'ASSIGNED HOURS', 'GROSS WORK'), contains('298:42'));
    expect(block(text, 'BREAK HOURS', 'LATE HOURS'), contains('01:30'));
    expect(block(text, 'NET HOURS', 'APPROVED OT'), contains('10:30'));
  });
}
