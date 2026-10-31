/// inc_details records the last award, not a future increment schedule.
class IncrementEligibilityService {
  static ({DateTime lastMonth, DateTime dueMonth, double? lastAmount})?
      dueForMonth(dynamic value, DateTime selectedMonth) {
    final text = '${value ?? ''}'.trim().toUpperCase();
    final match =
        RegExp(r'^([A-Z]{3,4})[-/](\d{4}|\d{2})(?:\D|$)').firstMatch(text);
    const months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'SEPT': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12
    };
    if (match == null || months[match[1]] == null) return null;
    var year = int.parse(match[2]!);
    if (year < 100) year += 2000;
    final last = DateTime(year, months[match[1]]!);
    final due = DateTime(last.year, last.month + 6);
    if (due != DateTime(selectedMonth.year, selectedMonth.month)) {
      return null;
    }
    final separator = text.lastIndexOf('/');
    final amount = separator < 0
        ? null
        : double.tryParse(text.substring(separator + 1).trim());
    return (
      lastMonth: last,
      dueMonth: due,
      lastAmount:
          amount != null && amount.isFinite && amount >= 0 ? amount : null
    );
  }
}
