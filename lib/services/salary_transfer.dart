/// Salary payment routing shared by employee information and payroll exports.
class SalaryTransfer {
  static const methods = ['rhb', 'instant', 'cash'];

  static String resolve(dynamic method, dynamic bankAccount) {
    final saved = (method ?? '').toString().trim().toLowerCase();
    if (methods.contains(saved)) {
      if (saved == 'rhb' && (bankAccount ?? '').toString().trim().isEmpty) {
        return '';
      }
      return saved;
    }
    return (bankAccount ?? '').toString().trim().isEmpty ? '' : 'rhb';
  }

  static String footerKey(dynamic method, dynamic bankAccount) {
    final resolved = resolve(method, bankAccount);
    return resolved == 'rhb' ? 'payroll' : resolved;
  }

  static String label(String method) => switch (method) {
        'rhb' => 'RHB',
        'instant' => 'Instant',
        'cash' => 'Cash',
        _ => 'Not selected',
      };
}

/// Tracks the exact net-salary cells contributing to each payment footer.
class SalaryTransferSummary {
  final totals = <String, double>{'payroll': 0, 'instant': 0, 'cash': 0};
  final rows = <String, List<int>>{'payroll': [], 'instant': [], 'cash': []};

  bool get hasUnassigned => rows['unassigned']?.isNotEmpty ?? false;

  void add({
    required dynamic method,
    required dynamic bankAccount,
    required double net,
    required int row,
    required String employeeId,
  }) {
    final resolvedKey = SalaryTransfer.footerKey(method, bankAccount);
    // A missing payment choice must not prevent exporting saved payroll or
    // silently assign the salary to a payment method the employee did not select.
    final key = resolvedKey.isEmpty ? 'unassigned' : resolvedKey;
    totals[key] = (totals[key] ?? 0) + net;
    rows.putIfAbsent(key, () => <int>[]).add(row);
  }

  String? formula(String key, String netColumn) {
    final contributors = rows[key] ?? const <int>[];
    if (contributors.isEmpty) return null;
    return 'SUM(${contributors.map((row) => '$netColumn$row').join(',')})';
  }
}
