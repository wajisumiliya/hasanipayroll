/// Centralized pure payroll calculations.
///
/// Historical foreign-worker records can contain the same salary in both
/// basic_salary and fw_salary. [salaryBase] deliberately chooses one salary
/// source so those records are never double counted.
class PayrollCalculationService {
  static const Set<String> _overtimeExcludedEmployeeIds = {'HED1016'};

  /// Employees in this exception list cannot calculate, approve, display, or
  /// receive overtime, including OT values saved before the exception existed.
  static bool isEmployeeOvertimeEligible(String employeeId) =>
      !_overtimeExcludedEmployeeIds.contains(employeeId.trim().toUpperCase());

  const PayrollCalculationService._();

  static double salaryBase({
    required double basicSalary,
    required double fwSalary,
  }) {
    if (fwSalary != 0) return fwSalary;
    return basicSalary;
  }

  /// Daily rate used only for explicit UNPAID attendance days.
  /// The divisor is the actual number of calendar days in the payroll month.
  static double unpaidDailyRate({
    required double basicSalary,
    required DateTime month,
  }) {
    if (basicSalary <= 0) return 0;
    final calendarDays = DateTime(month.year, month.month + 1, 0).day;
    return basicSalary / calendarDays;
  }

  /// Existing normal-day rate used for short-hours/late deductions.
  /// This remains separate from the calendar-day UNPAID leave rule.
  static double shortageDailyRate({
    required double basicSalary,
    required bool isForeignEmployee,
  }) {
    if (basicSalary <= 0) return 0;
    return basicSalary / (isForeignEmployee ? 28.0 : 26.0);
  }

  /// Public-holiday pay for days actually worked.
  ///
  /// The payroll rule is basic salary / 26 for each approved PH day.
  static double publicHolidayPay({
    required double basicSalary,
    required int workedDays,
  }) {
    if (basicSalary <= 0 || workedDays <= 0) return 0;
    return _roundMoney((basicSalary / 26) * workedDays);
  }

  /// Public-holiday addition for one attendance day.
  ///
  /// PH     + worked time = daily rate x 1
  /// PH-OFF               = no additional pay
  /// PH-SPL + worked time = daily rate x 2
  /// PH-GUNTI + worked    = replacement OFF only; no additional PH pay
  static double publicHolidayPayForStatus({
    required double basicSalary,
    required String status,
    required bool worked,
  }) {
    if (basicSalary <= 0) return 0;

    final multiplier = switch (status.trim().toUpperCase()) {
      'PH' when worked => 1.0,
      'PH-SPL' when worked => 2.0,
      _ => 0.0,
    };
    return _roundMoney((basicSalary / 26) * multiplier);
  }

  /// Replacement OFF entitlement granted by one attendance day.
  static int replacementOffDaysForStatus({
    required String status,
    required bool worked,
  }) =>
      status.trim().toUpperCase() == 'PH-GUNTI' && worked ? 1 : 0;

  /// Payable overtime comes only from Admin-approved minutes.
  static double approvedOvertimeHours(int? approvedMinutes) {
    if (approvedMinutes == null || approvedMinutes <= 0) return 0;
    return approvedMinutes / 60.0;
  }

  /// Converts a direct Admin OT-hours entry to payable approved minutes.
  /// Blank input clears OT; valid values range from 0 through 24 hours.
  static int? directOvertimeMinutes(String value) {
    final text = value.trim();
    if (text.isEmpty) return 0;
    final hoursAndMinutes = RegExp(r'^(\d{1,2})[.:](\d{2})$').firstMatch(text);
    if (hoursAndMinutes != null) {
      final hours = int.parse(hoursAndMinutes.group(1)!);
      final minutes = int.parse(hoursAndMinutes.group(2)!);
      if (hours > 24 || minutes > 59 || (hours == 24 && minutes > 0)) {
        return null;
      }
      return hours * 60 + minutes;
    }
    final hours = double.tryParse(text);
    if (hours == null || !hours.isFinite || hours < 0 || hours > 24) {
      return null;
    }
    return (hours * 60).round();
  }

