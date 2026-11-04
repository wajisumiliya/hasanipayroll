import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../services/bonus_report.dart';
import '../services/bonus_report_export.dart';

class BonusReportDialog extends StatefulWidget {
  const BonusReportDialog(
      {super.key, required this.initialMonth, required this.load});
  final DateTime initialMonth;
  final Future<BonusReport> Function(DateTime month) load;
  @override
  State<BonusReportDialog> createState() => _BonusReportDialogState();
}

class _BonusReportDialogState extends State<BonusReportDialog> {
  late DateTime month = widget.initialMonth;
  BonusReport? report;
  bool loading = true, exporting = false;
  String? error;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final request = ++revision;
    setState(() {
      loading = true;
      error = null;
      report = null;
    });
    try {
      final result = await widget.load(month);
      if (!mounted || request != revision) return;
      setState(() => report = result);
    } catch (e) {
      if (!mounted || request != revision) return;
      setState(() => error = 'Unable to load bonus recipients: $e');
    } finally {
      if (mounted && request == revision) setState(() => loading = false);
    }
  }

  List<BonusRecipient> get visibleRows => report?.rows ?? [];

  Future<void> export(bool pdf) async {
    final data = report;
    if (data == null || exporting) return;
    setState(() {
      exporting = true;
      error = null;
    });
    try {
      final name = 'Bonus_Recipients_${DateFormat('yyyy_MM').format(month)}';
      if (pdf) {
        final bytes = await BonusReportExport.pdf(data, visibleRows);
        await Printing.layoutPdf(
            name: '$name.pdf',
            dynamicLayout: false,
            onLayout: (_) async => bytes);
      } else {
        await FileSaver.instance.saveFile(
            name: name,
            bytes: BonusReportExport.excel(data, visibleRows),
            ext: 'xlsx',
            mimeType: MimeType.microsoftExcel);
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to export report: $e');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String money(double? amount) =>
        amount == null ? 'Not available' : amount.toStringAsFixed(2);
    return Dialog(
        child: SizedBox(
      width: 1200,
      height: MediaQuery.sizeOf(context).height * .85,
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bonus Recipients Report',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: [
                OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(DateFormat('MMMM yyyy').format(month)),
                    onPressed: loading || exporting
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                                context: context,
                                initialDate: month,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100));
                            if (picked == null || !mounted) return;
                            month = DateTime(picked.year, picked.month);
                            await reload();
                          }),
                OutlinedButton.icon(
                    onPressed: loading || exporting ? null : reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh')),
                if (report != null) Text(report!.branchName),
              ]),
              const SizedBox(height: 8),
              const Text(BonusReportExport.note,
                  style: TextStyle(fontSize: 12)),
              if (report != null) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 20, runSpacing: 8, children: [
                  Text('Recipients: ${report!.rows.length}'),
                  Text('Total bonus: RM ${money(report!.total)}'),
                ]),
              ],
              if (error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.red))),
              Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : report == null
                          ? const Center(
                              child: Text(
                                  'Report unavailable. Use Refresh to retry.'))
                          : visibleRows.isEmpty
                              ? const Center(
                                  child: Text(
                                      'No employees have a saved bonus for this month and branch.'))
                              : SingleChildScrollView(
                                  child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: BonusReportExport.headers
                                            .map((label) =>
                                                DataColumn(label: Text(label)))
                                            .toList(),
                                        dataRowMinHeight: 48,
                                        dataRowMaxHeight: 160,
                                        rows: visibleRows
                                            .map((row) => DataRow(cells: [
                                                  for (final value
                                                      in BonusReportExport.values(
                                                          row, month))
                                                    DataCell(SizedBox(
                                                        width:
                                                            value == row.reason
                                                                ? 260
                                                                : 150,
                                                        child: SingleChildScrollView(
                                                            child: Text(value
                                                                    is num
                                                                ? value
                                                                    .toStringAsFixed(
                                                                        2)
                                                                : value?.toString() ??
                                                                    'Not available')))),
                                                ]))
                                            .toList(),
                                      )))),
              const SizedBox(height: 12),
              Wrap(spacing: 12, children: [
                OutlinedButton.icon(
                    onPressed: loading || exporting || visibleRows.isEmpty
                        ? null
                        : () => export(true),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Print / Save PDF')),
                OutlinedButton.icon(
                    onPressed: loading || exporting || visibleRows.isEmpty
                        ? null
                        : () => export(false),
                    icon: const Icon(Icons.table_view),
                    label: const Text('Export Excel')),
                TextButton(
                    onPressed: exporting ? null : () => Navigator.pop(context),
                    child: const Text('Close')),
              ]),
            ],
          )),
    ));
  }
}
