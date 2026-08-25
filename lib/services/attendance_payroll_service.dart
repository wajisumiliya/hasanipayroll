import '../screens/supabase_service.dart';

class AttendancePayrollService {
  AttendancePayrollService._();

  // ============================================================================
  // GENERATE MONTHLY PAYROLL
  //
  // SOURCE:
  // employee_salary_defaults
  //
  // Every record in employee_salary_defaults is used.
  //
  // Salary fields:
  //   basic_salary
  //   fw_salary
  //   elaun_kedatangan
  //   elaun_perkhidmatan
  //   elaun_kerajinan
  //
  // NO ATTENDANCE CALCULATION YET.
  // ============================================================================

  static Future<PayrollGenerationResult>
      generateMonthlyPayroll({
    required DateTime month,
    String? branchId,
    bool overwriteExisting = true,
  }) async {
    final period = DateTime(
      month.year,
      month.month,
      1,
    );

    // --------------------------------------------------------------------------
    // LOAD ALL EMPLOYEES
    // --------------------------------------------------------------------------

    final employees =
        await _getAllEmployees();

    // --------------------------------------------------------------------------
    // CREATE EMPLOYEE LOOKUP
    //
    // Normalized:
    // BAJ010
    // baj010
    // " BAJ010 "
    //
    // will all become:
    //
    // BAJ010
    // --------------------------------------------------------------------------

    final employeeMap =
        <String, Map<String, dynamic>>{};

    for (final employee in employees) {
      final employeeId =
          _normalise(
        employee['employee_id'],
      );

      if (employeeId.isNotEmpty) {
        employeeMap[employeeId] =
            employee;
      }
    }

    // --------------------------------------------------------------------------
    // LOAD ALL SALARY DEFAULTS
    //
    // THIS IS NOW THE MAIN SOURCE.
    // --------------------------------------------------------------------------

    final salaryDefaults =
        await _getAllSalaryDefaults();

    final generated =
        <PayrollGenerationItem>[];

    final skipped =
        <PayrollGenerationItem>[];

    // --------------------------------------------------------------------------
    // GENERATE PAYROLL FOR EVERY SALARY DEFAULT
    // --------------------------------------------------------------------------

    for (final salaryDefault
        in salaryDefaults) {
      try {
        final employeeId =
            _normalise(
          salaryDefault['employee_id'],
        );

        if (employeeId.isEmpty) {
          skipped.add(
            PayrollGenerationItem(
              employeeId: '',
              employeeName: '',
              generated: false,
              message:
                  'Salary default has empty employee_id.',
            ),
          );

          continue;
        }

        // --------------------------------------------------------------
        // FIND EMPLOYEE
        // --------------------------------------------------------------

        final employee =
            employeeMap[employeeId];

        final employeeName =
            employee == null
                ? ''
                : _text(
                    employee['name'],
                  );

        // --------------------------------------------------------------
        // GENERATE
        // --------------------------------------------------------------

        final item =
            await generateEmployeePayroll(
          employeeId: employeeId,
          employee: employee,
          salaryDefault:
              salaryDefault,
          month: period,
          overwriteExisting:
              overwriteExisting,
        );

        if (item.generated) {
          generated.add(item);
        } else {
          skipped.add(item);
        }
      } catch (e) {
        skipped.add(
          PayrollGenerationItem(
            employeeId:
                _text(
              salaryDefault['employee_id'],
            ),
            employeeName: '',
            generated: false,
            message:
                'Failed: $e',
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

  // ============================================================================
  // GENERATE ONE EMPLOYEE PAYROLL
  // ============================================================================

  static Future<PayrollGenerationItem>
      generateEmployeePayroll({
    required String employeeId,
    required Map<String, dynamic>?
        employee,
    required Map<String, dynamic>
        salaryDefault,
    required DateTime month,
    bool overwriteExisting = true,
  }) async {
    final employeeName =
        employee == null
            ? ''
            : _text(
                employee['name'],
              );

    // --------------------------------------------------------------------------
    // SALARY VALUES
    // --------------------------------------------------------------------------

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
      salaryDefault[
          'elaun_kedatangan'],
    );

    final elaunPerkhidmatan =
        _number(
      salaryDefault[
          'elaun_perkhidmatan'],
    );

    final elaunKerajinan =
        _number(
      salaryDefault[
          'elaun_kerajinan'],
    );

    // --------------------------------------------------------------------------
    // BASIC SALARY IS ALLOWED TO BE ZERO?
    //
    // For now we only check whether the salary-default row exists.
    //
    // If basic_salary = 0, we still generate it because the record exists.
    // --------------------------------------------------------------------------

    // --------------------------------------------------------------------------
    // PAYROLL PERIOD
    // --------------------------------------------------------------------------

    final periodText =
        '${month.year.toString().padLeft(4, '0')}-'
        '${month.month.toString().padLeft(2, '0')}-01';

    // --------------------------------------------------------------------------
    // EMPLOYEE INFORMATION
    // --------------------------------------------------------------------------

    final newIcNo =
        employee == null
            ? ''
            : _text(
                employee['new_ic_no'],
              );

    final bankCode =
        employee == null
            ? ''
            : _text(
                employee['bank_code'],
              );

    final bankAccount =
        employee == null
            ? ''
            : _text(
                employee['bank_account'],
              );

    // --------------------------------------------------------------------------
    // PAYROLL DATA
    //
    // NO ATTENDANCE CALCULATION YET.
    // --------------------------------------------------------------------------

    final data =
        <String, dynamic>{
      'employee_id':
          employeeId,

      'period':
          periodText,

      // ------------------------------------------------------------
      // SALARY DEFAULTS
      // ------------------------------------------------------------

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

      // ------------------------------------------------------------
      // OTHER EARNINGS
      // ------------------------------------------------------------

      'overtime': 0,
      'bonus': 0,
      'commission': 0,
      'other_earnings': 0,

      // ------------------------------------------------------------
      // DEDUCTIONS
      //
      // WILL BE CALCULATED LATER.
      // ------------------------------------------------------------

      'cuti_umum': 0,
      'epf_employee': 0,
      'socso_employee': 0,
      'eis_employee': 0,
      'pcb': 0,
      'zakat': 0,

      // ------------------------------------------------------------
      // EMPLOYER CONTRIBUTIONS
      // ------------------------------------------------------------

      'epf_employer': 0,
      'socso_employer': 0,
      'eis_employer': 0,

      // ------------------------------------------------------------
      // EMPLOYEE INFORMATION
      // ------------------------------------------------------------

      'new_ic_no':
          newIcNo,

      'bank_code':
          bankCode,

      'bank_account':
          bankAccount,

      'remarks':
          'Generated from employee_salary_defaults',
    };

    // ==========================================================================
    // FIND EXISTING PAYROLL
    // ==========================================================================

    final existing =
        await _getPayrollForPeriod(
      employeeId,
      periodText,
    );

    // ==========================================================================
    // EXISTING PAYROLL
    // ==========================================================================

    if (existing != null) {
      if (!overwriteExisting) {
        return PayrollGenerationItem(
          employeeId:
              employeeId,
          employeeName:
              employeeName,
          generated: false,
          message:
              'Payroll already exists for this month.',
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
        );
      }

      await SupabaseService.client
          .from('payroll')
          .update(data)
          .eq(
            'id',
            existing['id'],
          );
    }

    // ==========================================================================
    // NEW PAYROLL
    // ==========================================================================

    else {
      await SupabaseService.client
          .from('payroll')
          .insert(data);
    }

    return PayrollGenerationItem(
      employeeId:
          employeeId,
      employeeName:
          employeeName,
      generated: true,
      message:
          employee == null
              ? 'Generated from salary default. '
                  'Employee record was not found.'
              : 'Payroll generated successfully.',
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
    );
  }

  // ============================================================================
  // LOAD ALL EMPLOYEES
  // ============================================================================

  static Future<
      List<Map<String, dynamic>>>
      _getAllEmployees() async {
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
            );

    return List<
        Map<String, dynamic>>.from(
      response,
    );
  }

  // ============================================================================
  // LOAD ALL SALARY DEFAULTS
  //
  // IMPORTANT:
  // NO EMPLOYEE FILTER HERE.
  //
  // Every row in employee_salary_defaults
  // is loaded.
  // ============================================================================

  static Future<
      List<Map<String, dynamic>>>
      _getAllSalaryDefaults() async {
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
            .order(
              'employee_id',
            );

    return List<
        Map<String, dynamic>>.from(
      response,
    );
  }

  // ============================================================================
  // GET EXISTING PAYROLL
  // ============================================================================

  static Future<
      Map<String, dynamic>?>
      _getPayrollForPeriod(
    String employeeId,
    String period,
  ) async {
    final response =
        await SupabaseService.client
            .from('payroll')
            .select()
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

  // ============================================================================
  // NORMALISE EMPLOYEE ID
  // ============================================================================

  static String _normalise(
    dynamic value,
  ) {
    return value
        ?.toString()
        .trim()
        .toUpperCase() ??
        '';
  }

  // ============================================================================
  // TEXT
  // ============================================================================

  static String _text(
    dynamic value,
  ) {
    return value
            ?.toString()
            .trim() ??
        '';
  }

  // ============================================================================
  // NUMBER
  // ============================================================================

  static double _number(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    final text =
        _text(value)
            .replaceAll(',', '')
            .replaceAll('RM', '')
            .replaceAll('rm', '')
            .trim();

    if (text.isEmpty) {
      return 0;
    }

    return double.tryParse(
          text,
        ) ??
        0;
  }
}

// ============================================================================
// PAYROLL GENERATION RESULT
// ============================================================================

class PayrollGenerationResult {
  final DateTime month;

  final List<
      PayrollGenerationItem>
      generated;

  final List<
      PayrollGenerationItem>
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