  /// Automatic attendance OT for local staff.
  ///
  /// Break usage up to [allocatedBreakMinutes] is neutral: it neither reduces
  /// OT nor becomes extra OT when unused. Only excess break time reduces OT.
  static int automaticLocalOvertimeMinutes({
    required bool isLocalStaff,
    required int workMinutes,
    required int actualBreakMinutes,
    required int allocatedShiftMinutes,
    required int allocatedBreakMinutes,
  }) {
    if (!isLocalStaff || workMinutes <= 0 || allocatedShiftMinutes <= 0) {
      return 0;
    }
    final excessBreakMinutes =
        (actualBreakMinutes - allocatedBreakMinutes).clamp(0, 24 * 60);
    final overtimeMinutes =
        (workMinutes - allocatedShiftMinutes - excessBreakMinutes)
            .clamp(0, 24 * 60)
            .toInt();
    return eligibleOvertimeMinutes(overtimeMinutes);
  }

  /// OT shorter than 30 minutes is not eligible or displayed.
  static int eligibleOvertimeMinutes(int minutes) =>
      minutes >= 30 ? minutes : 0;

  /// A day's OT is payable only when its calculated value exceeds RM5.00.
  static bool isPayableOvertimeAmount(double amount) =>
      amount.isFinite && amount > 5.0;

  /// Prevents a normal late/shortage deduction on UNPAID or PH rows.
  static bool shouldApplyShortageDeduction({
    required bool isUnpaid,
    required bool isPublicHoliday,
    required bool worked,
    bool isForeignEmployee = false,
    String employeeId = '',
  }) {
    // HED1007 is deducted only for explicitly marked UNPAID days. Normal
    // attendance shortages, including Early Out, are not deductible.
    if (employeeId.trim().toUpperCase() == 'HED1007') return false;
    return !isForeignEmployee && !isUnpaid && !isPublicHoliday && worked;
  }

  static double grossEarnings({
    required double basicSalary,
    required double fwSalary,
    double elaunKedatangan = 0,
    double elaunPerkhidmatan = 0,
    double elaunKerajinan = 0,
    double elaunMakanan = 0,
    double overtime = 0,
    double bonus = 0,
    double commission = 0,
    double otherEarnings = 0,
    double housingAllowance = 0,
    double travelAllowance = 0,
    double cutiUmum = 0,
  }) {
    return salaryBase(basicSalary: basicSalary, fwSalary: fwSalary) +
        elaunKedatangan +
        elaunPerkhidmatan +
        elaunKerajinan +
        elaunMakanan +
        overtime +
        bonus +
        commission +
        otherEarnings +
        housingAllowance +
        travelAllowance +
        cutiUmum;
  }

  static double totalDeductions({
    double epfEmployee = 0,
    double socsoEmployee = 0,
    double eisEmployee = 0,
    double pcb = 0,
    double zakat = 0,
    double advance = 0,
    double loan = 0,
    double unpaid = 0,
    double late = 0,
    double other = 0,
  }) {
    return epfEmployee +
        socsoEmployee +
        eisEmployee +
        pcb +
        zakat +
        advance +
        loan +
        unpaid +
        late +
        other;
  }

