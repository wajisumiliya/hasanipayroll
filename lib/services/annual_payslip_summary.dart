import '../models/payroll.dart';

class AnnualSalaryMonth {
  const AnnualSalaryMonth(
      this.month, this.salary, this.allowance, this.increment);
  final int month;
  final double? salary, allowance, increment;
  double? get total =>
      salary == null ? null : annualMoney(salary! + allowance!);
}

double annualMoney(double amount) => (amount * 100).round() / 100;

class AnnualPayslipSummary {
  AnnualPayslipSummary(
      {required this.employeeId,
      required this.year,
      required List<PayrollRecord> records}) {
    final history = records
        .where((p) =>
            p.employeeId.trim().toUpperCase() ==
                employeeId.trim().toUpperCase() &&
            p.period.year <= year)
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    final seen = <String>{};
    PayrollRecord? previous;
    final selected = <int, AnnualSalaryMonth>{};
    for (final p in history) {
      final key = '${p.period.year}-${p.period.month}';
      if (!seen.add(key)) {
        throw StateError('Duplicate payroll for $employeeId in $key.');
      }
      final allowance = allowances(p);
      if (p.period.year == year) {
        final increase = previous == null
            ? null
            : annualMoney(p.salaryBase +
                allowance -
                previous.salaryBase -
                allowances(previous));
        selected[p.period.month] = AnnualSalaryMonth(
            p.period.month,
            p.salaryBase,
            allowance,
            increase == null
                ? null
                : increase > 0
                    ? increase
                    : 0);
        if (p.bonus != 0) bonuses.add(p);
      }
      previous = p;
    }
    months = List.generate(12,
        (i) => selected[i + 1] ?? AnnualSalaryMonth(i + 1, null, null, null));
  }
  final String employeeId;
  final int year;
  late final List<AnnualSalaryMonth> months;
  final List<PayrollRecord> bonuses = [];
  static double allowances(PayrollRecord p) =>
      annualMoney(p.totalAllowance + p.housingAllowance + p.travelAllowance);
  static const monthNames = [
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER'
  ];
  static const salaryHeaders = [
    'NO',
    'MONTH',
    'SALARY\n(RM)',
    'ALLOWANCE\n(RM)',
    'INCREMENT\n(RM)',
    'TOTAL AMOUNT\n(RM)'
  ];
  static const bonusHeaders = [
    'NO',
    'DATE',
    'PARTICULAR',
    'TOTAL AMOUNT\n(RM)'
  ];
  static const explanation =
      'Salary is saved basic/FW pay; allowance includes saved allowances. '
      'Increment compares salary plus allowances with the previous saved payroll and is already included in the total. '
      'Total is salary plus allowances, before deductions. Bonuses are listed separately. '
      'Other earnings and deductions are not part of these columns. Blank months have no saved payroll.';
}
