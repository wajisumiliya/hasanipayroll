import 'package:intl/intl.dart';

String lateReviewStatus(dynamic value) => switch (value) {
      'noted' => 'Reviewed',
      'approved' => 'Approved',
      'correction_required' => 'Correction required',
      _ => 'Pending',
    };
String lateReasonLabel(dynamic value) => switch (value) {
      'transport' => 'Transport delay',
      'approved_late' => 'Approved late arrival / break',
      'attendance_error' => 'Incorrect attendance',
      _ => 'Other',
    };
String lateSeverityLabel(int count) => count >= 7
    ? 'High'
    : count >= 5
        ? 'Medium'
        : 'Low';
String lateLocalReviewTime(dynamic value) {
  final time = DateTime.tryParse('$value');
  return time == null
      ? '-'
      : '${DateFormat('dd MMM yyyy HH:mm').format(time.toUtc().add(const Duration(hours: 8)))} MYT';
}

// Small report metadata for the export UI; file generation runs on the server.
class LateReportExportData {
  const LateReportExportData(
      {required this.month,
      required this.branchId,
      required this.branchLabel,
      required this.reports});
  final DateTime month;
  final String? branchId;
  final String branchLabel;
  final List<Map<String, dynamic>> reports;
}