  /// Finds the latest genuine allowance increment.
  ///
  /// Temporary vacation/unpaid/re-entry reductions are ignored when choosing
  /// the employee's normal allowance baseline. After the employee returns, a
  /// genuine increase is compared with the last normal pre-vacation amount.
  ///
  /// If increases happen in consecutive months, only the latest month's
  /// incremental change is returned. Example: 100 -> 150 in August -> 200 in
  /// September returns September +50, not August +50 + September +50.
  static ({DateTime period, double amount})? latestStableAllowanceIncrement(
    List<({DateTime period, double amount})> history, {
    int stableMonths = 3,
    int lookbackMonths = 6,
  }) {
    bool sameAmount(double a, double b) => (a - b).abs() <= 0.004;
    int monthKey(DateTime value) => value.year * 12 + value.month;

    final byMonth = <int, ({DateTime period, double amount})>{};
    for (final entry in history) {
      if (!entry.amount.isFinite || entry.amount < 0) continue;
      final period = DateTime(entry.period.year, entry.period.month);
      byMonth[monthKey(period)] = (period: period, amount: entry.amount);
    }
    final months = byMonth.values.toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    if (months.length < 2) return null;

    // Track the last normal/high amount. Lower months do not reset it because
    // they can represent vacation, unpaid leave or re-entry. A later amount
    // above this baseline is therefore still detected immediately.
    var baseline = months.first.amount;
    ({DateTime period, double amount})? latest;
    for (var index = 1; index < months.length; index++) {
      final current = months[index];
      if (current.amount > baseline + 0.004) {
        latest = (
          period: current.period,
          amount: _roundMoney(current.amount - baseline),
        );
        // Important: advance the baseline after every genuine increase. This
        // makes consecutive August/September increases report September only.
        baseline = current.amount;
      } else if (sameAmount(current.amount, baseline)) {
        baseline = current.amount;
      }
    }
    return latest;
  }

  /// Applies the genuine-increase rule to each increment-eligible allowance
  /// separately. This prevents a temporary reduction in one allowance from
  /// hiding or changing a genuine increase in the other allowance.
  static ({
    DateTime period,
    double attendanceDifference,
    double serviceDifference,
    double amount,
  })? latestStablePayrollAllowanceIncrement(
    List<
            ({
              DateTime period,
              double attendanceAllowance,
              double serviceAllowance,
            })>
        history, {
    int stableMonths = 3,
    int lookbackMonths = 6,
  }) {
    // Treat Attendance + Service as one increment value. Otherwise an older
    // increase from one allowance can be counted again in a later month.
    final totalIncrement = latestStableAllowanceIncrement(
      history
          .map(
            (entry) => (
              period: entry.period,
              amount: entry.attendanceAllowance + entry.serviceAllowance,
            ),
          )
          .toList(),
      stableMonths: stableMonths,
      lookbackMonths: lookbackMonths,
    );
    if (totalIncrement == null) return null;

    int monthKey(DateTime value) => value.year * 12 + value.month;
    final byMonth = <int, ({
      DateTime period,
      double attendanceAllowance,
      double serviceAllowance,
    })>{};
    for (final entry in history) {
      byMonth[monthKey(entry.period)] = entry;
    }
    final months = byMonth.values.toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    final currentIndex = months.indexWhere(
      (entry) =>
          entry.period.year == totalIncrement.period.year &&
          entry.period.month == totalIncrement.period.month,
    );

    var attendanceDifference = 0.0;
    var serviceDifference = 0.0;
    if (currentIndex > 0) {
      final current = months[currentIndex];
      final previous = months[currentIndex - 1];
      attendanceDifference = _roundMoney(
        (current.attendanceAllowance - previous.attendanceAllowance)
            .clamp(0.0, double.infinity),
      );
      serviceDifference = _roundMoney(
        (current.serviceAllowance - previous.serviceAllowance)
            .clamp(0.0, double.infinity),
      );
    }

    return (
      period: totalIncrement.period,
      attendanceDifference: attendanceDifference,
      serviceDifference: serviceDifference,
      amount: totalIncrement.amount,
    );
  }

  /// Applies the payroll rule for the final monthly late deduction.
  ///
  /// Totals below RM10 are waived. Chargeable totals are rounded to the
  /// nearest ten sen (for example, RM130.77 becomes RM130.80).
  static double payableLateDeduction(double amount) {
    if (!amount.isFinite || amount < 10) return 0;
    return roundPayrollAmount(amount);
  }

  /// Rounds payroll earnings to the nearest ten sen.
  static double roundPayrollAmount(double amount) {
    if (!amount.isFinite) return 0;
    return (amount * 10).roundToDouble() / 10;
  }

  static double _roundMoney(double value) =>
      (value * 100).roundToDouble() / 100;

  static double netPay({
    required double gross,
    required double deductions,
  }) =>
      gross - deductions;
}
