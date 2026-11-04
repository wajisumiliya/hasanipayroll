import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_net_hours.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';
import 'package:hasani_payroll_portal/services/attendance_batch_print_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents, block;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only MC, AL and PH-OFF credit a full assigned day, exactly once', () {
    for (final status in ['MC', 'AL', 'PH-OFF', ' mc ']) {
      for (final actual in [0, 450, 510]) {
        expect(
            AttendanceNetHours.displayMinutes(
              status: status,
              actualMinutes: actual,
              assignedMinutes: 450,
            ),
            450);
      }
    }
    for (final status in ['OFF', 'UL-UNPAID', 'Absent', 'PH', '']) {
      expect(
          AttendanceNetHours.displayMinutes(
            status: status,
            actualMinutes: 0,
            assignedMinutes: 450,
          ),
          0);
    }
    expect(
        AttendanceNetHours.displayMinutes(
          status: 'Present',
          actualMinutes: 497,
          assignedMinutes: 450,
        ),
        497);
  });

  test('daily shift precedes weekly shift and excludes allocated breaks', () {
    final weekly = <String, dynamic>{
      'shift_start': '09:00',
      'shift_end': '18:00',
      'break_minutes': 90,
    };
    expect(
        AttendanceNetHours.assignedMinutes(
          dailyRoster: {
            'shift_start': '10:00',
            'shift_end': '20:00',
            'break_minutes': 60
          },
          weeklyRoster: weekly,
          fallbackMinutes: 630,
        ),
        540);
    expect(
        AttendanceNetHours.assignedMinutes(
          dailyRoster: {'assignment_type': 'MC'},
          weeklyRoster: weekly,
          fallbackMinutes: 630,
        ),
        450);
    expect(
        AttendanceNetHours.assignedMinutes(
          dailyRoster: {
            'shift_start': '22:00',
            'shift_end': '07:00',
            'break_minutes': 60
          },
          fallbackMinutes: 450,
        ),
        480);
    expect(AttendanceNetHours.assignedMinutes(fallbackMinutes: 630), 630);
  });

  test('single print credits leave into daily NET and total, never approved OT',
      () async {
    final days = [
      for (var i = 0; i < 3; i++)
        AttendancePrintDay(
          day: i + 1,
          workingIn: '',
          workingOut: '',
          morningIn: '',
          morningOut: '',
          afternoonIn: '',
          afternoonOut: '',
          eveningIn: '',
          eveningOut: '',
          status: ['MC', 'AL', 'PH-OFF'][i],
          workMinutes: 0,
          breakMinutes: 0,
          netMinutes: 0,
          overtimeMinutes: 450,
          lateMinutes: 0,
          assignedNetMinutes: 480,
        ),
    ];
    final text = pdfContents(await AttendancePdfService.build(
      employeeId: 'TEST',
      employeeName: 'Test',
      department: '',
      section: '',
      branchId: 'A',
      isForeignEmployee: false,
      month: DateTime(2026, 10),
      days: days,
      approvedOtAmount: 150,
    ));
    expect(block(text, 'NET HOURS', 'APPROVED OT'), contains('24:00'));
    expect(
        block(text, 'APPROVED OT', 'Review saved payroll:'), contains('00:00'));
    expect(block(text, 'APPROVED OT', 'Review saved payroll:'),
        contains('RM 0.00'));
    expect(text, contains('08:00'));
    // Rendering must not turn credited leave into actual worked payroll data.
    expect(days.every((day) => day.netMinutes == 0), true);
  });

  test('batch print uses assigned weekly hours for daily leave-only rosters',
      () async {
    final text = pdfContents(await AttendanceBatchPrintService.build(
      data: {
        'employees': [
          {'employee_id': 'E1', 'name': 'Test', 'branch_id': 'A'}
        ],
        'attendance': [
          for (var day = 1; day <= 3; day++)
            {
              'employee_id': 'E1',
              'attendance_date': '2026-10-0$day',
              'status': ['MC', 'AL', 'PH-OFF'][day - 1],
              'approved_ot_minutes': 450
            },
        ],
        'salaries': [
          {'employee_id': 'E1', 'epf_category': 'normal1'}
        ],
        'payroll': [
          {'employee_id': 'E1', 'overtime': 0}
        ],
        'monthly_rosters': [
          {
            'employee_id': 'E1',
            'branch_id': 'A',
            'week_number': 1,
            'shift_start': '09:00',
            'shift_end': '18:00',
            'break_minutes': 60
          }
        ],
        'daily_rosters': [
          {
            'employee_id': 'E1',
            'branch_id': 'A',
            'roster_date': '2026-10-01',
            'assignment_type': 'MC'
          }
        ],
      },
      employeeIds: ['E1'],
      month: DateTime(2026, 10),
      branchName: 'Branch A',
    ));
    expect(block(text, 'NET HOURS', 'APPROVED OT'), contains('24:00'));
    expect(text, contains('08:00'));
    expect(text, isNot(contains('OT / BONUS HOURS')));
    expect(block(text, 'APPROVED OT', 'DAY'), contains('00:00'));
  });
}
