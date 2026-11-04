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
    if (isForeignEmployee || employeeId.trim().toUpperCase() == 'HED2016') {
      // Decimal hours confirmed by payroll: 298.70h = 298:42 and
      // 288.40h = 288:24. These are fixed monthly targets, independent of OFFs.
      if (days == 31) return 298 * 60 + 42;
      if (days == 30) return 288 * 60 + 24;
    }
    return (days - offDays).clamp(0, days) * (isForeignEmployee ? 630 : 450);
  }
}
