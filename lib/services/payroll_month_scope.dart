/// Eligibility for viewing existing payroll in a selected calendar month.
/// This does not filter the employee master list or payroll-generation inputs.
class PayrollMonthScope {
  static String employeeId(dynamic value) =>
      (value ?? '').toString().trim().toUpperCase();

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value.toString().trim());
    if (parsed == null) return null;
    // Employment timestamps come from PostgreSQL in UTC; payroll is Malaysian.
    final local = parsed.isUtc ? parsed.add(const Duration(hours: 8)) : parsed;
    return DateTime(local.year, local.month, local.day);
  }

  static bool activeInMonth(Map<String, dynamic> employee, DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final joined = _date(employee['joining_date'] ?? employee['joiningDate']);
    if (joined != null && !joined.isBefore(end)) return false;
    final resigned = _date(employee['resigned_at'] ?? employee['resignedAt']);
    if (resigned != null) return !resigned.isBefore(start);
    final active = employee['is_active'] ?? employee['isActive'];
    return active == true || active?.toString().toLowerCase() == 'true';
  }

  static bool matchesMonth(dynamic value, DateTime month) {
    if (value == null) return false;

    final text = value.toString().trim();
    if (text.isEmpty) return false;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed.year == month.year && parsed.month == month.month;
    }

    final normalized = text.toLowerCase();
    final monthNames = const [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];

    for (var i = 0; i < monthNames.length; i++) {
      if (normalized.contains(monthNames[i]) &&
          normalized.contains(month.year.toString())) {
        return i + 1 == month.month;
      }
    }

    final yearMonth = RegExp(r'^(\d{4})[-/]([0-9]{1,2})$').firstMatch(text);
    if (yearMonth != null) {
      return int.tryParse(yearMonth.group(1) ?? '') == month.year &&
          int.tryParse(yearMonth.group(2) ?? '') == month.month;
    }

    final monthYear = RegExp(r'^([0-9]{1,2})[-/](\d{4})$').firstMatch(text);
    if (monthYear != null) {
      return int.tryParse(monthYear.group(1) ?? '') == month.month &&
          int.tryParse(monthYear.group(2) ?? '') == month.year;
    }

    return false;
  }

  static Set<String> employeeIdsWithPayroll(
    Iterable<Map<String, dynamic>> payroll,
    DateTime month,
  ) {
    return payroll
        .where((row) => matchesMonth(row['period'], month))
        .map((row) => employeeId(row['employee_id'] ?? row['employeeId']))
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static List<Map<String, dynamic>> employeesWithPayroll({
    required Iterable<Map<String, dynamic>> employees,
    required Iterable<Map<String, dynamic>> payroll,
    required DateTime month,
  }) {
    final ids = employeeIdsWithPayroll(payroll, month);
    return employees.where((employee) {
      final id = employeeId(employee['employee_id'] ?? employee['employeeId']);
      return ids.contains(id) && activeInMonth(employee, month);
    }).toList();
  }
}
