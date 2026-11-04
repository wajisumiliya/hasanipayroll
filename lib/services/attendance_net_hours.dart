/// Paid absence credits are attendance hours, never worked time or overtime.
class AttendanceNetHours {
  static bool isPaidAbsence(String status) =>
      const {'MC', 'AL', 'PH-OFF'}.contains(status.trim().toUpperCase());

  /// A leave-only daily roster may omit times. Use the weekly working shift
  /// before falling back to the employee's default working day.
  static int assignedMinutes({
    Map<String, dynamic>? dailyRoster,
    Map<String, dynamic>? weeklyRoster,
    required int fallbackMinutes,
  }) {
    int? clock(dynamic value) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('$value');
      if (match == null) return null;
      final hour = int.parse(match[1]!);
      final minute = int.parse(match[2]!);
      return hour < 24 && minute < 60 ? hour * 60 + minute : null;
    }

    for (final roster in [dailyRoster, weeklyRoster]) {
      final start = clock(roster?['shift_start']);
      final end = clock(roster?['shift_end']);
      if (start == null || end == null) continue;
      final gross = end > start ? end - start : end - start + 1440;
      final breaks = num.tryParse('${roster?['break_minutes']}')?.round() ?? 0;
      return (gross - breaks.clamp(0, 1440)).clamp(0, 1440).toInt();
    }
    return fallbackMinutes.clamp(0, 1440).toInt();
  }

  static int displayMinutes({
    required String status,
    required int actualMinutes,
    required int assignedMinutes,
  }) =>
      (isPaidAbsence(status) ? assignedMinutes : actualMinutes)
          .clamp(0, 1440)
          .toInt();
}
