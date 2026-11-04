import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_pdf_service.dart';
import 'package:hasani_payroll_portal/services/attendance_batch_print_service.dart';
import 'attendance_pdf_summary_test.dart' show pdfContents;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'batch attendance creates front and back pages for each selected employee',
      () async {
    final data = <String, dynamic>{
      'employees': [
        {'employee_id': 'E1', 'name': 'Employee One', 'branch_id': 'A'},
        {'employee_id': 'E2', 'name': 'Employee Two', 'branch_id': 'A'},
      ],
      'attendance': [
        {
          'employee_id': 'E1',
          'attendance_date': '2026-10-01',
          'check_in': '09:00',
          'check_out': '18:00',
          'status': 'Present',
          'work_minutes': 540,
          'break_minutes': 60,
          'net_working_minutes': 480,
          'approved_ot_minutes': 30
        },
      ],
      'salaries': [
        for (final id in ['E1', 'E2'])
          {
            'employee_id': id,
            'basic_salary': 2600,
            'epf_category': 'normal1',
            'eis_applicable': true
          },
      ],
      'payroll': [],
      'monthly_rosters': [],
      'daily_rosters': [],
    };
    final bytes = await AttendanceBatchPrintService.build(
        data: data,
        employeeIds: ['E1', 'E2'],
        month: DateTime(2026, 10),
        branchName: 'Branch A');
    final pdf = latin1.decode(bytes);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 4);
    expect(pdf, contains('/ViewerPreferences'));
    expect(pdf, contains('/DuplexFlipLongEdge'));
    expect(pdf, contains('/PrintScaling'));
  });
  test('empty selection cannot produce a misleading blank PDF', () async {
    await expectLater(AttendancePdfService.buildBatch([]), throwsArgumentError);
  });

  test('batch print respects an Admin zero override despite saved OT money',
      () async {
    final data = <String, dynamic>{
      'employees': [
        {'employee_id': 'BPR010', 'name': 'Test employee', 'branch_id': 'A'},
      ],
      'attendance': [
        {
          'employee_id': 'BPR010', 'attendance_date': '2026-10-28',
          'check_in': '09:00', 'check_out': '20:00', 'status': 'Present',
          'approved_ot_minutes': 0, 'ot_manual_override': true,
        },
      ],
      'salaries': [
        {'employee_id': 'BPR010', 'basic_salary': 2600,
          'epf_category': 'normal1', 'eis_applicable': true},
      ],
      'payroll': [
        {'employee_id': 'BPR010', 'overtime': 288.45},
      ],
      'monthly_rosters': [], 'daily_rosters': [],
    };
    final text = pdfContents(await AttendanceBatchPrintService.build(
      data: data, employeeIds: ['BPR010'], month: DateTime(2026, 10),
      branchName: 'Branch A',
    ));
    final start = text.indexOf('APPROVED OT');
    final end = text.indexOf('Review saved payroll:', start);
    final summary = text.substring(start, end);
    expect(summary, contains('00:00'));
    expect(summary, contains('RM 0.00'));
    expect(text, isNot(contains('288.45')));
  });
}
