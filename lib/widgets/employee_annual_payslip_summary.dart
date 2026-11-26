import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/payroll.dart';
import '../services/annual_payslip_summary.dart';
import '../services/annual_payslip_export.dart';

class EmployeeAnnualPayslipSummary extends StatefulWidget {
  const EmployeeAnnualPayslipSummary(
      {super.key,
      required this.employees,
      required this.records,
      required this.onRefresh});
  final List<Employee> employees;
  final List<PayrollRecord> records;
  final VoidCallback onRefresh;
  @override
  State<EmployeeAnnualPayslipSummary> createState() =>
      _EmployeeAnnualPayslipSummaryState();
}

class _EmployeeAnnualPayslipSummaryState
    extends State<EmployeeAnnualPayslipSummary> {
  String? employeeId;
  int year = DateTime.now().year;
  bool exporting = false;
  Future<void> export(
      AnnualPayslipSummary summary, String name, bool pdf) async {
    setState(() => exporting = true);
    try {
      final filename = 'Annual_Salary_${summary.employeeId}_${summary.year}';
      if (pdf) {
        final bytes = await AnnualPayslipExport.pdf(summary, name);
        await Printing.layoutPdf(
            name: '$filename.pdf',
            format: PdfPageFormat.a4,
            onLayout: (_) async => bytes);
      } else {
        await FileSaver.instance.saveFile(
            name: filename,
            bytes: AnnualPayslipExport.excel(summary, name),
            ext: 'xlsx',
            mimeType: MimeType.microsoftExcel);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to export annual summary: $error')));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = [...widget.employees]
      ..sort((a, b) => a.name.compareTo(b.name));
    final employee =
        employees.where((e) => e.employeeId == employeeId).firstOrNull;
    final years = <int>{
      DateTime.now().year,
      year,
      for (final p in widget.records)
        if (employee == null ||
            p.employeeId.trim().toUpperCase() ==
                employee.employeeId.trim().toUpperCase())
          p.period.year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    AnnualPayslipSummary? summary;
    String? error;
    if (employee != null) {
      try {
        summary = AnnualPayslipSummary(
            employeeId: employee.employeeId,
            year: year,
            records: widget.records);
      } catch (e) {
        error = 'Unable to show annual summary: $e';
      }
    }
    Widget table(List<String> headers, List<List<String>> rows) =>
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
              headingRowHeight: 54,
              columnSpacing: 24,
              border: TableBorder.all(color: const Color(0xFFCBD5E1)),
              headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black),
              columns: [
                for (final h in headers) DataColumn(label: Text(h))
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [for (final value in r) DataCell(Text(value))])
              ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
                width: 360,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(employee?.employeeId),
                  initialValue: employee?.employeeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Choose employee',
                      border: OutlineInputBorder()),
                  items: [
                    for (final e in employees)
                      DropdownMenuItem(
                          value: e.employeeId,
                          child: Text('${e.name} (${e.employeeId})',
                              overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (value) => setState(() => employeeId = value),
                )),
            SizedBox(
                width: 150,
                child: DropdownButtonFormField<int>(
                  key: ValueKey(year),
                  initialValue: year,
                  decoration: const InputDecoration(
                      labelText: 'Year', border: OutlineInputBorder()),
                  items: [
                    for (final y in years)
                      DropdownMenuItem(value: y, child: Text('$y'))
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => year = value);
                  },
                )),
            OutlinedButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh')),
            OutlinedButton.icon(
                onPressed: summary == null || exporting
                    ? null
                    : () => export(summary!, employee!.name, true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Print / Save PDF')),
            OutlinedButton.icon(
                onPressed: summary == null || exporting
                    ? null
                    : () => export(summary!, employee!.name, false),
                icon: const Icon(Icons.table_view),
                label: const Text('Export Excel')),
          ]),
      const SizedBox(height: 20),
      if (error != null)
        Text(error, style: const TextStyle(color: Colors.red))
      else if (summary == null)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Choose an employee and year to view the annual payslip summary.'))
      else ...[
        Text('ANNUAL SALARY YEAR $year',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('NAME: ${employee!.name}   |   ID: ${employee.employeeId}'),
        const SizedBox(height: 12),
        table(AnnualPayslipSummary.salaryHeaders,
            AnnualPayslipExport.salaryRows(summary)),
        const SizedBox(height: 24),
        Text('WELFARE/GIFT/BONUS YEAR $year',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        table(AnnualPayslipSummary.bonusHeaders,
            AnnualPayslipExport.bonusRows(summary)),
        const SizedBox(height: 12),
        const Text(AnnualPayslipSummary.explanation,
            style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ]);
  }
}
