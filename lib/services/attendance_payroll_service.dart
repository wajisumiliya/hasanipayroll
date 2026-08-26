import '../screens/supabase_service.dart';

/// ============================================================================
/// ATTENDANCE PAYROLL SERVICE
/// ============================================================================
///
/// CURRENT PAYROLL RULES
///
/// Salary:
///   basic_salary        -> employee_salary_defaults.basic_salary
///   fw_salary           -> employee_salary_defaults.fw_salary
///   elaun_kedatangan    -> employee_salary_defaults.elaun_kedatangan
///   elaun_perkhidmatan  -> employee_salary_defaults.elaun_perkhidmatan
///   elaun_kerajinan     -> employee_salary_defaults.elaun_kerajinan
///
/// Overtime:
///   attendance.overtime_duration
///   ONLY when attendance.ot_authorized = 'true'
///   ONLY submitted attendance is used
///
/// Not calculated yet:
///   bonus
///   commission
///   other_earnings
///   cuti_umum
///   epf
///   socso
///   eis
///   pcb
///   zakat
///
/// IMPORTANT DATABASE DETAILS
/// --------------------------
/// payroll.id                = TEXT with Supabase UUID default
/// payroll.period            = DATE
/// attendance.ot_authorized  = TEXT
/// attendance.overtime_duration = TEXT
/// ============================================================================

class AttendancePayrollService {
  AttendancePayrollService._();

  // ==========================================================================
  // GENERATE PAYROLL FOR SELECTED EMPLOYEES
  // ==========================================================================

