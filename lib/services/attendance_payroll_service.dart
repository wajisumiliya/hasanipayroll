import '../screens/supabase_service.dart';

/// ============================================================================
/// ATTENDANCE PAYROLL SERVICE
/// ============================================================================
///
/// CURRENT PAYROLL RULES
///
/// 1. Employee is selected by Admin.
/// 2. Salary defaults come from employee_salary_defaults.
/// 3. cuti_umum = Basic Salary / 26 x 2 for each worked public holiday.
/// 4. Statutory wage = basic_salary - cuti_umum.
/// 5. If employee_salary_defaults.epf_category = "normal":
///      EPF employee = statutory wage x 2%
///      EPF employer = statutory wage x 2%
///    Other EPF categories use the supplied EPF schedule.
/// 6. SOCSO always uses FIRST CATEGORY and the supplied SOCSO schedule exactly.
/// 7. If employee_salary_defaults.eis_applicable = false:
///      EIS employee = 0
///      EIS employer = 0
///    Otherwise EIS uses the supplied EIS schedule.
/// 8. Overtime is summed from submitted attendance where ot_authorized is
///    "true", "1", "yes", or a boolean true.
/// 9. Approved OT is calculated above the assigned roster's daily net target.
///    When no roster exists, the employee salary-rule target is used.
/// 10. bonus, commission, other_earnings remain 0.
/// 11. Existing statutory values are overwritten when overwriteExisting=true.
/// 12. Attendance rules: submitted attendance drives working-time shortage,
///     unpaid days, authorized overtime and public-holiday pay.
///
/// STATUTORY CALCULATION
///
/// basic_salary
///      - cuti_umum
///      = statutory_wage
///
/// statutory_wage -> EPF schedule
///                -> SOCSO FIRST CATEGORY schedule
///                -> EIS schedule
///
/// EPF:
///   employee -> payroll.epf_employee
///   employer -> payroll.epf_employer
///
/// SOCSO FIRST CATEGORY:
///   employer -> payroll.socso_employer
///   employee -> invalidity + non-employment injury
///             -> payroll.socso_employee
///
/// EIS:
///   employee -> payroll.eis_employee
///   employer -> payroll.eis_employer
///
/// IMPORTANT:
/// The schedules below are embedded from the uploaded Excel files.
/// No percentage calculation is guessed.
/// ============================================================================

class AttendancePayrollService {
  AttendancePayrollService._();

  // ==========================================================================
  // GENERATE MONTHLY PAYROLL
  // ==========================================================================

  static Future<PayrollGenerationResult> generateMonthlyPayroll({
    required DateTime month,
    required List<String> employeeIds,
    bool overwriteExisting = true,
  }) async {
    final periodMonth = DateTime(month.year, month.month, 1);

    final normalizedIds = employeeIds
        .map(_normalizeId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      throw Exception('Please select at least one employee.');
    }

    final employees = await _getEmployeesByIds(normalizedIds);
    final employeeMap = <String, Map<String, dynamic>>{};

    for (final employee in employees) {
      final id = _normalizeId(employee['employee_id']);
      if (id.isNotEmpty) {
        employeeMap[id] = employee;
      }
    }

    final generated = <PayrollGenerationItem>[];
    final skipped = <PayrollGenerationItem>[];

    for (final employeeId in normalizedIds) {
      final employee = employeeMap[employeeId];

      if (employee == null) {
        skipped.add(
          PayrollGenerationItem(
            employeeId: employeeId,
            employeeName: '',
            generated: false,
            message: 'Employee not found in employees table.',
          ),
        );
        continue;
      }

      try {
        final result = await generateEmployeePayroll(
          employee: employee,
          month: periodMonth,
          overwriteExisting: overwriteExisting,
        );

        if (result.generated) {
          generated.add(result);
        } else {
          skipped.add(result);
        }
      } catch (e) {
        skipped.add(
          PayrollGenerationItem(
            employeeId: employeeId,
            employeeName: _text(employee['name']),
            generated: false,
            message: 'Failed: $e',
          ),
        );
      }
    }

    return PayrollGenerationResult(
      month: periodMonth,
      generated: generated,
      skipped: skipped,
    );
  }

  // ==========================================================================
  // GENERATE ONE EMPLOYEE
  // ==========================================================================

