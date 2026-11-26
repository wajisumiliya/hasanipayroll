import 'package:flutter/material.dart';

class PayrollOverviewEntry {
  const PayrollOverviewEntry(
      {required this.employeeId,
      required this.name,
      required this.basicSalary,
      required this.gross,
      required this.deductions,
      required this.net,
      required this.status,
      required this.onDetails});
  final String employeeId, name, basicSalary, gross, deductions, net, status;
  final VoidCallback onDetails;
}

class PayrollOverviewTable extends StatelessWidget {
  const PayrollOverviewTable({super.key, required this.entries});
  final List<PayrollOverviewEntry> entries;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 24,
          columns: [
            for (final title in [
              'Employee ID',
              'Name',
              'Basic Salary',
              'Gross Pay',
              'Deductions',
              'Net Pay',
              'Status',
              'Actions'
            ])
              DataColumn(
                  label: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: entries
              .map((entry) => DataRow(
                    onSelectChanged: (_) => entry.onDetails(),
                    cells: [
                      DataCell(Text(entry.employeeId)),
                      DataCell(SizedBox(
                          width: 160,
                          child: Text(entry.name,
                              maxLines: 2, overflow: TextOverflow.ellipsis))),
                      DataCell(Text(entry.basicSalary)),
                      DataCell(Text(entry.gross)),
                      DataCell(Text(entry.deductions)),
                      DataCell(Text(entry.net,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(entry.status)),
                      DataCell(TextButton(
                          onPressed: entry.onDetails,
                          child: const Text('View details'))),
                    ],
                  ))
              .toList(),
        ),
      );
}
