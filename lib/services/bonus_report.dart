import 'payroll_month_scope.dart';

class BonusRecipient {
  const BonusRecipient({required this.employeeId, required this.name,
    required this.branch, required this.amount, required this.reason});
  final String employeeId, name, branch, reason;
  final double amount;
}

class BonusReport {
  const BonusReport({required this.month, required this.branchName,
    required this.rows});
  final DateTime month;
  final String branchName;
  final List<BonusRecipient> rows;
  double get total => rows.fold<int>(0,
      (sum, row) => sum + (row.amount * 100).round()) / 100;

  static BonusReport build({required DateTime month,
    required List<Map<String, dynamic>> employees,
    required List<Map<String, dynamic>> payroll,
    required Map<String, String> branches, String? branchId}) {
    String id(dynamic value) => PayrollMonthScope.employeeId(value);
    final monthly = payroll.where((row) =>
        PayrollMonthScope.matchesMonth(row['period'], month)).toList();
    final eligible = PayrollMonthScope.employeesWithPayroll(
        employees: employees, payroll: monthly, month: month);
    final rows = <BonusRecipient>[];
    for (final employee in eligible) {
      final employeeId = id(employee['employee_id']);
      final branch = id(employee['payroll_branch_id']).isEmpty
          ? id(employee['branch_id']) : id(employee['payroll_branch_id']);
      if (branchId != null && branch != id(branchId)) continue;
      final records = monthly.where((row) => id(row['employee_id']) == employeeId).toList();
      if (records.length != 1) {
        throw StateError('Duplicate payroll for $employeeId. Resolve it before exporting bonuses.');
      }
      final record = records.single;
      final amount = double.tryParse('${record['bonus'] ?? 0}');
      if (amount == null || !amount.isFinite) {
        throw StateError('Invalid bonus amount for $employeeId.');
      }
      if (amount <= 0) continue;
      final days = int.tryParse(RegExp(r'Local unused OFF bonus days:\s*(\d+);')
          .firstMatch('${record['remarks'] ?? ''}')?.group(1) ?? '') ?? 0;
      rows.add(BonusRecipient(employeeId: employeeId,
        name: '${employee['name'] ?? employeeId}', branch: branches[branch] ?? branch,
        amount: (amount * 100).round() / 100,
        reason: days > 0
            ? 'Unused fifth OFF bonus ($days day) - saved payroll note'
            : 'Bonus recorded in payroll; reason not recorded',
      ));
    }
    rows.sort((a, b) {
      final branch = a.branch.compareTo(b.branch);
      return branch != 0 ? branch : a.name.compareTo(b.name);
    });
    return BonusReport(month: month,
      branchName: branchId == null ? 'All branches' : branches[id(branchId)] ?? branchId,
      rows: rows);
  }
}
