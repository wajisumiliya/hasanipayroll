import '../screens/supabase_service.dart';

class AttendancePayrollService {
  AttendancePayrollService._();

  static const double overtimeMultiplier = 1.5;

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
        (item.generated ? generated : skipped).add(item);
      } catch (e) {
        skipped.add(PayrollGenerationItem(
          employeeId: _text(employee['employee_id']),
          employeeName: _text(employee['name']),
          generated: false,
          message: e.toString(),
        ));
      }
    }
    return PayrollGenerationResult(
      month: period,
      generated: generated,
      skipped: skipped,
    );
  }

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

    final attendance = await SupabaseService.getAttendanceByEmployeeMonth(
      employeeId, month.year, month.month,
    );
    final payrollHistory = await SupabaseService.getPayrollByEmployee(employeeId);
    final latest = payrollHistory.isNotEmpty ? payrollHistory.first : <String, dynamic>{};

    final basicSalary = _firstNumber([
      employee['basic_salary'], employee['basicSalary'],
      latest['basic_salary'], latest['basicSalary'],
    ]);
    if (basicSalary <= 0) {
      return PayrollGenerationItem(
        employeeId: employeeId,
        employeeName: employeeName,
        generated: false,
        message: 'Basic salary is missing. Import or create a salary record first.',
      );
    }

    int presentDays = 0, absentDays = 0, approvedOtMinutes = 0, unauthorizedOtMinutes = 0;
    for (final row in attendance) {
      final status = _text(row['status']).toLowerCase().trim();
      final work = _number(row['work_minutes']).toInt();
      final ot = _number(row['overtime_minutes']).toInt();
      final absent = status == 'absent' || status == 'leave without pay';
      if (absent) {
        absentDays++;
      } else if (work > 0 || status == 'present' || status == 'late') {
        presentDays++;
      }
      // OT enters payroll only after admin authorization.
      if (ot > 0) {
        if (_bool(row['ot_authorized'])) {
          approvedOtMinutes += ot;
        } else {
          unauthorizedOtMinutes += ot;
        }
      }
    }

    final expectedDays = _expectedWorkingDays(month);
    final missingDays = attendance.isEmpty
        ? 0
        : (expectedDays - presentDays - absentDays).clamp(0, expectedDays);
    final totalUnpaidDays = absentDays + missingDays;
    final dailyRate = expectedDays > 0 ? basicSalary / expectedDays : 0.0;
    final attendanceDeduction = dailyRate * totalUnpaidDays;

    final approvedOtHours = approvedOtMinutes / 60.0;
    final unauthorizedOtHours = unauthorizedOtMinutes / 60.0;
    final overtimeAmount = approvedOtHours * (basicSalary / 26.0 / 8.0) * overtimeMultiplier;

    final periodText = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';

    double n(String snake, String camel) => _firstNumber([latest[snake], latest[camel]]);
    String t(String key) => _text(employee[key]).isNotEmpty ? _text(employee[key]) : _text(latest[key]);

    final data = <String, dynamic>{
      'employee_id': employeeId,
      'period': periodText,
      'basic_salary': basicSalary,
      'elaun_kedatangan': n('elaun_kedatangan', 'elaunKedatangan'),
      'elaun_perkhidmatan': n('elaun_perkhidmatan', 'elaunPerkhidmatan'),
      'elaun_kerajinan': n('elaun_kerajinan', 'elaunKerajinan'),
      'overtime': overtimeAmount,
      'bonus': n('bonus', 'bonus'),
      'commission': n('commission', 'commission'),
      'other_earnings': n('other_earnings', 'otherEarnings'),
      // Existing cuti_umum plus attendance-based deduction.
      'cuti_umum': n('cuti_umum', 'cutiUmum') + attendanceDeduction,
      'epf_employee': n('epf_employee', 'epfEmployee'),
      'socso_employee': n('socso_employee', 'socsoEmployee'),
      'eis_employee': n('eis_employee', 'eisEmployee'),
      'pcb': n('pcb', 'pcb'),
      'zakat': n('zakat', 'zakat'),
      'epf_employer': n('epf_employer', 'epfEmployer'),
      'socso_employer': n('socso_employer', 'socsoEmployer'),
      'eis_employer': n('eis_employer', 'eisEmployer'),
      'new_ic_no': t('new_ic_no'),
      'bank_code': t('bank_code'),
      'bank_account': t('bank_account'),
      'remarks': 'Attendance payroll | Present: $presentDays | Absent: $absentDays | Missing: $missingDays | Approved OT: ${approvedOtHours.toStringAsFixed(2)} hrs | Unauthorized OT omitted: ${unauthorizedOtHours.toStringAsFixed(2)} hrs',
    };

    final existing = payrollHistory.where((p) => _text(p['period']).startsWith(periodText.substring(0, 7))).toList();
    if (existing.isNotEmpty) {
      if (!overwriteExisting) {
        return PayrollGenerationItem(
          employeeId: employeeId, employeeName: employeeName,
          generated: false, message: 'Payroll already exists for this month.',
        );
      }
      await SupabaseService.updatePayroll(existing.first['id'], data);
    } else {
      await SupabaseService.addPayroll(data);
    }

    return PayrollGenerationItem(
      employeeId: employeeId, employeeName: employeeName,
      generated: true, message: 'Payroll generated successfully.',
      presentDays: presentDays, absentDays: absentDays, missingDays: missingDays,
      approvedOtHours: approvedOtHours, unauthorizedOtHours: unauthorizedOtHours,
      overtimeAmount: overtimeAmount, attendanceDeduction: attendanceDeduction,
    );
  }

  static Future<List<Map<String, dynamic>>> _getEmployees(String? branchId) async {
    var query = SupabaseService.client.from('employees').select();
    if (branchId != null && branchId.trim().isNotEmpty) {
      query = query.eq('branch_id', branchId.trim());
    }
    final response = await query.eq('is_active', true).order('employee_id');
    return List<Map<String, dynamic>>.from(response);
  }

  static int _expectedWorkingDays(DateTime month) {
    int count = 0;
    final last = DateTime(month.year, month.month + 1, 0);
    for (var d = DateTime(month.year, month.month, 1); !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) count++;
    }
    return count;
  }

  static String _text(dynamic value) => value?.toString() ?? '';
  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_text(value).replaceAll(',', '').trim()) ?? 0;
  }
  static double _firstNumber(List<dynamic> values) {
    for (final value in values) {
      final number = _number(value);
      if (number != 0) return number;
    }
    return 0;
  }
  static bool _bool(dynamic value) {
    if (value is bool) return value;
    final text = _text(value).toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }
}

class PayrollGenerationResult {
  final DateTime month;
  final List<PayrollGenerationItem> generated;
  final List<PayrollGenerationItem> skipped;
  const PayrollGenerationResult({required this.month, required this.generated, required this.skipped});
  int get generatedCount => generated.length;
  int get skippedCount => skipped.length;
  double get totalOvertime => generated.fold(0, (v, e) => v + e.overtimeAmount);
  double get totalAttendanceDeduction => generated.fold(0, (v, e) => v + e.attendanceDeduction);
}

class PayrollGenerationItem {
  final String employeeId, employeeName, message;
  final bool generated;
  final int presentDays, absentDays, missingDays;
  final double approvedOtHours, unauthorizedOtHours, overtimeAmount, attendanceDeduction;
  const PayrollGenerationItem({
    required this.employeeId, required this.employeeName,
    required this.generated, required this.message,
    this.presentDays = 0, this.absentDays = 0, this.missingDays = 0,
    this.approvedOtHours = 0, this.unauthorizedOtHours = 0,
    this.overtimeAmount = 0, this.attendanceDeduction = 0,
  });
}
