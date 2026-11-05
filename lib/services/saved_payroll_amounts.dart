import 'payroll_calculation_service.dart';

/// Financial snapshot from a saved payroll row, never from current defaults.
/// Aliases are alternatives, not additional earnings/deductions.
class SavedPayrollAmounts {
  const SavedPayrollAmounts({
    required this.gross,
    required this.deductions,
    required this.unroundedNet,
  });

  final double gross, deductions, unroundedNet;
  double get net => PayrollCalculationService.roundNetPay(unroundedNet);

  /// The Branch Payroll payment rule for every final-net-pay report.
  /// Consumers must not apply another earnings/component rounding afterwards.
  static double finalNetPay(Map<String, dynamic> row) =>
      SavedPayrollAmounts.fromRow(row).net;

  static const _grossKeys = [
    'gross_salary',
    'gross_pay',
    'total_gross',
    'grossSalary',
    'grossPay',
    'jumlah',
    'total_earnings',
    'totalEarnings',
  ];
  static const _deductionKeys = ['total_deductions', 'totalDeductions'];
  static const _netKeys = [
    'net_pay',
    'net_salary',
    'total_net',
    'netPay',
    'netSalary',
    'net',
  ];

  static double? _optional(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final raw = row[key];
      if (raw == null || '$raw'.trim().isEmpty) continue;
      final value = raw is num
          ? raw.toDouble()
          : double.tryParse('$raw'
              .trim()
              .replaceAll(',', '')
              .replaceFirst(RegExp(r'^RM\s*', caseSensitive: false), ''));
      if (value == null || !value.isFinite) {
        throw StateError(
            'Invalid saved payroll amount: $key. Review payroll before exporting.');
      }
      return value;
    }
    return null;
  }

  /// Update only existing snapshot columns after a financial edit. Never add
  /// columns to schemas which store components without calculated totals.
  static void refreshExistingTotals(Map<String, dynamic> row) {
    final amounts = SavedPayrollAmounts.fromRow(row, preferStoredTotals: false);
    for (final key in _grossKeys) {
      if (row.containsKey(key)) row[key] = amounts.gross;
    }
    for (final key in _deductionKeys) {
      if (row.containsKey(key)) row[key] = amounts.deductions;
    }
    for (final key in _netKeys) {
      if (row.containsKey(key)) row[key] = amounts.net;
    }
  }

  factory SavedPayrollAmounts.fromRow(Map<String, dynamic> row,
      {bool preferStoredTotals = true}) {
    double amount(List<String> keys) => _optional(row, keys) ?? 0;
    final base = PayrollCalculationService.salaryBase(
      basicSalary: amount(['basic_salary', 'basicSalary']),
      fwSalary: amount(['fw_salary', 'fwSalary']),
    );
    final gross = (preferStoredTotals ? _optional(row, _grossKeys) : null) ??
        base +
            amount(['elaun_kedatangan', 'elaunKedatangan']) +
            amount([
              'elaun_perkhidmatan',
              'elaunPerkhidmatan',
              'other_allowance',
              'otherAllowance'
            ]) +
            amount(['elaun_kerajinan', 'elaunKerajinan']) +
            amount([
              'elaun_makanan',
              'elaunMakanan',
              'food_allowance',
              'foodAllowance'
            ]) +
            amount(['housing_allowance', 'housingAllowance']) +
            amount(['travel_allowance', 'travelAllowance']) +
            amount(['overtime']) +
            amount(['bonus']) +
            amount(['commission']) +
            amount(['other_earnings', 'otherEarnings']) +
            amount(['cuti_umum', 'cutiUmum']);
    final deductions =
        (preferStoredTotals ? _optional(row, _deductionKeys) : null) ??
            amount(['epf_employee', 'epfEmployee']) +
                amount(['socso_employee', 'socsoEmployee']) +
                amount(['eis_employee', 'eisEmployee']) +
                amount(['pcb']) +
                amount(['zakat']) +
                amount(['advance', 'advance_deduction', 'advanceDeduction']) +
                amount(['loan_deduction', 'loanDeduction', 'loan']) +
                amount([
                  'unpaid_deduction',
                  'unpaidDeduction',
                  'unpaid_leave',
                  'unpaidLeave',
                  'cuti_tanpa_gaji',
                  'cuti_tanpa_gaji_deduction'
                ]) +
                amount(['late_deduction', 'lateDeduction']) +
                amount([
                  'other_deduction',
                  'other_deductions',
                  'other_deduction_amount',
                  'otherDeductionAmount',
                  'otherDeduction'
                ]);
    final net = (preferStoredTotals ? _optional(row, _netKeys) : null) ??
        gross - deductions;
    return SavedPayrollAmounts(
        gross: gross, deductions: deductions, unroundedNet: net);
  }
}
