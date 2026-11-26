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

class AnnualBenefit {
  const AnnualBenefit(this.date, this.particulars, this.amount,
      {this.exactDate = true});
  final DateTime date;
  final String particulars;
  final double amount;
  final bool exactDate;
  String get dateLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return exactDate
        ? '${two(date.day)}/${two(date.month)}/${date.year}'
        : '${two(date.month)}/${date.year}';
  }
}

class AnnualPayslipSummary {
  AnnualPayslipSummary(
      {required this.employeeId,
      required this.year,
      required List<PayrollRecord> records,
      List<Map<String, dynamic>> welfare = const []}) {
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
    for (final row in welfare) {
      if ('${row['employee_id']}'.trim().toUpperCase() !=
          employeeId.trim().toUpperCase()) {
        continue;
      }
      final date = DateTime.parse('${row['payment_date']}');
      if (date.year != year) continue;
      final amount = double.parse('${row['amount']}');
      if (!amount.isFinite || amount < 0) {
        throw StateError('Invalid welfare amount.');
      }
      benefits.add(AnnualBenefit(date, '${row['particulars']}', amount));
    }
    for (final bonus in bonuses) {
      benefits.add(AnnualBenefit(bonus.period, 'Payroll bonus', bonus.bonus,
          exactDate: false));
    }
    benefits.sort((a, b) => a.date.compareTo(b.date));
    months = List.generate(12,
        (i) => selected[i + 1] ?? AnnualSalaryMonth(i + 1, null, null, null));
  }
  final String employeeId;
  final int year;
  late final List<AnnualSalaryMonth> months;
  final List<PayrollRecord> bonuses = [];
  final List<AnnualBenefit> benefits = [];
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
      'Total is salary plus allowances, before deductions. Welfare, gifts and bonuses are listed separately. '
      'Other earnings and deductions are not part of these columns. Blank months have no saved payroll.';
}
