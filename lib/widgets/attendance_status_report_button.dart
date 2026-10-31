import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../services/app_service.dart';

class AttendanceStatusReportButton extends StatelessWidget {
  const AttendanceStatusReportButton(
      {super.key,
      required this.month,
      required this.branch,
      required this.status,
      required this.employeeIds});
  final DateTime month;
  final String? branch;
  final String status;
  final List<String> employeeIds;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _AttendanceStatusDialog(
              month: month,
              branch: branch,
              status: status,
              employeeIds: employeeIds)),
      icon: Icon(
          status == 'MC' ? Icons.medical_services_outlined : Icons.event_busy,
          size: 18),
      label: Text(status == 'MC' ? 'MC Report' : 'Unpaid Report'));
}

class _AttendanceStatusDialog extends StatefulWidget {
  const _AttendanceStatusDialog(
      {required this.month,
      required this.branch,
      required this.status,
      required this.employeeIds});
  final DateTime month;
  final String? branch;
  final String status;
  final List<String> employeeIds;
  @override
  State<_AttendanceStatusDialog> createState() =>
      _AttendanceStatusDialogState();
}

class _AttendanceStatusDialogState extends State<_AttendanceStatusDialog> {
  late Future<Map<String, dynamic>> data;
  bool printing = false;
  Future<Map<String, dynamic>> load({bool pdf = false}) =>
      AppService.instance.loadAttendanceStatusReport(
          month: widget.month,
          status: widget.status,
          branchId: widget.branch,
          employeeIds: widget.employeeIds,
          pdf: pdf);
  @override
  void initState() {
    super.initState();
    data = load();
  }

  Future<void> printReport() async {
    setState(() => printing = true);
    try {
      final result = await load(pdf: true);
      final bytes = base64Decode(result['file_base64'] as String);
      if (!mounted) return;
      await Printing.layoutPdf(
          name:
              '${widget.status}_${DateFormat('yyyy_MM').format(widget.month)}.pdf',
          dynamicLayout: false,
          onLayout: (_) async => bytes);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to print report: $error')));
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 650),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              '${widget.status == 'MC' ? 'MC' : 'Unpaid'} Report · ${DateFormat('MMMM yyyy').format(widget.month)}',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold))),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close))
                    ]),
                    Expanded(
                        child: FutureBuilder<Map<String, dynamic>>(
                            future: data,
                            builder: (_, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done)
                                return const Center(
                                    child: CircularProgressIndicator());
                              if (snapshot.hasError)
                                return Center(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      const Text('Unable to load report.'),
                                      TextButton(
                                          onPressed: () =>
                                              setState(() => data = load()),
                                          child: const Text('Retry'))
                                    ]));
                              final result = snapshot.data ?? {};
                              final rows = (result['reports'] as List? ?? [])
                                  .whereType<Map>()
                                  .toList();
                              final branches = result['branches'] as Map? ?? {};
                              if (rows.isEmpty)
                                return const Center(
                                    child: Text(
                                        'No matching attendance records for this month and branch.'));
                              final days = rows.fold<int>(
                                  0,
                                  (sum, r) =>
                                      sum +
                                      ((widget.status == 'MC'
                                              ? r['mc_taken'] ?? r['count']
                                              : r['count']) as num)
                                          .toInt());
                              return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${result['branchLabel']} · ${rows.length} employees · $days days'),
                                    const SizedBox(height: 12),
                                    Expanded(
                                        child: SingleChildScrollView(
                                            child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: DataTable(
                                                    columns: [
                                                      'Employee ID',
                                                      'Employee',
                                                      'Branch',
                                                      if (widget.status ==
                                                          'MC') ...[
                                                        'Opening MC',
                                                        'MC Taken',
                                                        'Closing MC'
                                                      ] else
                                                        'Days',
                                                      'Dates'
                                                    ]
                                                        .map((v) => DataColumn(
                                                            label: Text(v)))
                                                        .toList(),
                                                    dataRowMinHeight: 48,
                                                    dataRowMaxHeight: 240,
                                                    rows: rows
                                                        .map((r) => DataRow(
                                                                cells: [
                                                              '${r['employee_id']}',
                                                              '${r['name']}',
                                                              '${r['branch_names'] ?? branches['${r['branch_id']}'.trim().toUpperCase()] ?? r['branch_id']}',
                                                              if (widget
                                                                      .status ==
                                                                  'MC') ...[
                                                                '${r['opening_mc'] ?? 'Not set'}',
                                                                '${r['mc_taken'] ?? r['count']}',
                                                                '${r['closing_mc'] ?? 'Not set'}',
                                                              ] else
                                                                '${r['count']}',
                                                              (r['dates']
                                                                      as List)
                                                                  .join(', ')
                                                            ]
                                                                    .map((v) => DataCell(SizedBox(
                                                                        width: v.length >
                                                                                70
                                                                            ? 320
                                                                            : null,
                                                                        child: Text(
                                                                            v))))
                                                                    .toList()))
                                                        .toList()))))
                                  ]);
                            })),
                    Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                            onPressed: printing ? null : printReport,
                            icon: const Icon(Icons.print),
                            label: Text(
                                printing ? 'Preparing PDF…' : 'Print PDF')))
                  ]))));
}
