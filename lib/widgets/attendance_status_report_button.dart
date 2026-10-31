import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../services/app_service.dart';

class AttendanceStatusReportButton extends StatefulWidget {
  const AttendanceStatusReportButton(
      {super.key,
      required this.month,
      required this.branch,
      required this.status,
      required this.employeeIds,
      this.pdfLoader,
      this.printAction});
  final DateTime month;
  final String? branch;
  final String status;
  final List<String> employeeIds;
  final Future<Uint8List> Function()? pdfLoader;
  final Future<void> Function(Uint8List)? printAction;
  @override
  State<AttendanceStatusReportButton> createState() =>
      _AttendanceStatusReportButtonState();
}

class _AttendanceStatusReportButtonState
    extends State<AttendanceStatusReportButton> {
  bool busy = false;
  Future<void> printReport() async {
    final month = widget.month, status = widget.status, branch = widget.branch;
    final ids = List<String>.from(widget.employeeIds);
    final injectedLoader = widget.pdfLoader, injectedPrint = widget.printAction;
    setState(() => busy = true);
    try {
      final Uint8List bytes;
      if (injectedLoader != null) {
        bytes = await injectedLoader();
      } else {
        final result = await AppService.instance.loadAttendanceStatusReport(
            month: month,
            status: status,
            branchId: branch,
            employeeIds: ids,
            pdf: true);
        bytes = base64Decode(result['file_base64'] as String);
      }
      if (!mounted) return;
      if (injectedPrint != null) {
        await injectedPrint(bytes);
      } else {
        await Printing.layoutPdf(
            name: '${status}_${DateFormat('yyyy_MM').format(month)}.pdf',
            dynamicLayout: false,
            onLayout: (_) async => bytes);
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to print report: $error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: busy ? null : printReport,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              widget.status == 'MC'
                  ? Icons.medical_services_outlined
                  : Icons.event_busy,
              size: 18),
      label: Text(busy
          ? 'Preparing PDF…'
          : widget.status == 'MC'
              ? 'MC Print'
              : 'Unpaid Print'));
}