  static Future<PayrollGenerationItem> generateEmployeePayroll({
    required Map<String, dynamic> employee,
    required DateTime month,
    bool overwriteExisting = true,
  }) async {
    final employeeId = _normalizeId(employee['employee_id']);
    final employeeName = _text(employee['name']);

    if (employeeId.isEmpty) {
      return PayrollGenerationItem(
        employeeId: '',
        employeeName: employeeName,
        generated: false,
        message: 'Employee ID is missing.',
      );
    }

    // ------------------------------------------------------------------------
    // 1. SALARY DEFAULT
    // ------------------------------------------------------------------------

    final salaryDefault = await _getSalaryDefault(employeeId);

    if (salaryDefault == null) {
      return PayrollGenerationItem(
        employeeId: employeeId,
        employeeName: employeeName,
        generated: false,
        message:
            'No salary default found in employee_salary_defaults for $employeeId.',
      );
    }

    final basicSalary = _number(salaryDefault['basic_salary']);
    final fwSalary = _number(salaryDefault['fw_salary']);
    final elaunKedatangan = _number(salaryDefault['elaun_kedatangan']);
    final elaunPerkhidmatan = _number(salaryDefault['elaun_perkhidmatan']);
    final elaunKerajinan = _number(salaryDefault['elaun_kerajinan']);

    // Employee-specific statutory settings.
    //
    // IMPORTANT:
    // epf_category = "normal" means 2% employee + 2% employer.
    // Any other EPF category uses the supplied EPF schedule.
    //
    // eis_applicable = false means both EIS contributions are zero.
    final epfCategory = _normalizeCategory(
      salaryDefault['epf_category'],
    );
    final eisApplicable = _isApplicable(
      salaryDefault['eis_applicable'],
    );

    print('========================================');
    print('STATUTORY SETTINGS FOR $employeeId');
    print('epf_category = [$epfCategory]');
    print('eis_applicable = [$eisApplicable]');
    print('========================================');

    // ------------------------------------------------------------------------
    // 2. ATTENDANCE-BASED CALCULATIONS
    // ------------------------------------------------------------------------
    // Normal attendance calculations use submitted attendance. Payroll-impact
    // flags are also accepted for legacy rows because older saved attendance
    // could receive Admin OT approval, PH or UNPAID without is_submitted being
    // persisted correctly.
    //
    // Working-hour rules:
    //   epf_category = normal1 -> 7h30 net target (450 minutes)
    //   eis_applicable = false -> 10h30 net target (630 minutes),
    //                              and no overtime is paid.
    //   otherwise -> 7h30 net target (450 minutes).
    //
    // Public holiday and unpaid days are explicit attendance flags.
    // ------------------------------------------------------------------------

    final attendance = await _getSubmittedAttendanceForMonth(
      employeeId,
      month,
    );

    final branchId = _text(employee['branch_id'] ?? employee['branch']).trim();
    final rosterRows = branchId.isEmpty
        ? <Map<String, dynamic>>[]
        : await SupabaseService.getMonthlyRosters(
            branchId: branchId,
            year: month.year,
            month: month.month,
            employeeId: employeeId,
          );
    final rosterByWeek = <int, Map<String, dynamic>>{
      for (final row in rosterRows) _intNumber(row['week_number']): row,
    };

    final requiredWorkMinutes = _requiredWorkMinutes(
      epfCategory: epfCategory,
      eisApplicable: eisApplicable,
    );

    final requiredWorkHours = requiredWorkMinutes / 60.0;
    final calendarDays = DateTime(month.year, month.month + 1, 0).day;
    final dailySalary = calendarDays > 0 ? basicSalary / calendarDays : 0.0;
    double totalShortageMinutes = 0.0;
    double totalLateDeduction = 0.0;
    double totalOvertimeHours = 0.0;
    double totalOvertimeAmount = 0.0;
    double cutiUmum = 0.0;
    int unpaidDays = 0;
    int publicHolidayWorkedDays = 0;
    int approvedOtDays = 0;

    for (final row in attendance) {
      final workMinutes = _attendanceNetMinutes(row);
      final attendanceDate = DateTime.tryParse(_text(row['attendance_date']));
      final weekNumber =
          attendanceDate == null ? 0 : ((attendanceDate.day - 1) ~/ 7) + 1;
      final roster = rosterByWeek[weekNumber];
      final isRosterOff = attendanceDate != null &&
          _intNumber(roster?['off_weekday']) == attendanceDate.weekday;
      final dailyRequiredMinutes = isRosterOff
          ? 0
          : (_rosterRequiredMinutes(roster) ?? requiredWorkMinutes);
      final dailyRequiredHours = dailyRequiredMinutes / 60.0;
      final dailyShortageRate =
          dailyRequiredHours > 0 ? dailySalary / dailyRequiredHours : 0.0;
      final isUnpaid = _toBool(row['is_unpaid']);
      final isPublicHoliday = _toBool(row['is_public_holiday']);
      final worked = workMinutes > 0;

      // --------------------------------------------------------------
      // UNPAID DAY
      // --------------------------------------------------------------
      // An explicit is_unpaid flag controls unpaid leave. We do not
      // automatically treat every Absent row as unpaid.
      if (isUnpaid) {
        unpaidDays++;
      }

      // --------------------------------------------------------------
      // PUBLIC HOLIDAY
      // --------------------------------------------------------------
      // Only pay public holiday when the employee actually worked.
      if (isPublicHoliday && worked) {
        publicHolidayWorkedDays++;
        // Public holiday payment is exactly Basic Salary / 26 x 2 per day.
        cutiUmum += (basicSalary / 26.0) * 2.0;
      }

      // --------------------------------------------------------------
      // LATE / SHORT WORKING TIME
      // --------------------------------------------------------------
      // Unpaid and public-holiday rows are excluded from the normal-day
      // shortage calculation. A normal worked day below the target creates
      // a deduction based on basic salary / calendar days / target hours.
      if (!isUnpaid && !isPublicHoliday && worked) {
        final shortage = dailyRequiredMinutes - workMinutes;

        if (shortage > 0) {
          totalShortageMinutes += shortage;
          totalLateDeduction += (shortage / 60.0) * dailyShortageRate;
        }
      }

      // --------------------------------------------------------------
      // OVERTIME
      // --------------------------------------------------------------
      // OT is only paid when Admin authorized it.
      // A non-null approved_ot_minutes value is itself an Admin approval.
      // This also supports legacy rows where ot_authorized was not persisted.
      if (_isOtAuthorized(row['ot_authorized']) ||
          row['approved_ot_minutes'] != null) {
        final otHours = _attendanceOvertimeHours(row, dailyRequiredMinutes);
        if (otHours > 0) {
          approvedOtDays++;
          totalOvertimeHours += otHours;
          final rateHours =
              dailyRequiredHours > 0 ? dailyRequiredHours : requiredWorkHours;
          final dailyOtRate =
              rateHours > 0 ? (basicSalary / 26.0 / rateHours) * 1.5 : 0.0;
          totalOvertimeAmount += otHours * dailyOtRate;
        }
      }
    }

    // Your rule: if the monthly late/short-working deduction is below RM5,
    // do not deduct it.
    totalLateDeduction = _roundMoney(
      totalLateDeduction < 5.0 ? 0.0 : totalLateDeduction,
    );

    final unpaidDeduction = _roundMoney(
      dailySalary * unpaidDays,
    );

    final overtimeAmount = _roundMoney(
      totalOvertimeAmount,
    );

    cutiUmum = _roundMoney(cutiUmum);

    // ------------------------------------------------------------------------
    // 3. STATUTORY WAGE
    // ------------------------------------------------------------------------
    // Per the agreed rule:
    // basic_salary - cuti_umum = statutory wage.
    // ------------------------------------------------------------------------

    final statutoryWage = basicSalary - cutiUmum;

    if (statutoryWage < 0) {
      throw Exception(
        'Statutory wage cannot be negative. '
        'Basic salary: $basicSalary, Cuti Umum: $cutiUmum',
      );
    }

    // ------------------------------------------------------------------------
    // 4. EPF
    // ------------------------------------------------------------------------

    final _ContributionRow epf;

    if (epfCategory == 'normal') {
      // SPECIAL RULE:
      // epf_category = normal -> 2% employee + 2% employer.
      final epfTwoPercent = _roundMoney(statutoryWage * 0.02);

      epf = _ContributionRow(
        statutoryWage,
        statutoryWage,
        epfTwoPercent,
        epfTwoPercent,
      );
    } else {
      epf = _findContribution(
        schedule: _epfSchedule,
        wage: statutoryWage,
        scheduleName: 'EPF',
      );
    }

    // ------------------------------------------------------------------------
    // 5. SOCSO - FIRST CATEGORY
    // ------------------------------------------------------------------------

    final socso = _findContribution(
      schedule: _socsoFirstCategorySchedule,
      wage: statutoryWage,
      scheduleName: 'SOCSO First Category',
    );

    // ------------------------------------------------------------------------
    // 6. EIS
    // ------------------------------------------------------------------------

    final _ContributionRow eis;

    if (eisApplicable) {
      eis = _findContribution(
        schedule: _eisSchedule,
        wage: statutoryWage,
        scheduleName: 'EIS',
      );
    } else {
      eis = const _ContributionRow(
        0,
        0,
        0,
        0,
      );
    }

    // 8. PERIOD
    // ------------------------------------------------------------------------

    final period = _periodText(month);

    // ------------------------------------------------------------------------
    // 9. PAYROLL DATA
    // ------------------------------------------------------------------------

    final data = <String, dynamic>{
      'employee_id': employeeId,
      'period': period,

      // Salary defaults
      'basic_salary': basicSalary,
      'fw_salary': fwSalary,
      'elaun_kedatangan': elaunKedatangan,
      'elaun_perkhidmatan': elaunPerkhidmatan,
      'elaun_kerajinan': elaunKerajinan,

      // Attendance / earnings
      'overtime': overtimeAmount,
      'bonus': 0,
      'commission': 0,
      'other_earnings': 0,
      'cuti_umum': cutiUmum,
      'late_deduction': totalLateDeduction,
      'unpaid_deduction': unpaidDeduction,

      // Statutory contributions
      'epf_employee': epf.employee,
      'epf_employer': epf.employer,

      'socso_employee': socso.employee,
      'socso_employer': socso.employer,

      'eis_employee': eis.employee,
      'eis_employer': eis.employer,

      // Future deductions
      'pcb': 0,
      'zakat': 0,

      // Employee information
      'new_ic_no': _text(employee['new_ic_no']),
      'bank_code': _text(employee['bank_code']),
      'bank_account': _text(employee['bank_account']),

      // Debug / audit information
      'remarks': 'Generated payroll. '
          'Attendance rows used: ${attendance.length}. '
          'Statutory wage: ${statutoryWage.toStringAsFixed(2)}. '
          'EPF employee: ${epf.employee.toStringAsFixed(2)}. '
          'EPF employer: ${epf.employer.toStringAsFixed(2)}. '
          'SOCSO employee: ${socso.employee.toStringAsFixed(2)}. '
          'SOCSO employer: ${socso.employer.toStringAsFixed(2)}. '
          'EIS employee: ${eis.employee.toStringAsFixed(2)}. '
          'EIS employer: ${eis.employer.toStringAsFixed(2)}. '
          'Approved OT hours: ${totalOvertimeHours.toStringAsFixed(2)}. '
          'Approved OT days: $approvedOtDays. '
          'OT amount: ${overtimeAmount.toStringAsFixed(2)}. '
          'Public holidays worked: $publicHolidayWorkedDays. '
          'Fallback daily net hours: ${requiredWorkHours.toStringAsFixed(2)}. '
          'Roster weeks used: ${rosterByWeek.length}. '
          'Shortage minutes: ${totalShortageMinutes.toStringAsFixed(0)}. '
          'Late deduction: ${totalLateDeduction.toStringAsFixed(2)}. '
          'Unpaid days: $unpaidDays. '
          'Unpaid deduction: ${unpaidDeduction.toStringAsFixed(2)}. '
          //'Public holiday worked days: $publicHolidayWorkedDays. '
          'Cuti Umum: ${cutiUmum.toStringAsFixed(2)}.',
    };

    // ------------------------------------------------------------------------
    // 10. EXISTING PAYROLL
    // ------------------------------------------------------------------------

    final existing = await _getPayrollForPeriod(
      employeeId,
      period,
    );

    if (existing != null) {
      if (!overwriteExisting) {
        return PayrollGenerationItem(
          employeeId: employeeId,
          employeeName: employeeName,
          generated: false,
          message: 'Payroll already exists for $employeeId for $period.',
          basicSalary: basicSalary,
          fwSalary: fwSalary,
          elaunKedatangan: elaunKedatangan,
          elaunPerkhidmatan: elaunPerkhidmatan,
          elaunKerajinan: elaunKerajinan,
          overtimeDuration: totalOvertimeHours,
          overtimeAmount: overtimeAmount,
          cutiUmum: cutiUmum,
          lateDeduction: totalLateDeduction,
          unpaidDeduction: unpaidDeduction,
          unpaidDays: unpaidDays,
          //publicHolidayWorkedDays: publicHolidayWorkedDays,
          shortageMinutes: totalShortageMinutes,
          epfEmployee: epf.employee,
          epfEmployer: epf.employer,
          socsoEmployee: socso.employee,
          socsoEmployer: socso.employer,
          eisEmployee: eis.employee,
          eisEmployer: eis.employer,
          statutoryWage: statutoryWage,
        );
      }

      final existingId = existing['id'];

      if (existingId == null || _text(existingId).isEmpty) {
        throw Exception('Existing payroll record has no id.');
      }

      await SupabaseService.client
          .from('payroll')
          .update(data)
          .eq('id', existingId);
    } else {
      // Do not send payroll.id.
      // The database is expected to generate it.
      await SupabaseService.client.from('payroll').insert(data);
    }

    return PayrollGenerationItem(
      employeeId: employeeId,
      employeeName: employeeName,
      generated: true,
      message: 'Payroll generated successfully.',
      basicSalary: basicSalary,
      fwSalary: fwSalary,
      elaunKedatangan: elaunKedatangan,
      elaunPerkhidmatan: elaunPerkhidmatan,
      elaunKerajinan: elaunKerajinan,
      overtimeDuration: totalOvertimeHours,
      overtimeAmount: overtimeAmount,
      cutiUmum: cutiUmum,
      lateDeduction: totalLateDeduction,
      unpaidDeduction: unpaidDeduction,
      unpaidDays: unpaidDays,
      //publicHolidayWorkedDays: publicHolidayWorkedDays,
      shortageMinutes: totalShortageMinutes,
      epfEmployee: epf.employee,
      epfEmployer: epf.employer,
      socsoEmployee: socso.employee,
      socsoEmployer: socso.employer,
      eisEmployee: eis.employee,
      eisEmployer: eis.employer,
      statutoryWage: statutoryWage,
    );
  }

