/// Shared attendance time rules. Durations are always minutes, not decimals.
class AttendanceWorkingRules {
  static bool isForeign(dynamic employeeAddress, [dynamic salaryAddress]) {
    final marker =
        '${employeeAddress ?? ''} ${salaryAddress ?? ''}'.toUpperCase();
    return marker.contains('FRN') || marker.contains('FOREIGN');
  }

  static int breakMinutes(
      {required bool isForeignEmployee,
      required int workMinutes,
      required int actualMinutes,
      required String status}) {
    final paidAbsence =
        const {'MC', 'AL', 'PH-OFF'}.contains(status.trim().toUpperCase());
    if (isForeignEmployee &&
        workMinutes > 0 &&
        !paidAbsence &&
        actualMinutes < 60) {
      return 90;
    }
    return actualMinutes;
  }

  static int monthlyTarget(
      {required String employeeId,
      required DateTime month,
      required int offDays,
      required bool isForeignEmployee}) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    if (employeeId.trim().toUpperCase() == 'HED2016') {
      if (days == 31) return 304 * 60 + 30;
      if (days == 30) return 294 * 60;
    }
    if (isForeignEmployee && offDays == 2 && (days == 30 || days == 31)) {
      return 288 * 60 + 40;
    }
    return (days - offDays).clamp(0, days) * (isForeignEmployee ? 630 : 450);
  }
}
