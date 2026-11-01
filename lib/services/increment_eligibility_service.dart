/// inc_details records the last award, not a future increment schedule.
class IncrementEligibilityService {
  static ({DateTime lastMonth, DateTime dueMonth, double? lastAmount})?
      dueForMonth(dynamic value, DateTime selectedMonth,
          {dynamic joiningDate}) {
    final text = '${value ?? ''}'.trim().toUpperCase();
    if (text.isEmpty) {
      final raw = '${joiningDate ?? ''}';
      final parsed =
          joiningDate is DateTime ? joiningDate : DateTime.tryParse(raw);
      if (parsed == null) {
        return null;
      }
      if (joiningDate is! DateTime) {
        final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
        if (iso == null ||
            parsed.year != int.parse(iso[1]!) ||
            parsed.month != int.parse(iso[2]!) ||
            parsed.day != int.parse(iso[3]!)) {
          return null;
        }
      }
      if (parsed.isBefore(DateTime(2026, 1, 1))) {
        return null;
      }
      final last = DateTime(parsed.year, parsed.month);
      final due = DateTime(parsed.year, parsed.month + 6);
      if (due.isAfter(DateTime(selectedMonth.year, selectedMonth.month))) {
        return null;
      }
      return (lastMonth: last, dueMonth: due, lastAmount: null);
    }
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
    final monthsSinceIncrement = (selectedMonth.year - last.year) * 12 +
        selectedMonth.month -
        last.month;
    if (monthsSinceIncrement < 6 || monthsSinceIncrement > 10) {
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
