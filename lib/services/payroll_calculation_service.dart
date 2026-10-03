/// Centralized pure payroll calculations.
///
/// Historical foreign-worker records can contain the same salary in both
/// basic_salary and fw_salary. [salaryBase] deliberately chooses one salary
/// source so those records are never double counted.
class PayrollCalculationService {
  const PayrollCalculationService._();

  static double salaryBase({
    required double basicSalary,
    required double fwSalary,
  }) {
    if (fwSalary != 0) return fwSalary;
    return basicSalary;
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
    final hours = double.tryParse(text);
    if (hours == null || !hours.isFinite || hours < 0 || hours > 24) {
      return null;
    }
    return (hours * 60).round();
  }

  /// Prevents a normal late/shortage deduction on UNPAID or PH rows.
  static bool shouldApplyShortageDeduction({
    required bool isUnpaid,
    required bool isPublicHoliday,
    required bool worked,
    bool isForeignEmployee = false,
  }) =>
      !isForeignEmployee && !isUnpaid && !isPublicHoliday && worked;

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

  static double _roundMoney(double value) =>
      (value * 100).roundToDouble() / 100;

  static double netPay({
    required double gross,
    required double deductions,
  }) =>
      gross - deductions;
}
