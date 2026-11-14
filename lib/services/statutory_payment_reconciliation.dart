/// Only foreign staff without an EPF number are excluded from EPF payment.
/// Local staff remain payable even when their EPF number is missing.
bool excludeMissingEpfFromPayment(Map<String, dynamic> employee) {
  return _excludeMissingForeignNumber(
      employee, const ['epf_no', 'epfNo', 'kwsp_no', 'kwspNo']);
}

/// SOCSO and EIS use the SOCSO number; local staff remain payable by default.
bool excludeMissingSocsoFromPayment(Map<String, dynamic> employee) {
  return _excludeMissingForeignNumber(
      employee, const ['socso_no', 'socsoNo', 'socso_number', 'SOCSO_NO']);
}

bool _excludeMissingForeignNumber(
    Map<String, dynamic> employee, List<String> keys) {
  final foreign =
      employee['address']?.toString().toUpperCase().contains('FRN') == true;
  if (!foreign) return false;

  return !keys.any((key) {
    final value = employee[key]?.toString().trim() ?? '';
    return value.isNotEmpty &&
        !{'-', 'N/A', 'NA', 'NULL', '0'}.contains(value.toUpperCase());
  });
}

const statutoryEmployeeCountKeys = [
  'epfEmployees',
  'excludedEpfEmployees',
  'socsoEmployees',
  'excludedSocsoEmployees',
  'eisEmployees',
  'excludedEisEmployees',
];

/// Count each contributing payroll employee once, including employer-only rows.
/// Zero-contribution employees do not inflate the statutory employee count.
void countStatutoryEmployee(Map<String, dynamic> summary, String contribution,
    double amount, bool excluded) {
  if (amount <= 0) return;
  final key = '${contribution}Employees';
  summary[key] = ((summary[key] as num?) ?? 0).toInt() + 1;
  if (excluded) {
    final excludedKey =
        'excluded${contribution[0].toUpperCase()}${contribution.substring(1)}Employees';
    summary[excludedKey] = ((summary[excludedKey] as num?) ?? 0).toInt() + 1;
  }
}

String statutoryAmountWithEmployees(double amount, int employees) =>
    '${amount.toStringAsFixed(2)} / $employees emp';
