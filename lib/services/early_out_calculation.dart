/// Shared payroll-only Early Out exemption. This never adds another deduction.
class EarlyOutCalculation {
  static String clock(dynamic value) {
    final text = (value ?? '').toString().trim();
    final match = RegExp(
            r'^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*(AM|PM)?$',
            caseSensitive: false)
        .firstMatch(text);
    if (match == null) return text;
    var hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (minute > 59 || (match[3] != null && int.parse(match[3]!) > 59)) {
      return text;
    }
    if (match[4] != null) {
      if (hour < 1 || hour > 12) return text;
      hour = hour % 12 + (match[4]!.toUpperCase() == 'PM' ? 12 : 0);
    }
    if (hour > 23) return text;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static int exemptMinutes(
      {required Map<String, dynamic> row,
      required int requiredMinutes,
      required int workedMinutes,
      required int shortageMinutes}) {
    final context = row['_early_out'];
    if (context is! Map ||
        context['approval_status'] != 'APPROVED' ||
        context['attendance_date'] !=
            (row['attendance_date'] ?? '').toString().split('T').first ||
        (row['employee_id'] != null &&
            context['employee_id'] != row['employee_id']) ||
        context['required_minutes'] != requiredMinutes ||
        context['worked_minutes'] != workedMinutes ||
        clock(context['check_in']) !=
            clock(row['check_in'] ?? row['working_in']) ||
        clock(context['check_out']) !=
            clock(row['check_out'] ?? row['working_out'])) {
      return 0;
    }
    final approved = (context['approved_minutes'] as num?)?.toInt() ?? 0;
    final eligible = (context['eligible_early_minutes'] as num?)?.toInt() ?? 0;
    return approved.clamp(0, eligible.clamp(0, shortageMinutes)).toInt();
  }

  static bool locked(Map<String, dynamic> payroll) =>
      payroll['is_published'] == true ||
      payroll['is_paid'] == true ||
      payroll['isPaid'] == true ||
      payroll['is_finalized'] == true ||
      payroll['paid_at'] != null ||
      payroll['paidAt'] != null ||
      payroll['finalized_at'] != null ||
      ['paid', 'finalized', 'finalised', 'locked']
          .contains('${payroll['status']}'.toLowerCase());

  static bool preserveManualStatutory(
      Map<String, dynamic>? payroll, String field) {
    if (payroll == null) return false;
    final snapshot = payroll['early_out_snapshot'];
    if (snapshot is! Map ||
        (snapshot['manual_statutory_fields'] as List? ?? []).contains(field)) {
      return true;
    }
    final automatic = snapshot['calculated_statutory_fields'];
    if (automatic is! Map || automatic[field] == null) return true;
    final current = double.tryParse('${payroll[field]}') ?? 0;
    final computed = double.tryParse('${automatic[field]}');
    return computed == null || (current - computed).abs() > .005;
  }

  static bool preserveManualUnpaid(Map<String, dynamic>? payroll) {
    if (payroll == null) return false;
    final snapshot = payroll['early_out_snapshot'];
    if (snapshot is! Map || snapshot['manual_unpaid_preserved'] == true) {
      return true;
    }
    final current = double.tryParse('${payroll['unpaid_deduction']}') ?? 0;
    final calculated =
        double.tryParse('${snapshot['calculated_unpaid_deduction']}');
    return calculated == null || (current - calculated).abs() > .005;
  }

  static bool preserveManual(Map<String, dynamic>? payroll) {
    if (payroll == null) return false;
    final snapshot = payroll['early_out_snapshot'];
    if (snapshot is! Map || snapshot['manual_preserved'] == true) return true;
    final value = double.tryParse('${payroll['late_deduction']}') ?? 0;
    final computed =
        double.tryParse('${snapshot['calculated_late_deduction']}');
    return computed == null || (value - computed).abs() > .005;
  }
}