  // ==========================================================================
  // EMPLOYEES
  // ==========================================================================

  static Future<List<Map<String, dynamic>>> _getEmployeesByIds(
    List<String> employeeIds,
  ) async {
    final response = await SupabaseService.client
        .from('employees')
        .select(
          'employee_id,name,new_ic_no,bank_code,bank_account,branch_id,is_active',
        )
        .inFilter('employee_id', employeeIds);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================================================
  // SALARY DEFAULT
  // ==========================================================================

  static Future<Map<String, dynamic>?> _getSalaryDefault(
    String employeeId,
  ) async {
    final wantedId = _normalizeId(employeeId);

    if (wantedId.isEmpty) {
      return null;
    }

    try {
      final response = await SupabaseService.client
          .from('employee_salary_defaults')
          .select(
            'employee_id,'
            'basic_salary,'
            'fw_salary,'
            'elaun_kedatangan,'
            'elaun_perkhidmatan,'
            'elaun_kerajinan,'
            'epf_category,'
            'eis_applicable',
          )
          .eq('employee_id', wantedId);

      print('========================================');
      print('PAYROLL SALARY DEFAULT LOOKUP');
      print('Requested employee ID: [$wantedId]');
      print('Rows returned: ${response.length}');
      print('Salary response: $response');
      print('========================================');

      for (final row in response) {
        if (_normalizeId(row['employee_id']) == wantedId) {
          return Map<String, dynamic>.from(row);
        }
      }

      return null;
    } catch (e) {
      print('========================================');
      print('SALARY DEFAULT QUERY ERROR');
      print('Employee ID: [$wantedId]');
      print('Error: $e');
      print('========================================');
      rethrow;
    }
  }

  // ==========================================================================
  // SUBMITTED ATTENDANCE
  // ==========================================================================

  static Future<List<Map<String, dynamic>>> _getSubmittedAttendanceForMonth(
    String employeeId,
    DateTime month,
  ) async {
    final start = DateTime(
      month.year,
      month.month,
      1,
    );

    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final response = await SupabaseService.client
        .from('attendance')
        .select(
          'employee_id,attendance_date,work_minutes,break_minutes,'
          'net_working_minutes,net_working_duration,overtime_minutes,'
          'overtime_duration,approved_ot_minutes,ot_authorized,is_submitted,'
          'is_public_holiday,is_unpaid,status',
        )
        .eq('employee_id', employeeId)
        .or(
          'is_submitted.eq.true,ot_authorized.eq.true,'
          'approved_ot_minutes.not.is.null,is_public_holiday.eq.true,'
          'is_unpaid.eq.true',
        )
        .gte('attendance_date', _dateText(start))
        .lt('attendance_date', _dateText(end));

    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================================================
  // EXISTING PAYROLL
  // ==========================================================================

  static Future<Map<String, dynamic>?> _getPayrollForPeriod(
    String employeeId,
    String period,
  ) async {
    final response = await SupabaseService.client
        .from('payroll')
        .select('id,employee_id,period')
        .eq('employee_id', employeeId)
        .eq('period', period)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ==========================================================================
  // CONTRIBUTION LOOKUP
  // ==========================================================================

  static _ContributionRow _findContribution({
    required List<_ContributionRow> schedule,
    required double wage,
    required String scheduleName,
  }) {
    for (final row in schedule) {
      if (wage >= row.start && wage <= row.end) {
        return row;
      }
    }

    throw Exception(
      '$scheduleName schedule has no matching wage range for '
      'statutory wage RM${wage.toStringAsFixed(2)}.',
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  static String _normalizeId(dynamic value) {
    return _text(value).trim().toUpperCase();
  }

  static String _text(dynamic value) {
    return value?.toString() ?? '';
  }

  static int _requiredWorkMinutes({
    required String epfCategory,
    required bool eisApplicable,
  }) {
    // normal1 takes priority over the EIS setting.
    if (epfCategory == 'normal1') {
      return 450; // 7h30
    }

    if (!eisApplicable) {
      return 630; // 10h30
    }

    return 450; // 7h30
  }

  static int _attendanceWorkMinutes(Map<String, dynamic> row) {
    final value = row['work_minutes'];
    if (value != null) {
      final minutes = _intNumber(value);
      if (minutes > 0) return minutes;
    }

    // Fallback for older rows that may not have work_minutes populated.
    return _durationToMinutes(row['work_duration']);
  }

  static double _attendanceOvertimeHours(
    Map<String, dynamic> row,
    int requiredMinutes,
  ) {
    final approvedMinutes = _intNumber(row['approved_ot_minutes']);
    if (approvedMinutes >= 0 && row['approved_ot_minutes'] != null) {
      return approvedMinutes / 60.0;
    }
    // IMPORTANT:
    // Payroll must use the same NET working time shown/saved by Attendance
    // Dialog. Do NOT trust an old/stale overtime_minutes value, because that
    // can turn a real 01:23 OT into an old 02:00 value.
    //
    // reduced/reduced1 required NET = 7:30 = 450 minutes.
    // OT = synchronized NET working minutes - 450.
    final netMinutes = _intNumber(row['net_working_minutes']);
    if (netMinutes > 0) {
      final calculatedOtMinutes = netMinutes - requiredMinutes;
      return calculatedOtMinutes > 0 ? calculatedOtMinutes / 60.0 : 0.0;
    }

    // Fallback for older rows without net_working_minutes:
    // derive NET from work_minutes - break_minutes.
    final workMinutes = _intNumber(row['work_minutes']);
    final breakMinutes = _intNumber(row['break_minutes']);
    if (workMinutes > 0) {
      final netMinutesFallback = workMinutes - breakMinutes;
      final calculatedOtMinutes = netMinutesFallback - requiredMinutes;
      return calculatedOtMinutes > 0 ? calculatedOtMinutes / 60.0 : 0.0;
    }

    // Last-resort compatibility fallback for legacy rows.
    final overtimeMinutes = _intNumber(row['overtime_minutes']);
    if (overtimeMinutes > 0) {
      return overtimeMinutes / 60.0;
    }

    return 0.0;
  }

  static int _attendanceNetMinutes(Map<String, dynamic> row) {
    final savedNet = _intNumber(row['net_working_minutes']);
    if (savedNet > 0) return savedNet;
    final gross = _attendanceWorkMinutes(row);
    final breaks = _intNumber(row['break_minutes']);
    return (gross - breaks).clamp(0, 24 * 60);
  }

  static int? _rosterRequiredMinutes(Map<String, dynamic>? roster) {
    if (roster == null) return null;
    final start = _clockMinutes(roster['shift_start']);
    final end = _clockMinutes(roster['shift_end']);
    if (start == null || end == null) return null;
    var gross = end - start;
    if (gross <= 0) gross += 24 * 60;
    final required = gross - _intNumber(roster['break_minutes']);
    return required > 0 ? required : null;
  }

  static int? _clockMinutes(dynamic value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(_text(value).trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static int _durationToMinutes(dynamic value) {
    final text = _text(value).trim();
    if (text.isEmpty || text == '-') return 0;

    final parts = text.split(':');
    if (parts.length == 2) {
      final hours = int.tryParse(parts[0].trim());
      final minutes = int.tryParse(parts[1].trim());
      if (hours != null && minutes != null) {
        return hours * 60 + minutes;
      }
    }

    final decimal = double.tryParse(text.replaceAll(',', ''));
    if (decimal != null) {
      return (decimal * 60).round();
    }

    return 0;
  }

  static int _intNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();

    final text = value.toString().replaceAll(',', '').trim();
    if (text.isEmpty) return 0;

    return int.tryParse(text) ?? double.tryParse(text)?.round() ?? 0;
  }

  static double _number(dynamic value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    final text = value.toString().replaceAll(',', '').trim();

    if (text.isEmpty) {
      return 0.0;
    }

    return double.tryParse(text) ?? 0.0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;

    final text = _text(value).trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes' || text == 'y';
  }

  static bool _isOtAuthorized(dynamic value) {
    if (value is bool) {
      return value;
    }

    final text = _text(value).trim().toLowerCase();

    return text == 'true' || text == '1' || text == 'yes';
  }

  static String _normalizeCategory(dynamic value) {
    return _text(value)
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  static bool _isApplicable(dynamic value) {
    if (value is bool) {
      return value;
    }

    final text = _normalizeCategory(value);

    // Explicitly NOT applicable.
    if (text == 'false' ||
        text == '0' ||
        text == 'no' ||
        text == 'n' ||
        text == 'not applicable' ||
        text == 'not applicable ') {
      return false;
    }

    // Everything else is treated as applicable.
    return true;
  }

  static double _roundMoney(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  static String _dateText(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _periodText(DateTime month) {
    return '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}-01';
  }

  // ==========================================================================
  // EPF SCHEDULE
  // ==========================================================================
  // Source: EPF Schedule Amendment(1).xlsx
  // Columns: Start With, End With, Employer EPF, Employee EPF
  // ==========================================================================

  static final List<_ContributionRow> _epfSchedule = <_ContributionRow>[
    _ContributionRow(0.01, 10, 0, 0),
    _ContributionRow(10.01, 20, 3, 3),
    _ContributionRow(20.01, 40, 6, 5),
    _ContributionRow(40.01, 60, 8, 7),
    _ContributionRow(60.01, 80, 11, 9),
    _ContributionRow(80.01, 100, 13, 11),
    _ContributionRow(100.01, 120, 16, 14),
    _ContributionRow(120.01, 140, 19, 16),
    _ContributionRow(140.01, 160, 21, 18),
    _ContributionRow(160.01, 180, 24, 20),
    _ContributionRow(180.01, 200, 26, 22),
    _ContributionRow(200.01, 220, 29, 25),
    _ContributionRow(220.01, 240, 32, 27),
    _ContributionRow(240.01, 260, 34, 29),
    _ContributionRow(260.01, 280, 37, 31),
    _ContributionRow(280.01, 300, 39, 33),
    _ContributionRow(300.01, 320, 42, 36),
    _ContributionRow(320.01, 340, 45, 38),
    _ContributionRow(340.01, 360, 47, 40),
    _ContributionRow(360.01, 380, 50, 42),
    _ContributionRow(380.01, 400, 52, 44),
    _ContributionRow(400.01, 420, 55, 47),
    _ContributionRow(420.01, 440, 58, 49),
    _ContributionRow(440.01, 460, 60, 51),
    _ContributionRow(460.01, 480, 63, 53),
    _ContributionRow(480.01, 500, 65, 55),
    _ContributionRow(500.01, 520, 68, 58),
    _ContributionRow(520.01, 540, 71, 60),
    _ContributionRow(540.01, 560, 73, 62),
    _ContributionRow(560.01, 580, 76, 64),
    _ContributionRow(580.01, 600, 78, 66),
    _ContributionRow(600.01, 620, 81, 69),
    _ContributionRow(620.01, 640, 84, 71),
    _ContributionRow(640.01, 660, 86, 73),
    _ContributionRow(660.01, 680, 89, 75),
    _ContributionRow(680.01, 700, 91, 77),
    _ContributionRow(700.01, 720, 94, 80),
    _ContributionRow(720.01, 740, 97, 82),
    _ContributionRow(740.01, 760, 99, 84),
    _ContributionRow(760.01, 780, 102, 86),
    _ContributionRow(780.01, 800, 104, 88),
    _ContributionRow(800.01, 820, 107, 91),
    _ContributionRow(820.01, 840, 110, 93),
    _ContributionRow(840.01, 860, 112, 95),
    _ContributionRow(860.01, 880, 115, 97),
    _ContributionRow(880.01, 900, 117, 99),
    _ContributionRow(900.01, 920, 120, 102),
    _ContributionRow(920.01, 940, 123, 104),
    _ContributionRow(940.01, 960, 125, 106),
    _ContributionRow(960.01, 980, 128, 108),
    _ContributionRow(980.01, 1000, 130, 110),
    _ContributionRow(1000.01, 1020, 133, 113),
    _ContributionRow(1020.01, 1040, 136, 115),
    _ContributionRow(1040.01, 1060, 138, 117),
    _ContributionRow(1060.01, 1080, 141, 119),
    _ContributionRow(1080.01, 1100, 143, 121),
    _ContributionRow(1100.01, 1120, 146, 124),
    _ContributionRow(1120.01, 1140, 149, 126),
    _ContributionRow(1140.01, 1160, 151, 128),
    _ContributionRow(1160.01, 1180, 154, 130),
    _ContributionRow(1180.01, 1200, 156, 132),
    _ContributionRow(1200.01, 1220, 159, 135),
    _ContributionRow(1220.01, 1240, 162, 137),
    _ContributionRow(1240.01, 1260, 164, 139),
    _ContributionRow(1260.01, 1280, 167, 141),
    _ContributionRow(1280.01, 1300, 169, 143),
    _ContributionRow(1300.01, 1320, 172, 146),
    _ContributionRow(1320.01, 1340, 175, 148),
    _ContributionRow(1340.01, 1360, 177, 150),
    _ContributionRow(1360.01, 1380, 180, 152),
    _ContributionRow(1380.01, 1400, 182, 154),
    _ContributionRow(1400.01, 1420, 185, 157),
    _ContributionRow(1420.01, 1440, 188, 159),
    _ContributionRow(1440.01, 1460, 190, 161),
    _ContributionRow(1460.01, 1480, 193, 163),
    _ContributionRow(1480.01, 1500, 195, 165),
    _ContributionRow(1500.01, 1520, 198, 168),
    _ContributionRow(1520.01, 1540, 201, 170),
    _ContributionRow(1540.01, 1560, 203, 172),
    _ContributionRow(1560.01, 1580, 206, 174),
    _ContributionRow(1580.01, 1600, 208, 176),
    _ContributionRow(1600.01, 1620, 211, 179),
    _ContributionRow(1620.01, 1640, 214, 181),
    _ContributionRow(1640.01, 1660, 216, 183),
    _ContributionRow(1660.01, 1680, 219, 185),
    _ContributionRow(1680.01, 1700, 221, 187),
    _ContributionRow(1700.01, 1720, 224, 190),
    _ContributionRow(1720.01, 1740, 227, 192),
    _ContributionRow(1740.01, 1760, 229, 194),
    _ContributionRow(1760.01, 1780, 232, 196),
    _ContributionRow(1780.01, 1800, 234, 198),
    _ContributionRow(1800.01, 1820, 237, 201),
    _ContributionRow(1820.01, 1840, 240, 203),
    _ContributionRow(1840.01, 1860, 242, 205),
    _ContributionRow(1860.01, 1880, 245, 207),
    _ContributionRow(1880.01, 1900, 247, 209),
    _ContributionRow(1900.01, 1920, 250, 212),
    _ContributionRow(1920.01, 1940, 253, 214),
    _ContributionRow(1940.01, 1960, 255, 216),
    _ContributionRow(1960.01, 1980, 258, 218),
    _ContributionRow(1980.01, 2000, 260, 220),
    _ContributionRow(2000.01, 2020, 263, 223),
    _ContributionRow(2020.01, 2040, 266, 225),
    _ContributionRow(2040.01, 2060, 268, 227),
    _ContributionRow(2060.01, 2080, 271, 229),
    _ContributionRow(2080.01, 2100, 273, 231),
    _ContributionRow(2100.01, 2120, 276, 234),
    _ContributionRow(2120.01, 2140, 279, 236),
    _ContributionRow(2140.01, 2160, 281, 238),
    _ContributionRow(2160.01, 2180, 284, 240),
    _ContributionRow(2180.01, 2200, 286, 242),
    _ContributionRow(2200.01, 2220, 289, 245),
    _ContributionRow(2220.01, 2240, 292, 247),
    _ContributionRow(2240.01, 2260, 294, 249),
    _ContributionRow(2260.01, 2280, 297, 251),
    _ContributionRow(2280.01, 2300, 299, 253),
    _ContributionRow(2300.01, 2320, 302, 256),
    _ContributionRow(2320.01, 2340, 305, 258),
    _ContributionRow(2340.01, 2360, 307, 260),
    _ContributionRow(2360.01, 2380, 310, 262),
    _ContributionRow(2380.01, 2400, 312, 264),
    _ContributionRow(2400.01, 2420, 315, 267),
    _ContributionRow(2420.01, 2440, 318, 269),
    _ContributionRow(2440.01, 2460, 320, 271),
    _ContributionRow(2460.01, 2480, 323, 273),
    _ContributionRow(2480.01, 2500, 325, 275),
    _ContributionRow(2500.01, 2520, 328, 278),
    _ContributionRow(2520.01, 2540, 331, 280),
    _ContributionRow(2540.01, 2560, 333, 282),
    _ContributionRow(2560.01, 2580, 336, 284),
    _ContributionRow(2580.01, 2600, 338, 286),
    _ContributionRow(2600.01, 2620, 341, 289),
    _ContributionRow(2620.01, 2640, 344, 291),
    _ContributionRow(2640.01, 2660, 346, 293),
    _ContributionRow(2660.01, 2680, 349, 295),
    _ContributionRow(2680.01, 2700, 351, 297),
    _ContributionRow(2700.01, 2720, 354, 300),
    _ContributionRow(2720.01, 2740, 357, 302),
    _ContributionRow(2740.01, 2760, 359, 304),
    _ContributionRow(2760.01, 2780, 362, 306),
    _ContributionRow(2780.01, 2800, 364, 308),
    _ContributionRow(2800.01, 2820, 367, 311),
    _ContributionRow(2820.01, 2840, 370, 313),
    _ContributionRow(2840.01, 2860, 372, 315),
    _ContributionRow(2860.01, 2880, 375, 317),
    _ContributionRow(2880.01, 2900, 377, 319),
    _ContributionRow(2900.01, 2920, 380, 322),
    _ContributionRow(2920.01, 2940, 383, 324),
    _ContributionRow(2940.01, 2960, 385, 326),
    _ContributionRow(2960.01, 2980, 388, 328),
    _ContributionRow(2980.01, 3000, 390, 330),
    _ContributionRow(3000.01, 3020, 393, 333),
    _ContributionRow(3020.01, 3040, 396, 335),
    _ContributionRow(3040.01, 3060, 398, 337),
    _ContributionRow(3060.01, 3080, 401, 339),
    _ContributionRow(3080.01, 3100, 403, 341),
    _ContributionRow(3100.01, 3120, 406, 344),
    _ContributionRow(3120.01, 3140, 409, 346),
    _ContributionRow(3140.01, 3160, 411, 348),
    _ContributionRow(3160.01, 3180, 414, 350),
    _ContributionRow(3180.01, 3200, 416, 352),
    _ContributionRow(3200.01, 3220, 419, 355),
    _ContributionRow(3220.01, 3240, 422, 357),
    _ContributionRow(3240.01, 3260, 424, 359),
    _ContributionRow(3260.01, 3280, 427, 361),
    _ContributionRow(3280.01, 3300, 429, 363),
    _ContributionRow(3300.01, 3320, 432, 366),
    _ContributionRow(3320.01, 3340, 435, 368),
    _ContributionRow(3340.01, 3360, 437, 370),
    _ContributionRow(3360.01, 3380, 440, 372),
    _ContributionRow(3380.01, 3400, 442, 374),
    _ContributionRow(3400.01, 3420, 445, 377),
    _ContributionRow(3420.01, 3440, 448, 379),
    _ContributionRow(3440.01, 3460, 450, 381),
    _ContributionRow(3460.01, 3480, 453, 383),
    _ContributionRow(3480.01, 3500, 455, 385),
    _ContributionRow(3500.01, 3520, 458, 388),
    _ContributionRow(3520.01, 3540, 461, 390),
    _ContributionRow(3540.01, 3560, 463, 392),
    _ContributionRow(3560.01, 3580, 466, 394),
    _ContributionRow(3580.01, 3600, 468, 396),
    _ContributionRow(3600.01, 3620, 471, 399),
    _ContributionRow(3620.01, 3640, 474, 401),
    _ContributionRow(3640.01, 3660, 476, 403),
    _ContributionRow(3660.01, 3680, 479, 405),
    _ContributionRow(3680.01, 3700, 481, 407),
    _ContributionRow(3700.01, 3720, 484, 410),
    _ContributionRow(3720.01, 3740, 487, 412),
    _ContributionRow(3740.01, 3760, 489, 414),
    _ContributionRow(3760.01, 3780, 492, 416),
    _ContributionRow(3780.01, 3800, 494, 418),
    _ContributionRow(3800.01, 3820, 497, 421),
    _ContributionRow(3820.01, 3840, 500, 423),
    _ContributionRow(3840.01, 3860, 502, 425),
    _ContributionRow(3860.01, 3880, 505, 427),
    _ContributionRow(3880.01, 3900, 507, 429),
    _ContributionRow(3900.01, 3920, 510, 432),
    _ContributionRow(3920.01, 3940, 513, 434),
    _ContributionRow(3940.01, 3960, 515, 436),
    _ContributionRow(3960.01, 3980, 518, 438),
    _ContributionRow(3980.01, 4000, 520, 440),
    _ContributionRow(4000.01, 4020, 523, 443),
    _ContributionRow(4020.01, 4040, 526, 445),
    _ContributionRow(4040.01, 4060, 528, 447),
    _ContributionRow(4060.01, 4080, 531, 449),
    _ContributionRow(4080.01, 4100, 533, 451),
    _ContributionRow(4100.01, 4120, 536, 454),
    _ContributionRow(4120.01, 4140, 539, 456),
    _ContributionRow(4140.01, 4160, 541, 458),
    _ContributionRow(4160.01, 4180, 544, 460),
    _ContributionRow(4180.01, 4200, 546, 462),
    _ContributionRow(4200.01, 4220, 549, 465),
    _ContributionRow(4220.01, 4240, 552, 467),
    _ContributionRow(4240.01, 4260, 554, 469),
    _ContributionRow(4260.01, 4280, 557, 471),
    _ContributionRow(4280.01, 4300, 559, 473),
    _ContributionRow(4300.01, 4320, 562, 476),
    _ContributionRow(4320.01, 4340, 565, 478),
    _ContributionRow(4340.01, 4360, 567, 480),
    _ContributionRow(4360.01, 4380, 570, 482),
    _ContributionRow(4380.01, 4400, 572, 484),
    _ContributionRow(4400.01, 4420, 575, 487),
    _ContributionRow(4420.01, 4440, 578, 489),
    _ContributionRow(4440.01, 4460, 580, 491),
    _ContributionRow(4460.01, 4480, 583, 493),
    _ContributionRow(4480.01, 4500, 585, 495),
    _ContributionRow(4500.01, 4520, 588, 498),
    _ContributionRow(4520.01, 4540, 591, 500),
    _ContributionRow(4540.01, 4560, 593, 502),
    _ContributionRow(4560.01, 4580, 596, 504),
    _ContributionRow(4580.01, 4600, 598, 506),
    _ContributionRow(4600.01, 4620, 601, 509),
    _ContributionRow(4620.01, 4640, 604, 511),
    _ContributionRow(4640.01, 4660, 606, 513),
    _ContributionRow(4660.01, 4680, 609, 515),
    _ContributionRow(4680.01, 4700, 611, 517),
    _ContributionRow(4700.01, 4720, 614, 520),
    _ContributionRow(4720.01, 4740, 617, 522),
    _ContributionRow(4740.01, 4760, 619, 524),
    _ContributionRow(4760.01, 4780, 622, 526),
    _ContributionRow(4780.01, 4800, 624, 528),
    _ContributionRow(4800.01, 4820, 627, 531),
    _ContributionRow(4820.01, 4840, 630, 533),
    _ContributionRow(4840.01, 4860, 632, 535),
    _ContributionRow(4860.01, 4880, 635, 537),
    _ContributionRow(4880.01, 4900, 637, 539),
    _ContributionRow(4900.01, 4920, 640, 542),
    _ContributionRow(4920.01, 4940, 643, 544),
    _ContributionRow(4940.01, 4960, 645, 546),
    _ContributionRow(4960.01, 4980, 648, 548),
    _ContributionRow(4980.01, 5000, 650, 550),
    _ContributionRow(5000.01, 5100, 612, 561),
    _ContributionRow(5100.01, 5200, 624, 572),
    _ContributionRow(5200.01, 5300, 636, 583),
    _ContributionRow(5300.01, 5400, 648, 594),
    _ContributionRow(5400.01, 5500, 660, 605),
    _ContributionRow(5500.01, 5600, 672, 616),
    _ContributionRow(5600.01, 5700, 684, 627),
    _ContributionRow(5700.01, 5800, 696, 638),
    _ContributionRow(5800.01, 5900, 708, 649),
    _ContributionRow(5900.01, 6000, 720, 660),
    _ContributionRow(6000.01, 6100, 732, 671),
    _ContributionRow(6100.01, 6200, 744, 682),
    _ContributionRow(6200.01, 6300, 756, 693),
    _ContributionRow(6300.01, 6400, 768, 704),
    _ContributionRow(6400.01, 6500, 780, 715),
    _ContributionRow(6500.01, 6600, 792, 726),
    _ContributionRow(6600.01, 6700, 804, 737),
    _ContributionRow(6700.01, 6800, 816, 748),
    _ContributionRow(6800.01, 6900, 828, 759),
    _ContributionRow(6900.01, 7000, 840, 770),
    _ContributionRow(7000.01, 7100, 852, 781),
    _ContributionRow(7100.01, 7200, 864, 792),
    _ContributionRow(7200.01, 7300, 876, 803),
    _ContributionRow(7300.01, 7400, 888, 814),
    _ContributionRow(7400.01, 7500, 900, 825),
    _ContributionRow(7500.01, 7600, 912, 836),
    _ContributionRow(7600.01, 7700, 924, 847),
    _ContributionRow(7700.01, 7800, 936, 858),
    _ContributionRow(7800.01, 7900, 948, 869),
    _ContributionRow(7900.01, 8000, 960, 880),
    _ContributionRow(8000.01, 8100, 972, 891),
    _ContributionRow(8100.01, 8200, 984, 902),
    _ContributionRow(8200.01, 8300, 996, 913),
    _ContributionRow(8300.01, 8400, 1008, 924),
    _ContributionRow(8400.01, 8500, 1020, 935),
    _ContributionRow(8500.01, 8600, 1032, 946),
    _ContributionRow(8600.01, 8700, 1044, 957),
    _ContributionRow(8700.01, 8800, 1056, 968),
    _ContributionRow(8800.01, 8900, 1068, 979),
    _ContributionRow(8900.01, 9000, 1080, 990),
    _ContributionRow(9000.01, 9100, 1092, 1001),
    _ContributionRow(9100.01, 9200, 1104, 1012),
    _ContributionRow(9200.01, 9300, 1116, 1023),
    _ContributionRow(9300.01, 9400, 1128, 1034),
    _ContributionRow(9400.01, 9500, 1140, 1045),
    _ContributionRow(9500.01, 9600, 1152, 1056),
    _ContributionRow(9600.01, 9700, 1164, 1067),
    _ContributionRow(9700.01, 9800, 1176, 1078),
    _ContributionRow(9800.01, 9900, 1188, 1089),
    _ContributionRow(9900.01, 10000, 1200, 1100),
    _ContributionRow(10000.01, 10100, 1212, 1111),
    _ContributionRow(10100.01, 10200, 1224, 1122),
    _ContributionRow(10200.01, 10300, 1236, 1133),
    _ContributionRow(10300.01, 10400, 1248, 1144),
    _ContributionRow(10400.01, 10500, 1260, 1155),
    _ContributionRow(10500.01, 10600, 1272, 1166),
    _ContributionRow(10600.01, 10700, 1284, 1177),
    _ContributionRow(10700.01, 10800, 1296, 1188),
    _ContributionRow(10800.01, 10900, 1308, 1199),
    _ContributionRow(10900.01, 11000, 1320, 1210),
    _ContributionRow(11000.01, 11100, 1332, 1221),
    _ContributionRow(11100.01, 11200, 1344, 1232),
    _ContributionRow(11200.01, 11300, 1356, 1243),
    _ContributionRow(11300.01, 11400, 1368, 1254),
    _ContributionRow(11400.01, 11500, 1380, 1265),
    _ContributionRow(11500.01, 11600, 1392, 1276),
    _ContributionRow(11600.01, 11700, 1404, 1287),
    _ContributionRow(11700.01, 11800, 1416, 1298),
    _ContributionRow(11800.01, 11900, 1428, 1309),
    _ContributionRow(11900.01, 12000, 1440, 1320),
    _ContributionRow(12000.01, 12100, 1452, 1331),
    _ContributionRow(12100.01, 12200, 1464, 1342),
    _ContributionRow(12200.01, 12300, 1476, 1353),
    _ContributionRow(12300.01, 12400, 1488, 1364),
    _ContributionRow(12400.01, 12500, 1500, 1375),
    _ContributionRow(12500.01, 12600, 1512, 1386),
    _ContributionRow(12600.01, 12700, 1524, 1397),
    _ContributionRow(12700.01, 12800, 1536, 1408),
    _ContributionRow(12800.01, 12900, 1548, 1419),
    _ContributionRow(12900.01, 13000, 1560, 1430),
    _ContributionRow(13000.01, 13100, 1572, 1441),
    _ContributionRow(13100.01, 13200, 1584, 1452),
    _ContributionRow(13200.01, 13300, 1596, 1463),
    _ContributionRow(13300.01, 13400, 1608, 1474),
    _ContributionRow(13400.01, 13500, 1620, 1485),
    _ContributionRow(13500.01, 13600, 1632, 1496),
    _ContributionRow(13600.01, 13700, 1644, 1507),
    _ContributionRow(13700.01, 13800, 1656, 1518),
    _ContributionRow(13800.01, 13900, 1668, 1529),
    _ContributionRow(13900.01, 14000, 1680, 1540),
    _ContributionRow(14000.01, 14100, 1692, 1551),
    _ContributionRow(14100.01, 14200, 1704, 1562),
    _ContributionRow(14200.01, 14300, 1716, 1573),
    _ContributionRow(14300.01, 14400, 1728, 1584),
    _ContributionRow(14400.01, 14500, 1740, 1595),
    _ContributionRow(14500.01, 14600, 1752, 1606),
    _ContributionRow(14600.01, 14700, 1764, 1617),
    _ContributionRow(14700.01, 14800, 1776, 1628),
    _ContributionRow(14800.01, 14900, 1788, 1639),
    _ContributionRow(14900.01, 15000, 1800, 1650),
    _ContributionRow(15000.01, 15100, 1812, 1661),
    _ContributionRow(15100.01, 15200, 1824, 1672),
    _ContributionRow(15200.01, 15300, 1836, 1683),
    _ContributionRow(15300.01, 15400, 1848, 1694),
    _ContributionRow(15400.01, 15500, 1860, 1705),
    _ContributionRow(15500.01, 15600, 1872, 1716),
    _ContributionRow(15600.01, 15700, 1884, 1727),
    _ContributionRow(15700.01, 15800, 1896, 1738),
    _ContributionRow(15800.01, 15900, 1908, 1749),
    _ContributionRow(15900.01, 16000, 1920, 1760),
    _ContributionRow(16000.01, 16100, 1932, 1771),
    _ContributionRow(16100.01, 16200, 1944, 1782),
    _ContributionRow(16200.01, 16300, 1956, 1793),
    _ContributionRow(16300.01, 16400, 1968, 1804),
    _ContributionRow(16400.01, 16500, 1980, 1815),
    _ContributionRow(16500.01, 16600, 1992, 1826),
    _ContributionRow(16600.01, 16700, 2004, 1837),
    _ContributionRow(16700.01, 16800, 2016, 1848),
    _ContributionRow(16800.01, 16900, 2028, 1859),
    _ContributionRow(16900.01, 17000, 2040, 1870),
    _ContributionRow(17000.01, 17100, 2052, 1881),
    _ContributionRow(17100.01, 17200, 2064, 1892),
    _ContributionRow(17200.01, 17300, 2076, 1903),
    _ContributionRow(17300.01, 17400, 2088, 1914),
    _ContributionRow(17400.01, 17500, 2100, 1925),
    _ContributionRow(17500.01, 17600, 2112, 1936),
    _ContributionRow(17600.01, 17700, 2124, 1947),
    _ContributionRow(17700.01, 17800, 2136, 1958),
    _ContributionRow(17800.01, 17900, 2148, 1969),
    _ContributionRow(17900.01, 18000, 2160, 1980),
    _ContributionRow(18000.01, 18100, 2172, 1991),
    _ContributionRow(18100.01, 18200, 2184, 2002),
    _ContributionRow(18200.01, 18300, 2196, 2013),
    _ContributionRow(18300.01, 18400, 2208, 2024),
    _ContributionRow(18400.01, 18500, 2220, 2035),
    _ContributionRow(18500.01, 18600, 2232, 2046),
    _ContributionRow(18600.01, 18700, 2244, 2057),
    _ContributionRow(18700.01, 18800, 2256, 2068),
    _ContributionRow(18800.01, 18900, 2268, 2079),
    _ContributionRow(18900.01, 19000, 2280, 2090),
    _ContributionRow(19000.01, 19100, 2292, 2101),
    _ContributionRow(19100.01, 19200, 2304, 2112),
    _ContributionRow(19200.01, 19300, 2316, 2123),
    _ContributionRow(19300.01, 19400, 2328, 2134),
    _ContributionRow(19400.01, 19500, 2340, 2145),
    _ContributionRow(19500.01, 19600, 2352, 2156),
    _ContributionRow(19600.01, 19700, 2364, 2167),
    _ContributionRow(19700.01, 19800, 2376, 2178),
    _ContributionRow(19800.01, 19900, 2388, 2189),
    _ContributionRow(19900.01, 20000, 2400, 2200)
  ];

  // ==========================================================================
  // SOCSO FIRST CATEGORY SCHEDULE
  // ==========================================================================
  // Source: SOCSO Schedule Amendment(1).xlsx
  //
  // Employee contribution = Invalidity + Non-Employment Injury.
  // Second Category is intentionally NOT used.
  // ==========================================================================

  static final List<_ContributionRow> _socsoFirstCategorySchedule =
      <_ContributionRow>[
    _ContributionRow(0.01, 30, 0.40, 0.30),
    _ContributionRow(30.01, 50, 0.70, 0.50),
    _ContributionRow(50.01, 70, 1.10, 0.80),
    _ContributionRow(70.01, 100, 1.50, 1.05),
    _ContributionRow(100.01, 140, 2.10, 1.50),
    _ContributionRow(140.01, 200, 2.95, 2.10),
    _ContributionRow(200.01, 300, 4.35, 3.10),
    _ContributionRow(300.01, 400, 6.15, 4.40),
    _ContributionRow(400.01, 500, 7.85, 5.60),
    _ContributionRow(500.01, 600, 9.65, 6.90),
    _ContributionRow(600.01, 700, 11.35, 8.10),
    _ContributionRow(700.01, 800, 13.15, 9.40),
    _ContributionRow(800.01, 900, 14.85, 10.60),
    _ContributionRow(900.01, 1000, 16.65, 11.90),
    _ContributionRow(1000.01, 1100, 18.35, 13.10),
    _ContributionRow(1100.01, 1200, 20.15, 14.40),
    _ContributionRow(1200.01, 1300, 21.85, 15.60),
    _ContributionRow(1300.01, 1400, 23.65, 16.90),
    _ContributionRow(1400.01, 1500, 25.35, 18.10),
    _ContributionRow(1500.01, 1600, 27.15, 19.40),
    _ContributionRow(1600.01, 1700, 28.85, 20.60),
    _ContributionRow(1700.01, 1800, 30.65, 21.90),
    _ContributionRow(1800.01, 1900, 32.35, 23.10),
    _ContributionRow(1900.01, 2000, 34.15, 24.40),
    _ContributionRow(2000.01, 2100, 35.85, 25.60),
    _ContributionRow(2100.01, 2200, 37.65, 26.90),
    _ContributionRow(2200.01, 2300, 39.35, 28.10),
    _ContributionRow(2300.01, 2400, 41.15, 29.40),
    _ContributionRow(2400.01, 2500, 42.85, 30.60),
    _ContributionRow(2500.01, 2600, 44.65, 31.90),
    _ContributionRow(2600.01, 2700, 46.35, 33.10),
    _ContributionRow(2700.01, 2800, 48.15, 34.40),
    _ContributionRow(2800.01, 2900, 49.85, 35.60),
    _ContributionRow(2900.01, 3000, 51.65, 36.90),
    _ContributionRow(3000.01, 3100, 53.35, 38.10),
    _ContributionRow(3100.01, 3200, 55.15, 39.40),
    _ContributionRow(3200.01, 3300, 56.85, 40.60),
    _ContributionRow(3300.01, 3400, 58.65, 41.90),
    _ContributionRow(3400.01, 3500, 60.35, 43.10),
    _ContributionRow(3500.01, 3600, 62.15, 44.40),
    _ContributionRow(3600.01, 3700, 63.85, 45.60),
    _ContributionRow(3700.01, 3800, 65.65, 46.90),
    _ContributionRow(3800.01, 3900, 67.35, 48.10),
    _ContributionRow(3900.01, 4000, 69.15, 49.40),
    _ContributionRow(4000.01, 4100, 70.85, 50.60),
    _ContributionRow(4100.01, 4200, 72.65, 51.90),
    _ContributionRow(4200.01, 4300, 74.35, 53.10),
    _ContributionRow(4300.01, 4400, 76.15, 54.40),
    _ContributionRow(4400.01, 4500, 77.85, 55.60),
    _ContributionRow(4500.01, 4600, 79.65, 56.90),
    _ContributionRow(4600.01, 4700, 81.35, 58.10),
    _ContributionRow(4700.01, 4800, 83.15, 59.40),
    _ContributionRow(4800.01, 4900, 84.85, 60.60),
    _ContributionRow(4900.01, 5000, 86.65, 61.90),
    _ContributionRow(5000.01, 5100, 88.35, 63.10),
    _ContributionRow(5100.01, 5200, 90.15, 64.40),
    _ContributionRow(5200.01, 5300, 91.85, 65.60),
    _ContributionRow(5300.01, 5400, 93.65, 66.90),
    _ContributionRow(5400.01, 5500, 95.35, 68.10),
    _ContributionRow(5500.01, 5600, 97.15, 69.40),
    _ContributionRow(5600.01, 5700, 98.85, 70.60),
    _ContributionRow(5700.01, 5800, 100.65, 71.90),
    _ContributionRow(5800.01, 5900, 102.35, 73.10),
    _ContributionRow(5900.01, 6000, 104.15, 74.40),
    _ContributionRow(6000.01, 99999.99, 104.15, 74.40)
  ];

  // ==========================================================================
  // EIS SCHEDULE
  // ==========================================================================
  // Source: EIS Schedule Amendment(1).xlsx
  // Columns: Start With, End With, Employer EIS, Employee EIS
  // ==========================================================================

  static final List<_ContributionRow> _eisSchedule = <_ContributionRow>[
    _ContributionRow(30.01, 50, 0.10, 0.10),
    _ContributionRow(50.01, 70, 0.15, 0.15),
    _ContributionRow(70.01, 100, 0.20, 0.20),
    _ContributionRow(100.01, 140, 0.25, 0.25),
    _ContributionRow(140.01, 200, 0.35, 0.35),
    _ContributionRow(200.01, 300, 0.50, 0.50),
    _ContributionRow(300.01, 400, 0.70, 0.70),
    _ContributionRow(400.01, 500, 0.90, 0.90),
    _ContributionRow(500.01, 600, 1.10, 1.10),
    _ContributionRow(600.01, 700, 1.30, 1.30),
    _ContributionRow(700.01, 800, 1.50, 1.50),
    _ContributionRow(800.01, 900, 1.70, 1.70),
    _ContributionRow(900.01, 1000, 1.90, 1.90),
    _ContributionRow(1000.01, 1100, 2.10, 2.10),
    _ContributionRow(1100.01, 1200, 2.30, 2.30),
    _ContributionRow(1200.01, 1300, 2.50, 2.50),
    _ContributionRow(1300.01, 1400, 2.70, 2.70),
    _ContributionRow(1400.01, 1500, 2.90, 2.90),
    _ContributionRow(1500.01, 1600, 3.10, 3.10),
    _ContributionRow(1600.01, 1700, 3.30, 3.30),
    _ContributionRow(1700.01, 1800, 3.50, 3.50),
    _ContributionRow(1800.01, 1900, 3.70, 3.70),
    _ContributionRow(1900.01, 2000, 3.90, 3.90),
    _ContributionRow(2000.01, 2100, 4.10, 4.10),
    _ContributionRow(2100.01, 2200, 4.30, 4.30),
    _ContributionRow(2200.01, 2300, 4.50, 4.50),
    _ContributionRow(2300.01, 2400, 4.70, 4.70),
    _ContributionRow(2400.01, 2500, 4.90, 4.90),
    _ContributionRow(2500.01, 2600, 5.10, 5.10),
    _ContributionRow(2600.01, 2700, 5.30, 5.30),
    _ContributionRow(2700.01, 2800, 5.50, 5.50),
    _ContributionRow(2800.01, 2900, 5.70, 5.70),
    _ContributionRow(2900.01, 3000, 5.90, 5.90),
    _ContributionRow(3000.01, 3100, 6.10, 6.10),
    _ContributionRow(3100.01, 3200, 6.30, 6.30),
    _ContributionRow(3200.01, 3300, 6.50, 6.50),
    _ContributionRow(3300.01, 3400, 6.70, 6.70),
    _ContributionRow(3400.01, 3500, 6.90, 6.90),
    _ContributionRow(3500.01, 3600, 7.10, 7.10),
    _ContributionRow(3600.01, 3700, 7.30, 7.30),
    _ContributionRow(3700.01, 3800, 7.50, 7.50),
    _ContributionRow(3800.01, 3900, 7.70, 7.70),
    _ContributionRow(3900.01, 4000, 7.90, 7.90),
    _ContributionRow(4000.01, 4100, 8.10, 8.10),
    _ContributionRow(4100.01, 4200, 8.30, 8.30),
    _ContributionRow(4200.01, 4300, 8.50, 8.50),
    _ContributionRow(4300.01, 4400, 8.70, 8.70),
    _ContributionRow(4400.01, 4500, 8.90, 8.90),
    _ContributionRow(4500.01, 4600, 9.10, 9.10),
    _ContributionRow(4600.01, 4700, 9.30, 9.30),
    _ContributionRow(4700.01, 4800, 9.50, 9.50),
    _ContributionRow(4800.01, 4900, 9.70, 9.70),
    _ContributionRow(4900.01, 5000, 9.90, 9.90),
    _ContributionRow(5000.01, 5100, 10.10, 10.10),
    _ContributionRow(5100.01, 5200, 10.30, 10.30),
    _ContributionRow(5200.01, 5300, 10.50, 10.50),
    _ContributionRow(5300.01, 5400, 10.70, 10.70),
    _ContributionRow(5400.01, 5500, 10.90, 10.90),
    _ContributionRow(5500.01, 5600, 11.10, 11.10),
    _ContributionRow(5600.01, 5700, 11.30, 11.30),
    _ContributionRow(5700.01, 5800, 11.50, 11.50),
    _ContributionRow(5800.01, 5900, 11.70, 11.70),
    _ContributionRow(5900.01, 6000, 11.90, 11.90),
    _ContributionRow(6000.01, 99999.99, 11.90, 11.90)
  ];
}

/// ============================================================================
/// CONTRIBUTION ROW
/// ============================================================================

class _ContributionRow {
  final double start;
  final double end;
  final double employer;
  final double employee;

  const _ContributionRow(
    this.start,
    this.end,
    this.employer,
    this.employee,
  );
}

/// ============================================================================
/// PAYROLL GENERATION RESULT
/// ============================================================================

class PayrollGenerationResult {
  final DateTime month;
  final List<PayrollGenerationItem> generated;
  final List<PayrollGenerationItem> skipped;

  const PayrollGenerationResult({
    required this.month,
    required this.generated,
    required this.skipped,
  });

  int get generatedCount => generated.length;
  int get skippedCount => skipped.length;

  double get totalOvertimeDuration {
    return generated.fold(
      0.0,
      (sum, item) => sum + item.overtimeDuration,
    );
  }
}

/// ============================================================================
/// PAYROLL GENERATION ITEM
/// ============================================================================

class PayrollGenerationItem {
  final String employeeId;
  final String employeeName;
  final bool generated;
  final String message;

  final double basicSalary;
  final double fwSalary;
  final double elaunKedatangan;
  final double elaunPerkhidmatan;
  final double elaunKerajinan;
  final double overtimeDuration;
  final double overtimeAmount;
  final double cutiUmum;
  final double lateDeduction;
  final double unpaidDeduction;
  final int unpaidDays;
  //final int publicHolidayWorkedDays;
  final double shortageMinutes;

  final double statutoryWage;

  final double epfEmployee;
  final double epfEmployer;

  final double socsoEmployee;
  final double socsoEmployer;

  final double eisEmployee;
  final double eisEmployer;

  const PayrollGenerationItem({
    required this.employeeId,
    required this.employeeName,
    required this.generated,
    required this.message,
    this.basicSalary = 0.0,
    this.fwSalary = 0.0,
    this.elaunKedatangan = 0.0,
    this.elaunPerkhidmatan = 0.0,
    this.elaunKerajinan = 0.0,
    this.overtimeDuration = 0.0,
    this.overtimeAmount = 0.0,
    this.cutiUmum = 0.0,
    this.lateDeduction = 0.0,
    this.unpaidDeduction = 0.0,
    this.unpaidDays = 0,
    //this.publicHolidayWorkedDays = 0,
    this.shortageMinutes = 0.0,
    this.statutoryWage = 0.0,
    this.epfEmployee = 0.0,
    this.epfEmployer = 0.0,
    this.socsoEmployee = 0.0,
    this.socsoEmployer = 0.0,
    this.eisEmployee = 0.0,
    this.eisEmployer = 0.0,
  });
}
