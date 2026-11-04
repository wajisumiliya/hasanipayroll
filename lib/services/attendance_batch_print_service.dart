import 'dart:typed_data';
import 'attendance_net_hours.dart';
import 'attendance_working_rules.dart';
import 'attendance_pdf_service.dart';
import 'attendance_payroll_service.dart';
import 'payroll_calculation_service.dart';

/// Converts saved monthly attendance into the same front/back print template.
class AttendanceBatchPrintService {
  static int number(dynamic v) => num.tryParse('$v')?.round() ?? 0;
  static String text(dynamic v) => '${v ?? ''}'.trim();
  static int? clock(dynamic v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text(v));
    if (m == null || int.parse(m[1]!) > 23 || int.parse(m[2]!) > 59)
      return null;
    return int.parse(m[1]!) * 60 + int.parse(m[2]!);
  }

  static int duration(dynamic a, dynamic b) {
    final start = clock(a), end = clock(b);
    return start == null || end == null ? 0 : (end - start + 1440) % 1440;
  }

  static List<Map<String, dynamic>> rows(dynamic value) =>
      (value as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

  static Future<Uint8List> build(
      {required Map<String, dynamic> data,
      required List<String> employeeIds,
      required DateTime month,
      required String branchName}) async {
    final employees = rows(data['employees']),
        attendance = rows(data['attendance']),
        salaries = rows(data['salaries']),
        payroll = rows(data['payroll']),
        monthly = rows(data['monthly_rosters']),
        daily = rows(data['daily_rosters']);
    final sheets = <AttendancePrintSheet>[];
    for (final id in employeeIds) {
      final employee =
          employees.firstWhere((e) => text(e['employee_id']) == id);
      final salaryRows =
          salaries.where((r) => text(r['employee_id']) == id).toList();
      final salary = salaryRows.isEmpty ? null : salaryRows.first;
      final saved = payroll.where((r) => text(r['employee_id']) == id).toList();
      if (saved.length > 1)
        throw StateError('Duplicate payroll records for $id.');
      final records =
          attendance.where((r) => text(r['employee_id']) == id).toList();
      final rosterRows = monthly
          .where((r) =>
              text(r['employee_id']) == id &&
              text(r['branch_id']).toUpperCase() ==
                  text(employee['branch_id']).toUpperCase())
          .toList();
      final dailyRows = daily
          .where((r) =>
              text(r['employee_id']) == id &&
              text(r['branch_id']).toUpperCase() ==
                  text(employee['branch_id']).toUpperCase())
          .toList();
      final local = salary == null
          ? !text(employee['address']).toUpperCase().contains('FRN')
          : text(salary['epf_category']).toLowerCase() == 'normal1' ||
              const ['true', '1', 'yes']
                  .contains(text(salary['eis_applicable']).toLowerCase());
      final foreign = AttendanceWorkingRules.isForeign(
          employee['address'], salary?['address']);
      final days = List<AttendancePrintDay>.generate(
          DateTime(month.year, month.month + 1, 0).day, (index) {
        final day = index + 1;
        final matches = records
            .where((r) =>
                DateTime.tryParse(text(r['attendance_date']))?.day == day)
            .toList();
        final r = matches.isEmpty ? <String, dynamic>{} : matches.first;
        final dailyMatch = dailyRows
            .where((r) => DateTime.tryParse(text(r['roster_date']))?.day == day)
            .toList();
        final weeklyMatch = rosterRows
            .where((r) => number(r['week_number']) == (index ~/ 7) + 1)
            .toList();
        final roster = dailyMatch.isNotEmpty
            ? dailyMatch.first
            : weeklyMatch.isNotEmpty
                ? weeklyMatch.first
                : <String, dynamic>{};
        final workingIn = text(r['check_in'] ?? r['working_in']);
        final workingOut = text(r['check_out'] ?? r['working_out']);
        final hasWorkingTimes =
            clock(workingIn) != null && clock(workingOut) != null;
        final gross = hasWorkingTimes
            ? duration(workingIn, workingOut)
            : number(r['work_minutes']);
        final hasBreakTimes = ['morning_in', 'afternoon_in', 'overtime_in']
            .any((key) => clock(r[key]) != null);
        final actualBreaks = hasBreakTimes
            ? duration(r['morning_in'], r['morning_out']) +
                duration(r['afternoon_in'], r['afternoon_out']) +
                duration(r['overtime_in'], r['overtime_out'])
            : number(r['break_minutes']);
        final breaks = AttendanceWorkingRules.breakMinutes(
          isForeignEmployee: foreign,
          workMinutes: gross,
          actualMinutes: actualBreaks,
          status: text(r['status']),
        );
        final net = (hasWorkingTimes || breaks != actualBreaks
                ? gross - breaks
                : r['net_working_minutes'] != null
                    ? number(r['net_working_minutes'])
                    : gross - breaks)
            .clamp(0, 1440)
            .toInt();
        final allocated = clock(roster['shift_start']) != null &&
                clock(roster['shift_end']) != null
            ? duration(roster['shift_start'], roster['shift_end'])
            : (local ? 450 : 630) + 60;
        final ot = !PayrollCalculationService.isEmployeeOvertimeEligible(id)
            ? 0
            : r['approved_ot_minutes'] != null
                ? PayrollCalculationService.eligibleOvertimeMinutes(
                    number(r['approved_ot_minutes']))
                : PayrollCalculationService.automaticLocalOvertimeMinutes(
                    isLocalStaff: local,
                    workMinutes: gross,
                    actualBreakMinutes: breaks,
                    allocatedShiftMinutes: allocated,
                    allocatedBreakMinutes:
                        roster.isEmpty ? 60 : number(roster['break_minutes']));
        final actualIn = clock(workingIn),
            shiftIn = clock(roster['shift_start']);
        final late = actualIn != null && shiftIn != null
            ? (actualIn - shiftIn).clamp(0, 1440).toInt()
            : 0;
        final status = text(r['status']).toUpperCase() == 'UL'
            ? 'UL-UNPAID'
            : text(r['status']);
        return AttendancePrintDay(
            day: day,
            workingIn: workingIn,
            workingOut: workingOut,
            morningIn: text(r['morning_in']),
            morningOut: text(r['morning_out']),
            afternoonIn: text(r['afternoon_in']),
            afternoonOut: text(r['afternoon_out']),
            eveningIn: text(r['overtime_in']),
            eveningOut: text(r['overtime_out']),
            status: status,
            isUnpaid: const ['true', '1', 'yes']
                .contains(text(r['is_unpaid']).toLowerCase()),
            workMinutes: gross,
            breakMinutes: breaks,
            netMinutes: net,
            overtimeMinutes: ot,
            lateMinutes: late,
            assignedNetMinutes: AttendanceNetHours.assignedMinutes(
              dailyRoster: dailyMatch.isEmpty ? null : dailyMatch.first,
              weeklyRoster: weeklyMatch.isEmpty ? null : weeklyMatch.first,
              fallbackMinutes: local ? 450 : 630,
            ));
      });
      double overtime, lateAmount, unpaid;
      if (saved.isNotEmpty) {
        double amount(String key) =>
            double.tryParse('${saved.first[key]}') ?? 0;
        overtime = amount('overtime');
        lateAmount = amount('late_deduction');
        unpaid = amount('unpaid_deduction');
      } else {
        if (salary == null) throw StateError('No salary defaults for $id.');
        final preview = await AttendancePayrollService.previewEmployeePayroll(
            employee: employee,
            month: month,
            attendance: records,
            salaryDefault: {
              ...salary,
              'epf_enabled': false,
              'socso_enabled': false,
              'eis_enabled': false
            },
            rosterRows: rosterRows);
        if (!preview.calculated) throw StateError('$id: ${preview.message}');
        overtime = preview.overtimeAmount;
        lateAmount = preview.lateDeduction;
        unpaid = preview.unpaidDeduction;
      }
      sheets.add(AttendancePrintSheet(
          employeeId: id,
          employeeName: text(employee['name']),
          department: text(employee['department']),
          section: text(employee['section']),
          branchId: branchName,
          isForeignEmployee: foreign,
          month: month,
          days: days,
          basicSalary: double.tryParse('${salary?['basic_salary']}') ?? 0,
          payrollBasicSalary: saved.isEmpty ? null
              : double.tryParse('${saved.first['basic_salary']}'),
          approvedOtAmount: overtime,
          lateDeductionAmount: lateAmount,
          unpaidDeductionAmount: unpaid,
          estimatedAmounts: saved.isEmpty,
          deductionMinutes: AttendancePayrollService.attendanceShortageMinutes(
              employee: employee,
              salaryDefault: salary ??
                  {
                    'epf_category': local ? 'normal1' : 'normal',
                    'eis_applicable': local
                  },
              attendance: records,
              rosterRows: rosterRows)));
    }
    return AttendancePdfService.buildBatch(sheets);
  }
}
