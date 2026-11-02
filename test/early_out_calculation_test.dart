import 'package:flutter_test/flutter_test.dart';
import 'package:hasani_payroll_portal/services/attendance_payroll_service.dart';
import 'package:hasani_payroll_portal/services/early_out_calculation.dart';

void main() {
  const salary = <String, dynamic>{
    'basic_salary': 5200,
    'epf_category': 'normal1',
    'eis_applicable': true,
    'epf_enabled': false,
    'socso_enabled': false,
    'eis_enabled': false
  };
  const employee = <String, dynamic>{
    'employee_id': 'E1',
    'name': 'Employee',
    'branch_id': 'A'
  };
  const roster = <String, dynamic>{
    'employee_id': 'E1',
    'branch_id': 'A',
    'week_number': 1,
    'shift_start': '09:00',
    'shift_end': '18:00',
    'break_minutes': 60
  };
  Map<String, dynamic> row({int worked = 360, String start = '09:00'}) => {
        'employee_id': 'E1',
        'attendance_date': '2026-10-01',
        'check_in': start,
        'check_out': '16:00',
        'net_working_minutes': worked,
        'status': 'Early Out',
        'is_submitted': true
      };
  Map<String, dynamic> context(
          {String state = 'APPROVED',
          int approved = 105,
          int worked = 360,
          String start = '09:00',
          String date = '2026-10-01',
          String id = 'E1'}) =>
      {
        'cutoff': '2026-11-02T00:00:00Z',
        'events': [
          {
            'employee_id': id,
            'attendance_date': date,
            'approval_status': state,
            'approved_minutes': approved,
            'eligible_early_minutes': 105,
            'required_minutes': 480,
            'worked_minutes': worked,
            'check_in': start,
            'check_out': '16:00',
            'shift_start': '09:00',
            'shift_end': '18:00',
            'break_allowance': 60,
            'decision_id': '1',
            'fingerprint': 'snapshot'
          }
        ]
      };
  Future<PayrollGenerationItem> preview(Map<String, dynamic> approvals,
          {Map<String, dynamic>? person, Map<String, dynamic>? attendance}) =>
      AttendancePayrollService.previewEmployeePayroll(
          employee: person ?? employee,
          month: DateTime(2026, 10),
          attendance: [attendance ?? row()],
          salaryDefault: salary,
          rosterRows: [roster],
          earlyOutContext: approvals);
  test(
      'approved full Early Out removes only eligible deduction and records generation cutoff',
      () async {
    final result = await preview(context());
    expect(result.lateDeduction, 0);
    expect(result.shortageMinutes, 0);
    expect(result.earlyOutSnapshot!['exempted_minutes'], 105);
    expect(result.earlyOutSnapshot!['cutoff'], '2026-11-02T00:00:00Z');
  });
  test(
      'pending, rejected and missing approval retain existing rounding and monthly waiver rules',
      () async {
    for (final c in [
      context(state: 'PENDING', approved: 0),
      context(state: 'REJECTED', approved: 0),
      <String, dynamic>{'events': []}
    ]) {
      final result = await preview(c);
      expect(result.shortageMinutes, 105);
      expect(result.lateDeduction, 43.8);
    }
  });
  test(
      'partial exemption leaves remaining short hours, and does not create a second charge',
      () async {
    final result = await preview(context(approved: 45));
    expect(result.shortageMinutes, 60);
    expect(result.lateDeduction, 25);
    expect(result.unpaidDeduction, 0);
  });
  test(
      'late arrival and other shortfall remain when Early Out alone is fully approved',
      () async {
    final result = await preview(context(worked: 300, start: '10:00'),
        attendance: row(worked: 300, start: '10:00'));
    expect(result.shortageMinutes, 60);
    expect(result.lateDeduction, 25);
  });
  test('wrong date/month, employee or changed timing cannot reuse approval',
      () async {
    for (final c in [
      context(date: '2026-11-01'),
      context(id: 'OTHER'),
      context(start: '08:00')
    ]) {
      expect((await preview(c)).lateDeduction, 43.8);
    }
  });
  test('FRN, management, temporary and HED1007 exemptions remain', () async {
    for (final person in [
      {...employee, 'address': 'FRN'},
      {...employee, 'is_management_staff': true},
      {...employee, 'is_temp_staff': true},
      {...employee, 'employee_id': 'HED1007'}
    ]) {
      expect((await preview({'events': []}, person: person)).lateDeduction, 0);
    }
  });
  test(
      'manual and legacy deductions are protected; reviewed automatic deductions can regenerate',
      () {
    expect(EarlyOutCalculation.preserveManual(null), false);
    expect(EarlyOutCalculation.preserveManual({'late_deduction': 50}), true);
    expect(
        EarlyOutCalculation.preserveManual({
          'late_deduction': 50,
          'early_out_snapshot': {
            'calculated_late_deduction': 50,
            'manual_preserved': false
          }
        }),
        false);
    expect(
        EarlyOutCalculation.preserveManual({
          'late_deduction': 70,
          'early_out_snapshot': {'calculated_late_deduction': 50}
        }),
        true);
    expect(
        EarlyOutCalculation.preserveManual({
          'late_deduction': 50,
          'early_out_snapshot': {
            'calculated_late_deduction': 50,
            'manual_preserved': true
          }
        }),
        true);
  });
  test(
      'published, paid and finalized snapshots require adjustment rather than regeneration',
      () {
    for (final record in [
      {'is_published': true},
      {'is_paid': true},
      {'paidAt': '2026-11-01'},
      {'status': 'finalized'}
    ]) {
      expect(EarlyOutCalculation.locked(record), true);
    }
    expect(EarlyOutCalculation.locked({'is_published': false}), false);
  });
  test(
      'manual unpaid deductions remain protected when an override differs from the saved calculation',
      () {
    expect(EarlyOutCalculation.preserveManualUnpaid({'unpaid_deduction': 120}),
        true);
    expect(
        EarlyOutCalculation.preserveManualUnpaid({
          'unpaid_deduction': 120,
          'early_out_snapshot': {'calculated_unpaid_deduction': 120}
        }),
        false);
    expect(
        EarlyOutCalculation.preserveManualUnpaid({
          'unpaid_deduction': 150,
          'early_out_snapshot': {'calculated_unpaid_deduction': 120}
        }),
        true);
  });
  test(
      'manual statutory deductions are not overwritten by Early Out regeneration',
      () {
    expect(
        EarlyOutCalculation.preserveManualStatutory(
            {'epf_employee': 100}, 'epf_employee'),
        true);
    expect(
        EarlyOutCalculation.preserveManualStatutory({
          'epf_employee': 100,
          'early_out_snapshot': {
            'calculated_statutory_fields': {'epf_employee': 100}
          }
        }, 'epf_employee'),
        false);
    expect(
        EarlyOutCalculation.preserveManualStatutory({
          'epf_employee': 80,
          'early_out_snapshot': {
            'calculated_statutory_fields': {'epf_employee': 100}
          }
        }, 'epf_employee'),
        true);
  });
}
