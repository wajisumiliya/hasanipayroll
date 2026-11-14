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
