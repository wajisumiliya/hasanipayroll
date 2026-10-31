import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../services/app_service.dart';

class IncrementReportButton extends StatefulWidget {
  const IncrementReportButton(
      {super.key,
      required this.month,
      required this.branch,
      required this.comparison,
      this.pdfLoader,
      this.printAction});
  final DateTime month;
  final String? branch;
  final bool comparison;
  final Future<Uint8List> Function()? pdfLoader;
  final Future<void> Function(Uint8List)? printAction;
  @override
  State<IncrementReportButton> createState() => _IncrementReportButtonState();
}

class _IncrementReportButtonState extends State<IncrementReportButton> {
  bool busy = false;
  Future<void> printReport() async {
    final month = widget.month, branch = widget.branch;
    final comparison = widget.comparison;
    final loader = widget.pdfLoader, printer = widget.printAction;
    setState(() => busy = true);
    try {
      final bytes = loader != null
          ? await loader()
          : await AppService.instance.loadIncrementReportPdf(
              month: month, comparison: comparison, branchId: branch);
      if (!mounted) return;
      if (printer != null) {
        await printer(bytes);
      } else {
        await Printing.layoutPdf(
            name:
                'increment_${comparison ? 'comparison' : 'eligible'}_${DateFormat('yyyy_MM').format(month)}.pdf',
            dynamicLayout: false,
            onLayout: (_) async => bytes);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Unable to print increment report: $error')));
      }
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
                widget.comparison
                    ? Icons.fact_check_outlined
                    : Icons.print_outlined,
                size: 18),
        label: Text(busy
            ? 'Preparing PDF…'
            : widget.comparison
                ? 'Payroll Comparison PDF'
                : 'Eligible List PDF'),
      );
}
