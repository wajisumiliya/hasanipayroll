import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class SalaryReportPage extends StatefulWidget {
  const SalaryReportPage({super.key, required this.load, required this.export,
    this.initialStartYear = 2025});
  final Future<Map<String, dynamic>> Function(int startYear) load;
  final Future<Uint8List> Function(int startYear, String format, String? branchId) export;
  final int initialStartYear;
  @override
  State<SalaryReportPage> createState() => _SalaryReportPageState();
}

class _SalaryReportPageState extends State<SalaryReportPage> {
  late int year = widget.initialStartYear;
  Map<String, dynamic>? report;
  String? branchId, error;
  bool loading = true, exporting = false;
  int revision = 0;
  List<Map<String, dynamic>> get branches => (report?['branches'] as List? ?? [])
      .map((row) => Map<String, dynamic>.from(row as Map)).toList();
  List<Map<String, dynamic>> get visibleBranches => branches
      .where((branch) => branchId == null || branch['id'] == branchId).toList();

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final request = ++revision;
    setState(() { loading = true; report = null; error = null; });
    try {
      final result = await widget.load(year);
      if (!mounted || request != revision) return;
      setState(() {
        report = result;
        if (!branches.any((branch) => branch['id'] == branchId)) branchId = null;
      });
    } catch (e) {
      if (mounted && request == revision) setState(() => error = 'Unable to load Salary Report: $e');
    } finally {
      if (mounted && request == revision) setState(() => loading = false);
    }
  }

  Future<void> export(String format) async {
    setState(() { exporting = true; error = null; });
    try {
      final bytes = await widget.export(year, format, branchId);
      if (!mounted) return;
      final suffix = branchId == null ? '' : '_${branchId!.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
      final name = 'Salary_Report_${year}_07_${year + 1}_06$suffix';
      if (format == 'pdf') {
        await Printing.layoutPdf(name: '$name.pdf', dynamicLayout: false,
          onLayout: (_) async => bytes);
      } else {
        await FileSaver.instance.saveFile(name: name, bytes: bytes,
          ext: 'xlsx', mimeType: MimeType.microsoftExcel);
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to export Salary Report: $e');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = (report?['months'] as List? ?? []).cast<Map>();
    final headers = ['Sno', 'Employee ID', 'Employee Name',
      ...months.map((month) => '${month['label']}')];
    final disabled = loading || exporting;
    final empty = visibleBranches.isEmpty;
    final years = <int>{year, ...List.generate(DateTime.now().year - 1999,
      (index) => 2000 + index)}.toList()..sort();
    String money(dynamic amount) => amount == null ? '' : (amount as num).toStringAsFixed(2);
    return Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Salary Report', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('All earnings minus deductions, excluding EPF, EIS and SOCSO deductions.'),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 230, child: DropdownButtonFormField<int>(
            initialValue: year, decoration: const InputDecoration(labelText: 'Reporting period'),
            items: years.map((value) => DropdownMenuItem(value: value,
              child: Text('Jul $value - Jun ${value + 1}'))).toList(),
            onChanged: disabled ? null : (value) async {
              if (value == null) return;
              year = value;
              await reload();
            },
          )),
          SizedBox(width: 230, child: DropdownButtonFormField<String>(
            key: ValueKey('$year:$branchId:${branches.length}'), initialValue: branchId,
            decoration: const InputDecoration(labelText: 'Branch'),
            items: [const DropdownMenuItem<String>(value: null, child: Text('All branches')),
              ...branches.map((branch) => DropdownMenuItem<String>(
                value: '${branch['id']}', child: Text('${branch['name']}', overflow: TextOverflow.ellipsis)))],
            onChanged: disabled ? null : (value) => setState(() => branchId = value),
          )),
          OutlinedButton.icon(onPressed: disabled ? null : reload,
            icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          FilledButton.icon(onPressed: disabled || empty ? null : () => export('xlsx'),
            icon: const Icon(Icons.table_view_outlined), label: const Text('Export Excel')),
          OutlinedButton.icon(onPressed: disabled || empty ? null : () => export('pdf'),
            icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Print / Save PDF')),
        ]),
        const SizedBox(height: 12),
        const Text('Excel: one sheet per branch. PDF: one landscape page per branch. Missing months stay blank.'),
        if (report != null) ...[
          Text('${report!['note']}', style: const TextStyle(fontSize: 12)),
          Text('${report!['branch_note']}', style: const TextStyle(fontSize: 12)),
        ],
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 12),
        Expanded(child: loading ? const Center(child: CircularProgressIndicator())
          : report == null ? const Center(child: Text('Report unavailable. Use Refresh to retry.'))
          : empty ? const Center(child: Text('No eligible saved payroll records in this period.'))
          : ListView(children: [for (final branch in visibleBranches)
              Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${branch['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer),
                    columns: [for (var i = 0; i < headers.length; i++)
                      DataColumn(label: Text(headers[i]), numeric: i >= 3)],
                    rows: [
                      for (var i = 0; i < (branch['rows'] as List).length; i++)
                        DataRow(cells: [DataCell(Text('${i + 1}')),
                          DataCell(Text('${branch['rows'][i]['employee_id']}')),
                          DataCell(SizedBox(width: 180, child: Text('${branch['rows'][i]['name']}'))),
                          for (final value in branch['rows'][i]['values'] as List) DataCell(Text(money(value)))]),
                      DataRow(cells: [const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                        const DataCell(Text('')), const DataCell(Text('')),
                        for (final value in branch['totals'] as List) DataCell(Text(money(value),
                          style: const TextStyle(fontWeight: FontWeight.bold)))])],
                  )),
                ],
              )),
            ])),
      ],
    ));
  }
}
