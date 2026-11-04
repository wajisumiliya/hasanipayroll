import 'attendance_allowance_service.dart';
import 'payroll_month_scope.dart';

class AttendanceAllowanceDeduction {
  const AttendanceAllowanceDeduction(
      {required this.employeeId,
      required this.name,
      required this.branch,
      required this.reasons,
      required this.baseline,
      required this.paid,
      required this.deducted,
      required this.snapshot,
      required this.status});
  final String employeeId, name, branch, status;
  final List<AttendanceAllowanceReason> reasons;
  final double? baseline, paid, deducted;
  final bool snapshot;
  String get reasonText => reasons.map((r) => r.category).toSet().join(', ');
  String get dateText => reasons.map((reason) {
        final dates = reason.details.isNotEmpty
            ? reason.details
            : reason.dates.join(', ');
        return '${reason.category}: ${dates.isEmpty ? 'Dates unavailable' : dates}';
      }).join('\n');
  bool get needsReview => !snapshot || status != 'Fully deducted';
}

class AttendanceAllowanceReport {
  const AttendanceAllowanceReport(
      {required this.month, required this.rows, required this.branchName});
  final DateTime month;
  final List<AttendanceAllowanceDeduction> rows;
  final String branchName;
  double get confirmedTotal =>
      (rows
                  .where((r) => r.snapshot)
                  .fold(0.0, (sum, row) => sum + (row.deducted ?? 0)) *
              100)
          .round() /
      100.0;
  double get estimatedTotal =>
      (rows
                  .where((r) => !r.snapshot)
                  .fold(0.0, (sum, row) => sum + (row.deducted ?? 0)) *
              100)
          .round() /
      100.0;
  int get reviewCount => rows.where((r) => r.needsReview).length;

  static double? _amount(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return null;
    final number = double.tryParse('$value');
    return number != null && number.isFinite && number >= 0 ? number : null;
  }

  static AttendanceAllowanceReport build(
      {required DateTime month,
      required List<Map<String, dynamic>> employees,
      required List<Map<String, dynamic>> payroll,
      required List<Map<String, dynamic>> defaults,
      required Map<String, List<AttendanceAllowanceReason>> reasons,
      required Map<String, String> branches,
      String? branchId}) {
    String id(dynamic value) => PayrollMonthScope.employeeId(value);
    final eligible = PayrollMonthScope.employeesWithPayroll(
        employees: employees, payroll: payroll, month: month);
    final defaultById = {
      for (final row in defaults) id(row['employee_id']): row
    };
    final rows = <AttendanceAllowanceDeduction>[];
    for (final employee in eligible) {
      final employeeId = id(employee['employee_id']);
      final causes = reasons[employeeId];
      if (causes == null || causes.isEmpty) continue;
      final branch = id(employee['payroll_branch_id']).isNotEmpty
          ? id(employee['payroll_branch_id'])
          : id(employee['branch_id']);
      if (branchId != null && branch != id(branchId)) continue;
      final records = payroll
          .where((row) =>
              id(row['employee_id']) == employeeId &&
              PayrollMonthScope.matchesMonth(row['period'], month))
          .toList();
      final unique = records.length == 1;
      final record = unique ? records.single : <String, dynamic>{};
      final savedBaseline = _amount(record['attendance_allowance_default']);
      final baseline = savedBaseline ??
          _amount(defaultById[employeeId]?['elaun_kedatangan']);
      if (baseline == 0) continue; // No allowance entitlement to remove.
      final paid = unique ? _amount(record['elaun_kedatangan']) : null;
      final deducted = baseline != null && paid != null
          ? ((baseline - paid).clamp(0, baseline) * 100).round() / 100.0
          : null;
      final status = !unique
          ? 'Duplicate payroll — review'
          : baseline == null || paid == null
              ? 'Missing amounts — review'
              : paid == 0
                  ? 'Fully deducted'
                  : paid < baseline
                      ? 'Partially deducted — review'
                      : 'Not deducted — review';
      rows.add(AttendanceAllowanceDeduction(
        employeeId: employeeId,
        name: '${employee['name'] ?? employeeId}',
        branch: branches[branch] ?? branch,
        reasons: causes,
        baseline: baseline,
        paid: paid,
        deducted: deducted,
        snapshot: savedBaseline != null,
        status: status,
      ));
    }
    rows.sort((a, b) {
      final branch = a.branch.compareTo(b.branch);
      return branch != 0 ? branch : a.name.compareTo(b.name);
    });
    return AttendanceAllowanceReport(
        month: month,
        rows: rows,
        branchName: branchId == null
            ? 'All branches'
            : branches[id(branchId)] ?? branchId);
  }
}
