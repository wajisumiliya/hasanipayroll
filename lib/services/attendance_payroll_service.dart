import '../screens/supabase_service.dart';

/// ============================================================================
/// ATTENDANCE PAYROLL SERVICE
/// ============================================================================
///
/// Payroll generation:
///
/// employees
///     ↓
/// employee_salary_defaults
///     ↓
/// attendance (submitted + authorized OT)
///     ↓
/// payroll
///
/// Current salary fields:
///   basic_salary
///   fw_salary
///   elaun_kedatangan
///   elaun_perkhidmatan
///   elaun_kerajinan
///
/// Current OT rule:
///   attendance.is_submitted = true
///   AND
///   attendance.ot_authorized = "true"
///
/// overtime_duration is copied as a numeric value into payroll.overtime.
/// No OT money/rate calculation is performed yet.
///
/// Future calculations currently remain 0:
///   bonus
///   commission
///   other_earnings
///   cuti_umum
///   EPF
///   SOCSO
///   EIS
///   PCB
///   Zakat
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
    final periodMonth = DateTime(
      month.year,
      month.month,
      1,
    );

    final normalizedIds = employeeIds
        .map(_normalizeId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedIds.isEmpty) {
      throw Exception(
        'Please select at least one employee.',
      );
    }

    // ------------------------------------------------------------------------
    // GET SELECTED EMPLOYEES
    // ------------------------------------------------------------------------

    final employees = await _getEmployeesByIds(
      normalizedIds,
    );

    final employeeMap = <String, Map<String, dynamic>>{};

    for (final employee in employees) {
      final id = _normalizeId(
        employee['employee_id'],
      );

      if (id.isNotEmpty) {
        employeeMap[id] = employee;
      }
    }

    final generated = <PayrollGenerationItem>[];
    final skipped = <PayrollGenerationItem>[];

    // ------------------------------------------------------------------------
    // GENERATE ONE EMPLOYEE AT A TIME
    // ------------------------------------------------------------------------

    for (final employeeId in normalizedIds) {
      final employee = employeeMap[employeeId];

      if (employee == null) {
        skipped.add(
          PayrollGenerationItem(
            employeeId: employeeId,
            employeeName: '',
            generated: false,
            message:
                'Employee not found in employees table.',
          ),
        );

        continue;
      }

      try {
        final result =
            await generateEmployeePayroll(
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
            employeeName: _text(
              employee['name'],
            ),
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
  // GENERATE PAYROLL FOR ONE EMPLOYEE
  // ==========================================================================

  static Future<PayrollGenerationItem>
      generateEmployeePayroll({
    required Map<String, dynamic> employee,
    required DateTime month,
    bool overwriteExisting = true,
  }) async {
    final employeeId = _normalizeId(
      employee['employee_id'],
    );

    final employeeName = _text(
      employee['name'],
    );

    if (employeeId.isEmpty) {
      return PayrollGenerationItem(
        employeeId: '',
        employeeName: employeeName,
        generated: false,
        message: 'Employee ID is missing.',
      );
    }

    // =========================================================================
    // 1. GET SALARY DEFAULT
    // =========================================================================

    final salaryDefault =
        await _getSalaryDefault(employeeId);

    if (salaryDefault == null) {
      return PayrollGenerationItem(
        employeeId: employeeId,
        employeeName: employeeName,
        generated: false,
        message:
            'No salary default found in employee_salary_defaults for $employeeId.',
      );
    }

    // =========================================================================
    // 2. SALARY VALUES
    // =========================================================================

    final basicSalary = _number(
      salaryDefault['basic_salary'],
    );

    final fwSalary = _number(
      salaryDefault['fw_salary'],
    );

    final elaunKedatangan = _number(
      salaryDefault['elaun_kedatangan'],
    );

    final elaunPerkhidmatan = _number(
      salaryDefault['elaun_perkhidmatan'],
    );

    final elaunKerajinan = _number(
      salaryDefault['elaun_kerajinan'],
    );

    // =========================================================================
    // 3. GET SUBMITTED ATTENDANCE
    // =========================================================================

    final attendance =
        await _getSubmittedAttendanceForMonth(
      employeeId,
      month,
    );

    // =========================================================================
    // 4. APPROVED OVERTIME
    // =========================================================================

    double overtimeDuration = 0.0;

    for (final row in attendance) {
      if (_isOtAuthorized(
        row['ot_authorized'],
      )) {
        overtimeDuration += _number(
          row['overtime_duration'],
        );
      }
    }

    // =========================================================================
    // 5. PERIOD
    // =========================================================================

    final period = _periodText(month);

    // =========================================================================
    // 6. PAYROLL DATA
    // =========================================================================

    final data = <String, dynamic>{
      'employee_id': employeeId,
      'period': period,

      // -----------------------------------------------------------------------
      // SALARY DEFAULTS
      // -----------------------------------------------------------------------

      'basic_salary': basicSalary,
      'fw_salary': fwSalary,
      'elaun_kedatangan': elaunKedatangan,
      'elaun_perkhidmatan': elaunPerkhidmatan,
      'elaun_kerajinan': elaunKerajinan,

      // -----------------------------------------------------------------------
      // OVERTIME
      // -----------------------------------------------------------------------

      'overtime': overtimeDuration,

      // -----------------------------------------------------------------------
      // FUTURE EARNINGS
      // -----------------------------------------------------------------------

      'bonus': 0,
      'commission': 0,
      'other_earnings': 0,
      'cuti_umum': 0,

      // -----------------------------------------------------------------------
      // FUTURE STATUTORY
      // -----------------------------------------------------------------------

      'epf_employee': 0,
      'epf_employer': 0,

      'socso_employee': 0,
      'socso_employer': 0,

      'eis_employee': 0,
      'eis_employer': 0,

      'pcb': 0,
      'zakat': 0,

      // -----------------------------------------------------------------------
      // EMPLOYEE INFORMATION
      // -----------------------------------------------------------------------

      'new_ic_no': _text(
        employee['new_ic_no'],
      ),

      'bank_code': _text(
        employee['bank_code'],
      ),

      'bank_account': _text(
        employee['bank_account'],
      ),

      // -----------------------------------------------------------------------
      // REMARKS
      // -----------------------------------------------------------------------

      'remarks':
          'Generated for selected employee. '
          'Approved OT duration: '
          '${overtimeDuration.toStringAsFixed(2)}',
    };

    // =========================================================================
    // 7. CHECK EXISTING PAYROLL
    // =========================================================================

    final existing =
        await _getPayrollForPeriod(
      employeeId,
      period,
    );

    // =========================================================================
    // 8. UPDATE EXISTING PAYROLL
    // =========================================================================

    if (existing != null) {
      if (!overwriteExisting) {
        return PayrollGenerationItem(
          employeeId: employeeId,
          employeeName: employeeName,
          generated: false,
          message:
              'Payroll already exists for $employeeId for $period.',

          basicSalary: basicSalary,
          fwSalary: fwSalary,
          elaunKedatangan:
              elaunKedatangan,
          elaunPerkhidmatan:
              elaunPerkhidmatan,
          elaunKerajinan:
              elaunKerajinan,
          overtimeDuration:
              overtimeDuration,
        );
      }

      final existingId = existing['id'];

      if (existingId == null ||
          _text(existingId).isEmpty) {
        throw Exception(
          'Existing payroll record has no id.',
        );
      }

      await SupabaseService.client
          .from('payroll')
          .update(data)
          .eq(
            'id',
            existingId,
          );
    }

    // =========================================================================
    // 9. INSERT NEW PAYROLL
    // =========================================================================

    else {
      // IMPORTANT:
      // Do NOT send payroll.id.
      //
      // Your database should generate the ID automatically.
      await SupabaseService.client
          .from('payroll')
          .insert(data);
    }

    // =========================================================================
    // 10. SUCCESS
    // =========================================================================

    return PayrollGenerationItem(
      employeeId: employeeId,
      employeeName: employeeName,
      generated: true,
      message:
          'Payroll generated successfully.',

      basicSalary: basicSalary,
      fwSalary: fwSalary,
      elaunKedatangan:
          elaunKedatangan,
      elaunPerkhidmatan:
          elaunPerkhidmatan,
      elaunKerajinan:
          elaunKerajinan,
      overtimeDuration:
          overtimeDuration,
    );
  }

  // ==========================================================================
  // EMPLOYEES
  // ==========================================================================

  static Future<List<Map<String, dynamic>>>
      _getEmployeesByIds(
    List<String> employeeIds,
  ) async {
    final response =
        await SupabaseService.client
            .from('employees')
            .select(
              'employee_id,'
              'name,'
              'new_ic_no,'
              'bank_code,'
              'bank_account,'
              'branch_id,'
              'is_active',
            )
            .inFilter(
              'employee_id',
              employeeIds,
            );

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  // ==========================================================================
  // SALARY DEFAULT
  // ==========================================================================
  //
  // IMPORTANT:
  //
  // We query the requested employee ID directly.
  //
  // Example:
  //
  // HED2073
  //
  // Then we verify the returned employee_id after trimming and uppercasing.
  //
  // This is better than downloading the entire employee_salary_defaults table.
  // ==========================================================================

  static Future<Map<String, dynamic>?>
      _getSalaryDefault(
    String employeeId,
  ) async {
    final wantedId =
        _normalizeId(employeeId);

    if (wantedId.isEmpty) {
      return null;
    }

    try {
      final response =
          await SupabaseService.client
              .from(
                'employee_salary_defaults',
              )
              .select(
                'employee_id,'
                'basic_salary,'
                'fw_salary,'
                'elaun_kedatangan,'
                'elaun_perkhidmatan,'
                'elaun_kerajinan',
              )
              .eq(
                'employee_id',
                wantedId,
              );

      // -----------------------------------------------------------------------
      // DEBUG INFORMATION
      // -----------------------------------------------------------------------

      print(
        '========================================',
      );

      print(
        'PAYROLL SALARY DEFAULT LOOKUP',
      );

      print(
        'Requested employee ID: [$wantedId]',
      );

      print(
        'Rows returned: ${response.length}',
      );

      print(
        'Salary response: $response',
      );

      print(
        '========================================',
      );

      // -----------------------------------------------------------------------
      // NO ROW
      // -----------------------------------------------------------------------

      if (response.isEmpty) {
        return null;
      }

      // -----------------------------------------------------------------------
      // FIRST MATCH
      // -----------------------------------------------------------------------

      for (final row in response) {
        final databaseId =
            _normalizeId(
          row['employee_id'],
        );

        if (databaseId == wantedId) {
          return Map<String, dynamic>.from(
            row,
          );
        }
      }

      return null;
    } catch (e) {
      print(
        '========================================',
      );

      print(
        'SALARY DEFAULT QUERY ERROR',
      );

      print(
        'Employee ID: [$wantedId]',
      );

      print(
        'Error: $e',
      );

      print(
        '========================================',
      );

      rethrow;
    }
  }

  // ==========================================================================
  // SUBMITTED ATTENDANCE
  // ==========================================================================

  static Future<List<Map<String, dynamic>>>
      _getSubmittedAttendanceForMonth(
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

    final response =
        await SupabaseService.client
            .from('attendance')
            .select(
              'employee_id,'
              'attendance_date,'
              'overtime_duration,'
              'ot_authorized,'
              'is_submitted',
            )
            .eq(
              'employee_id',
              employeeId,
            )
            .eq(
              'is_submitted',
              true,
            )
            .gte(
              'attendance_date',
              _dateText(start),
            )
            .lt(
              'attendance_date',
              _dateText(end),
            );

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  // ==========================================================================
  // EXISTING PAYROLL
  // ==========================================================================

  static Future<Map<String, dynamic>?>
      _getPayrollForPeriod(
    String employeeId,
    String period,
  ) async {
    final response =
        await SupabaseService.client
            .from('payroll')
            .select(
              'id,employee_id,period',
            )
            .eq(
              'employee_id',
              employeeId,
            )
            .eq(
              'period',
              period,
            )
            .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(
      response,
    );
  }

  // ==========================================================================
  // NORMALIZE EMPLOYEE ID
  // ==========================================================================

  static String _normalizeId(
    dynamic value,
  ) {
    return _text(value)
        .trim()
        .toUpperCase();
  }

  // ==========================================================================
  // TEXT
  // ==========================================================================

  static String _text(
    dynamic value,
  ) {
    return value?.toString() ?? '';
  }

  // ==========================================================================
  // NUMBER
  // ==========================================================================

  static double _number(
    dynamic value,
  ) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    final text = value
        .toString()
        .replaceAll(',', '')
        .trim();

    if (text.isEmpty) {
      return 0.0;
    }

    return double.tryParse(text) ?? 0.0;
  }

  // ==========================================================================
  // OT AUTHORIZED
  // ==========================================================================
  //
  // Your attendance schema has:
  //
  // ot_authorized text
  //
  // so this handles:
  //
  // true
  // TRUE
  // 1
  // yes
  //
  // ==========================================================================

  static bool _isOtAuthorized(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    final text =
        _text(value)
            .trim()
            .toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
  }

  // ==========================================================================
  // DATE TEXT
  // ==========================================================================

  static String _dateText(
    DateTime date,
  ) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  // ==========================================================================
  // PAYROLL PERIOD
  // ==========================================================================

  static String _periodText(
    DateTime month,
  ) {
    return '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}-01';
  }
}

// ============================================================================
// PAYROLL GENERATION RESULT
// ============================================================================

class PayrollGenerationResult {
  final DateTime month;

  final List<PayrollGenerationItem>
      generated;

  final List<PayrollGenerationItem>
      skipped;

  const PayrollGenerationResult({
    required this.month,
    required this.generated,
    required this.skipped,
  });

  int get generatedCount =>
      generated.length;

  int get skippedCount =>
      skipped.length;

  double get totalOvertimeDuration {
    return generated.fold(
      0.0,
      (sum, item) =>
          sum + item.overtimeDuration,
    );
  }
}

// ============================================================================
// PAYROLL GENERATION ITEM
// ============================================================================

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
  });
}