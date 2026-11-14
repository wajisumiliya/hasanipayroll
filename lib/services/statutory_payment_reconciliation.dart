/// Only foreign staff without an EPF number are excluded from EPF payment.
/// Local staff remain payable even when their EPF number is missing.
bool excludeMissingEpfFromPayment(Map<String, dynamic> employee) {
  final foreign =
      employee['address']?.toString().toUpperCase().contains('FRN') == true;
  if (!foreign) return false;

  return !const ['epf_no', 'epfNo', 'kwsp_no', 'kwspNo'].any((key) {
    final value = employee[key]?.toString().trim() ?? '';
    return value.isNotEmpty &&
        !{'-', 'N/A', 'NA', 'NULL', '0'}.contains(value.toUpperCase());
  });
}
