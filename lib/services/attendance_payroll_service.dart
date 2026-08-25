import '../screens/supabase_service.dart';

class AttendancePayrollService {
  AttendancePayrollService._();

  /// ============================================================
  /// GENERATE MONTHLY PAYROLL
  ///
  /// CURRENT STAGE:
  /// Payroll is generated ONLY from employee_salary_defaults.
  ///
  /// No attendance calculation is performed yet.
  ///
  /// Source table:
  ///   employee_salary_defaults
  ///
  /// Required columns:
  ///   employee_id
  ///   basic_salary
  ///   fw_salary
  ///   elaun_kedatangan
  ///   elaun_perkhidmatan
  ///   elaun_kerajinan
  ///
  /// Later we can add your attendance/payroll calculation rules.
  /// ============================================================

  static Future<PayrollGenerationResult> generateMonthlyPayroll({
    required DateTime month,
    String? branchId,
    bool overwriteExisting = true,
  }) async {
    final period = DateTime(month.year, month.month, 1);

    final employees = await _getEmployees(branchId);

    final generated = <PayrollGenerationItem>[];
    final skipped = <PayrollGenerationItem>[];

    for (final employee in employees) {
      try {
        final item = await generateEmployeePayroll(
          employee: employee,
          month: period,
          overwriteExisting: overwriteExisting,
        );

        if (item.generated) {
          generated.add(item);
        } else {
          skipped.add(item);
        }
      } catch (e) {
        skipped.add(
          PayrollGenerationItem(
            employeeId: _text(employee['employee_id']),
            employeeName: _text(employee['name']),
            generated: false,
            message: 'Failed: $e',
          ),
        );
      }
    }

    return PayrollGenerationResult(
      month: period,
      generated: generated,
      skipped: skipped,
    );
  }

  /// ============================================================
  /// GENERATE ONE EMPLOYEE PAYROLL
  /// ============================================================

  static Future<PayrollGenerationItem> generateEmployeePayroll({
    required Map<String, dynamic> employee,
    required DateTime month,
    bool overwriteExisting = true,
  }) async {
    final employeeId = _text(employee['employee_id']);
    final employeeName = _text(employee['name']);

    if (employeeId.isEmpty) {
      return PayrollGenerationItem(
        employeeId: '',
        employeeName: employeeName,
        generated: false,
        message: 'Employee ID is missing.',
      );
    }

    // ------------------------------------------------------------
    // GET SALARY DEFAULT FOR THIS EMPLOYEE
    // ------------------------------------------------------------

    final salaryDefault = await _getSalaryDefault(employeeId);

    if (salaryDefault == null) {
      return PayrollGenerationItem(
        employeeId: employeeId,
        employeeName: employeeName,
        generated: false,
        message:
            'No salary default found in employee_salary_defaults.',
      );
    }

    // ------------------------------------------------------------
    // READ SALARY DEFAULT VALUES
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // BASIC SALARY CHECK
    // ------------------------------------------------------------

    if (basicSalary <= 0) {
      return PayrollGenerationItem(
        employeeId: employeeId,
        employeeName: employeeName,
        generated: false,
        message:
            'Basic salary is missing in employee_salary_defaults.',
      );
    }

    // ------------------------------------------------------------
    // PAYROLL PERIOD
    // ------------------------------------------------------------

    final periodText =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}-01';

    // ------------------------------------------------------------
    // EMPLOYEE INFORMATION
    // ------------------------------------------------------------

    final newIcNo = _text(
      employee['new_ic_no'],
    );

    final bankCode = _text(
      employee['bank_code'],
    );

    final bankAccount = _text(
      employee['bank_account'],
    );

    // ------------------------------------------------------------
    // PAYROLL DATA
    //
    // IMPORTANT:
    // No attendance calculation here.
    // No overtime calculation here.
    // No deduction calculation here.
    //
    // Those rules can be added later.
    // ------------------------------------------------------------

