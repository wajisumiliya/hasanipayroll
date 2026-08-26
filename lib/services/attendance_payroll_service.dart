import '../screens/supabase_service.dart';

/// Payroll generation service.
///
/// Salary fields come from employee_salary_defaults.
/// Approved overtime comes from submitted attendance rows where
/// ot_authorized is true (stored as TEXT in the database).
/// Other calculations remain zero until their rules are provided.
class AttendancePayrollService {
  AttendancePayrollService._();

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
      if (id.isNotEmpty) employeeMap[id] = employee;
    }

    final generated = <PayrollGenerationItem>[];
    final skipped = <PayrollGenerationItem>[];

    for (final employeeId in normalizedIds) {
      final employee = employeeMap[employeeId];

      if (employee == null) {
        skipped.add(PayrollGenerationItem(
          employeeId: employeeId,
          employeeName: '',
          generated: false,
          message: 'Employee not found in employees table.',
        ));
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
        skipped.add(PayrollGenerationItem(
          employeeId: employeeId,
          employeeName: _text(employee['name']),
          generated: false,
          message: 'Failed: $e',
        ));
      }
    }

    return PayrollGenerationResult(
      month: periodMonth,
      generated: generated,
      skipped: skipped,
    );
  }

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

    final attendance = await _getSubmittedAttendanceForMonth(
      employeeId,
      month,
    );

    double overtimeDuration = 0.0;

    for (final row in attendance) {
      if (_isOtAuthorized(row['ot_authorized'])) {
        overtimeDuration += _number(row['overtime_duration']);
      }
    }

    final period = _periodText(month);

    final data = <String, dynamic>{
      'employee_id': employeeId,
      'period': period,
      'basic_salary': basicSalary,
      'fw_salary': fwSalary,
      'elaun_kedatangan': elaunKedatangan,
      'elaun_perkhidmatan': elaunPerkhidmatan,
      'elaun_kerajinan': elaunKerajinan,
      'overtime': overtimeDuration,
      'bonus': 0,
      'commission': 0,
      'other_earnings': 0,
      'cuti_umum': 0,
      'epf_employee': 0,
      'epf_employer': 0,
      'socso_employee': 0,
      'socso_employer': 0,
      'eis_employee': 0,
      'eis_employer': 0,
      'pcb': 0,
      'zakat': 0,
      'new_ic_no': _text(employee['new_ic_no']),
      'bank_code': _text(employee['bank_code']),
      'bank_account': _text(employee['bank_account']),
      'remarks':
          'Generated for selected employee. Approved OT duration: '
          '${overtimeDuration.toStringAsFixed(2)}',
    };

    final existing = await _getPayrollForPeriod(employeeId, period);

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
          overtimeDuration: overtimeDuration,
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
      // payroll.id must have a database default such as:
      // (gen_random_uuid())::text
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
      overtimeDuration: overtimeDuration,
    );
  }

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

  static Future<Map<String, dynamic>?> _getSalaryDefault(
    String employeeId,
  ) async {
    final response = await SupabaseService.client
        .from('employee_salary_defaults')
        .select(
          'employee_id,basic_salary,fw_salary,elaun_kedatangan,'
          'elaun_perkhidmatan,elaun_kerajinan',
        );

    final wantedId = _normalizeId(employeeId);

    for (final row in response) {
      if (_normalizeId(row['employee_id']) == wantedId) {
        return Map<String, dynamic>.from(row);
      }
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>>
      _getSubmittedAttendanceForMonth(
    String employeeId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final response = await SupabaseService.client
        .from('attendance')
        .select(
          'employee_id,attendance_date,overtime_duration,ot_authorized,is_submitted',
        )
        .eq('employee_id', employeeId)
        .eq('is_submitted', true)
        .gte('attendance_date', _dateText(start))
        .lt('attendance_date', _dateText(end));

    return List<Map<String, dynamic>>.from(response);
  }

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

    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  static String _normalizeId(dynamic value) {
    return _text(value).trim().toUpperCase();
  }

  static String _text(dynamic value) {
    return value?.toString() ?? '';
  }

  static double _number(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();

    final text = value.toString().replaceAll(',', '').trim();
    if (text.isEmpty) return 0.0;

    return double.tryParse(text) ?? 0.0;
  }

  static bool _isOtAuthorized(dynamic value) {
    if (value is bool) return value;

    final text = _text(value).trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
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
}

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