  static Future<PayrollGenerationResult>
      generateMonthlyPayroll({
    required DateTime month,
    required List<String> employeeIds,
    bool overwriteExisting = true,
  }) async {
    final payrollMonth = DateTime(
      month.year,
      month.month,
      1,
    );

    final selectedIds = employeeIds
        .map(_normalizeId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (selectedIds.isEmpty) {
      throw Exception(
        'Please select at least one employee.',
      );
    }

    // ------------------------------------------------------------------------
    // GET SELECTED EMPLOYEES
    // ------------------------------------------------------------------------

    final employees =
        await _getEmployeesByIds(selectedIds);

    final employeeMap =
        <String, Map<String, dynamic>>{};

    for (final employee in employees) {
      final id =
          _normalizeId(employee['employee_id']);

      if (id.isNotEmpty) {
        employeeMap[id] = employee;
      }
    }

    final generated =
        <PayrollGenerationItem>[];

    final skipped =
        <PayrollGenerationItem>[];

    // ------------------------------------------------------------------------
    // GENERATE ONE BY ONE
    // ------------------------------------------------------------------------

    for (final employeeId in selectedIds) {
      final employee =
          employeeMap[employeeId];

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
          month: payrollMonth,
          overwriteExisting:
              overwriteExisting,
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
            employeeName:
                _text(employee['name']),
            generated: false,
            message:
                'Payroll generation failed: $e',
          ),
        );
      }
    }

    return PayrollGenerationResult(
      month: payrollMonth,
      generated: generated,
      skipped: skipped,
    );
  }

  // ==========================================================================
  // GENERATE ONE EMPLOYEE PAYROLL
  // ==========================================================================

  static Future<PayrollGenerationItem>
      generateEmployeePayroll({
    required Map<String, dynamic> employee,
    required DateTime month,
    bool overwriteExisting = true,
  }) async {
    final employeeId =
        _normalizeId(
      employee['employee_id'],
    );

    final employeeName =
        _text(
      employee['name'],
    );

    if (employeeId.isEmpty) {
      return PayrollGenerationItem(
        employeeId: '',
        employeeName: employeeName,
        generated: false,
        message:
            'Employee ID is missing.',
      );
    }

    // =========================================================================
    // 1. GET SALARY DEFAULTS
    // =========================================================================

    final salaryDefault =
        await _getSalaryDefault(
      employeeId,
    );

    if (salaryDefault == null) {
      return PayrollGenerationItem(
        employeeId: employeeId,
        employeeName: employeeName,
        generated: false,
        message:
            'No salary default found for $employeeId.',
      );
    }

    final basicSalary =
        _number(
      salaryDefault['basic_salary'],
    );

    final fwSalary =
        _number(
      salaryDefault['fw_salary'],
    );

    final elaunKedatangan =
        _number(
      salaryDefault['elaun_kedatangan'],
    );

    final elaunPerkhidmatan =
        _number(
      salaryDefault['elaun_perkhidmatan'],
    );

    final elaunKerajinan =
        _number(
      salaryDefault['elaun_kerajinan'],
    );

    // =========================================================================
    // 2. GET SUBMITTED ATTENDANCE
    // =========================================================================

    final attendance =
        await _getSubmittedAttendanceForMonth(
      employeeId,
      month,
    );

    // =========================================================================
    // 3. APPROVED OT
    // =========================================================================
    //
    // Your actual database:
    //
    // ot_authorized = TEXT
    //
    // So we accept:
    //
    // "true"
    // "TRUE"
    // "True"
    // "1"
    // "yes"
    //
    // overtime_duration is TEXT, so it is converted to double.
    // =========================================================================

    double overtimeDuration = 0;

    for (final row in attendance) {
      if (!_isOtAuthorized(
        row['ot_authorized'],
      )) {
        continue;
      }

      overtimeDuration +=
          _number(
        row['overtime_duration'],
      );
    }

    // =========================================================================
    // 4. PERIOD
    // ==========================================================================

    final period =
        _periodText(month);

    // =========================================================================
    // 5. PAYROLL DATA
    // ==========================================================================

    final data =
        <String, dynamic>{
      // Employee
      'employee_id':
          employeeId,

      // Date column
      'period':
          period,

      // Salary defaults
      'basic_salary':
          basicSalary,

      'fw_salary':
          fwSalary,

      'elaun_kedatangan':
          elaunKedatangan,

      'elaun_perkhidmatan':
          elaunPerkhidmatan,

      'elaun_kerajinan':
          elaunKerajinan,

      // Approved OT duration
      'overtime':
          overtimeDuration,

      // Not calculated yet
      'bonus': 0,

      'commission': 0,

      'other_earnings': 0,

      'cuti_umum': 0,

      // EPF
      'epf_employee': 0,

      'epf_employer': 0,

      // SOCSO
      'socso_employee': 0,

      'socso_employer': 0,

      // EIS
      'eis_employee': 0,

      'eis_employer': 0,

      // PCB
      'pcb': 0,

      // Zakat
      'zakat': 0,

      // Employee information
      'new_ic_no':
          _text(
        employee['new_ic_no'],
      ),

      'bank_code':
          _text(
        employee['bank_code'],
      ),

      'bank_account':
          _text(
        employee['bank_account'],
      ),

      'remarks':
          'Generated payroll. '
          'Approved OT duration: '
          '${overtimeDuration.toStringAsFixed(2)}',
    };

    // =========================================================================
    // 6. CHECK EXISTING PAYROLL
    // =========================================================================

    final existing =
        await _getPayrollForPeriod(
      employeeId,
      period,
    );

    // =========================================================================
    // 7. UPDATE EXISTING PAYROLL
    // =========================================================================

    if (existing != null) {
      if (!overwriteExisting) {
        return PayrollGenerationItem(
          employeeId:
              employeeId,
          employeeName:
              employeeName,
          generated: false,
          message:
              'Payroll already exists for '
              '$employeeId for $period.',
          basicSalary:
              basicSalary,
          fwSalary:
              fwSalary,
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

      final existingId =
          existing['id'];

      if (existingId == null ||
          _text(existingId).isEmpty) {
        throw Exception(
          'Existing payroll has no ID.',
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
    // 8. INSERT NEW PAYROLL
    // =========================================================================
    //
    // DO NOT provide "id".
    //
    // Supabase will generate it automatically because we added:
    //
    // DEFAULT (gen_random_uuid())::text
    // =========================================================================

    else {
      await SupabaseService.client
          .from('payroll')
          .insert(data);
    }

    // =========================================================================
    // 9. SUCCESS
    // =========================================================================

    return PayrollGenerationItem(
      employeeId:
          employeeId,
      employeeName:
          employeeName,
      generated: true,
      message:
          'Payroll generated successfully.',
      basicSalary:
          basicSalary,
      fwSalary:
          fwSalary,
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
  // GET EMPLOYEES
  // ==========================================================================

  static Future<
      List<Map<String, dynamic>>>
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

    return List<
        Map<String, dynamic>>.from(
      response,
    );
  }

  // ==========================================================================
  // GET SALARY DEFAULT
  // ==========================================================================

  static Future<Map<String, dynamic>?> _getSalaryDefault(
  String employeeId,
) async {
  final response = await SupabaseService.client
      .from('employee_salary_defaults')
      .select(
        'employee_id,'
        'basic_salary,'
        'fw_salary,'
        'elaun_kedatangan,'
        'elaun_perkhidmatan,'
        'elaun_kerajinan',
      );

  final wantedId = employeeId.trim().toUpperCase();

  for (final row in response) {
    final databaseId =
        (row['employee_id'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

    if (databaseId == wantedId) {
      return Map<String, dynamic>.from(row);
    }
  }

  return null;
}
  // ==========================================================================
  // GET SUBMITTED ATTENDANCE FOR MONTH
  // ==========================================================================

  static Future<
      List<Map<String, dynamic>>>
      _getSubmittedAttendanceForMonth(
    String employeeId,
    DateTime month,
  ) async {
    final start =
        DateTime(
      month.year,
      month.month,
      1,
    );

    final end =
        DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final startDate =
        _dateText(start);

    final endDate =
        _dateText(end);

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
              startDate,
            )
            .lt(
              'attendance_date',
              endDate,
            );

    return List<
        Map<String, dynamic>>.from(
      response,
    );
  }

  // ==========================================================================
  // GET EXISTING PAYROLL
  // ==========================================================================

  static Future<
      Map<String, dynamic>?>
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
  // OT AUTHORIZATION
  // ==========================================================================

  static bool _isOtAuthorized(
    dynamic value,
  ) {
    final text =
        _text(value).toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes';
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
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .trim();
  }

  // ==========================================================================
  // NUMBER
  // ==========================================================================

  static double _number(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    final text =
        value
            .toString()
            .replaceAll(',', '')
            .trim();

    if (text.isEmpty) {
      return 0;
    }

    return double.tryParse(
          text,
        ) ??
        0;
  }

  // ==========================================================================
  // DATE
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
      (
        total,
        item,
      ) {
        return total +
            item.overtimeDuration;
      },
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