    final data = <String, dynamic>{
      'employee_id': employeeId,

      'period': periodText,

      // Salary defaults
      'basic_salary': basicSalary,
      'fw_salary': fwSalary,
      'elaun_kedatangan': elaunKedatangan,
      'elaun_perkhidmatan': elaunPerkhidmatan,
      'elaun_kerajinan': elaunKerajinan,

      // Future payroll calculation fields
      'overtime': 0,
      'bonus': 0,
      'commission': 0,
      'other_earnings': 0,

      // Future deduction calculation fields
      'cuti_umum': 0,
      'epf_employee': 0,
      'socso_employee': 0,
      'eis_employee': 0,
      'pcb': 0,
      'zakat': 0,

      // Future employer contribution calculation
      'epf_employer': 0,
      'socso_employer': 0,
      'eis_employer': 0,

      // Employee information
      'new_ic_no': newIcNo,
      'bank_code': bankCode,
      'bank_account': bankAccount,

      'remarks':
          'Generated from employee_salary_defaults',
    };

    // ------------------------------------------------------------
    // CHECK EXISTING PAYROLL FOR SAME EMPLOYEE + MONTH
    // ------------------------------------------------------------

    final existing = await _getPayrollForPeriod(
      employeeId,
      periodText,
    );

    if (existing != null) {
      if (!overwriteExisting) {
        return PayrollGenerationItem(
          employeeId: employeeId,
          employeeName: employeeName,
          generated: false,
          message:
              'Payroll already exists for this month.',
        );
      }

      // Update existing payroll
      await SupabaseService.client
          .from('payroll')
          .update(data)
          .eq('id', existing['id']);
    } else {
      // Insert new payroll
      await SupabaseService.client
          .from('payroll')
          .insert(data);
    }

    return PayrollGenerationItem(
      employeeId: employeeId,
      employeeName: employeeName,
      generated: true,
      message:
          'Payroll generated from salary defaults.',
      basicSalary: basicSalary,
      fwSalary: fwSalary,
      elaunKedatangan: elaunKedatangan,
      elaunPerkhidmatan: elaunPerkhidmatan,
      elaunKerajinan: elaunKerajinan,
    );
  }

  // ============================================================
  // GET ACTIVE EMPLOYEES
  // ============================================================

  static Future<List<Map<String, dynamic>>> _getEmployees(
    String? branchId,
  ) async {
    var query = SupabaseService.client
        .from('employees')
        .select();

    if (branchId != null &&
        branchId.trim().isNotEmpty) {
      query = query.eq(
        'branch_id',
        branchId.trim(),
      );
    }

    final response = await query
        .eq('is_active', true)
        .order('employee_id');

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  // ============================================================
  // GET SALARY DEFAULT
  // ============================================================

  static Future<Map<String, dynamic>?> _getSalaryDefault(
    String employeeId,
  ) async {
    final response = await SupabaseService.client
        .from('employee_salary_defaults')
        .select()
        .eq('employee_id', employeeId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // GET EXISTING PAYROLL FOR EMPLOYEE + PERIOD
  // ============================================================

  static Future<Map<String, dynamic>?> _getPayrollForPeriod(
    String employeeId,
    String period,
  ) async {
    final response = await SupabaseService.client
        .from('payroll')
        .select()
        .eq('employee_id', employeeId)
        .eq('period', period)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static String _text(dynamic value) {
    return value?.toString() ?? '';
  }

  static double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          _text(value)
              .replaceAll(',', '')
              .trim(),
        ) ??
        0;
  }
}

// ============================================================================
// PAYROLL GENERATION RESULT
// ============================================================================

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

  const PayrollGenerationItem({
    required this.employeeId,
    required this.employeeName,
    required this.generated,
    required this.message,

    this.basicSalary = 0,
    this.fwSalary = 0,
    this.elaunKedatangan = 0,
    this.elaunPerkhidmatan = 0,
    this.elaunKerajinan = 0,
  });
}