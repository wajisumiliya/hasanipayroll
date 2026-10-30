import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'modern_admin_overview.dart';

/// Analytics use saved payroll only; missing months are never interpolated.
class AdminAnalytics extends StatelessWidget {
  const AdminAnalytics(
      {super.key,
      required this.month,
      required this.branch,
      required this.branches,
      required this.employees,
      required this.payroll,
      required this.activity,
      required this.grossOf,
      required this.baseOf});
  final DateTime month;
  final String? branch;
  final Map<String, String> branches;
  final List<Map<String, dynamic>> employees, payroll;
  final Future<Map<String, dynamic>> activity;
  final double Function(Map<String, dynamic>) grossOf, baseOf;
  static String canonical(dynamic v) => '${v ?? ''}'.trim().toUpperCase();
  static String id(Map r) => canonical(r['employee_id'] ?? r['id']);
  static double number(dynamic v) =>
      double.tryParse('$v'.replaceAll(',', '')) ?? 0;
  static double deductionsOf(Map r) => [
        'late_deduction',
        'unpaid_deduction',
        'epf_employee',
        'socso_employee',
        'eis_employee',
        'pcb',
        'zakat',
        'advance'
      ].fold(0, (sum, field) => sum + number(r[field]));
  String money(double n) =>
      NumberFormat.currency(locale: 'en_MY', symbol: 'RM ', decimalDigits: 2)
          .format(n);
  String branchOf(Map r) {
    final own = canonical(r['branch_id']);
    if (own.isNotEmpty) return own;
    for (final e in employees) {
      if (id(e) == id(r)) return canonical(e['branch_id']);
    }
    return '';
  }

  List<Map<String, dynamic>> rows(DateTime date, {String? atBranch}) =>
      payroll.where((r) {
        final d = DateTime.tryParse('${r['period']}');
        return d != null &&
            d.year == date.year &&
            d.month == date.month &&
            ((atBranch ?? branch) == null ||
                branchOf(r) == canonical(atBranch ?? branch));
      }).toList();
  double total(List<Map<String, dynamic>> rs,
          double Function(Map<String, dynamic>) value) =>
      rs.fold(0, (a, r) => a + value(r));
  Widget card(String title, String subtitle, Widget body) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: adminBorder),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 18, offset: Offset(0, 5))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: adminInk)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: adminMuted)),
        const SizedBox(height: 20),
        body
      ]));
  Widget empty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(text, style: const TextStyle(color: adminMuted)));
  Widget table(List<String> headers, List<List<String>> data,
          {void Function(int)? onRow}) =>
      LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor:
                          const WidgetStatePropertyAll(Color(0xFFF8F5EF)),
                      headingTextStyle: const TextStyle(
                          color: adminMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                      dataTextStyle:
                          const TextStyle(color: adminInk, fontSize: 12),
                      columnSpacing: 24,
                      horizontalMargin: 12,
                      columns: headers
                          .map((h) => DataColumn(label: Text(h)))
                          .toList(),
                      rows: List.generate(
                          data.length,
                          (index) => DataRow(
                              onSelectChanged:
                                  onRow == null ? null : (_) => onRow(index),
                              cells: data[index]
                                  .map((v) => DataCell(Text(v)))
                                  .toList()))))));
  void details(BuildContext context, String title, List<String> headers,
      List<List<String>> data) {
    showDialog<void>(
        context: context,
        builder: (context) => Dialog(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1100, maxHeight: 650),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(title,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))
                          ]),
                          const SizedBox(height: 12),
                          Expanded(
                              child: SingleChildScrollView(
                                  child: data.isEmpty
                                      ? empty(
                                          'No saved records for this selection.')
                                      : table(headers, data)))
                        ])))));
  }

  String name(Map row) {
    for (final e in employees) {
      if (id(e) == id(row)) return '${e['name'] ?? id(row)}';
    }
    return id(row);
  }

  Widget bar(String label, double value, double max, Color color,
          {String? caption}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(color: adminMuted, fontSize: 12))),
              Text(caption ?? money(value),
                  style: const TextStyle(
                      color: adminInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))
            ]),
            const SizedBox(height: 7),
            ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                    value: max <= 0 ? 0 : (value / max).clamp(0, 1),
                    minHeight: 9,
                    backgroundColor: const Color(0xFFF1EEE8),
                    color: color))
          ]));

  @override
  Widget build(BuildContext context) {
    final current = rows(month);
    final gross = total(current, grossOf);
    final deduction = total(current, (r) => deductionsOf(r));
    final net = gross - deduction;
    final period = DateFormat('MMMM yyyy').format(month);
    final history =
        List.generate(8, (i) => DateTime(month.year, month.month - 7 + i));
    final maximum =
        history.map((d) => total(rows(d), grossOf)).fold<double>(0, math.max);
    final monthLabel = DateFormat('MMM yy');
    final trend = card(
        'Monthly payroll trend',
        'Saved gross payroll · eight months ending $period',
        Column(children: [
          for (final d in history)
            if (rows(d).isEmpty)
              Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(children: [
                    Expanded(
                        child: Text(monthLabel.format(d),
                            style: const TextStyle(color: adminMuted))),
                    const Text('No saved payroll',
                        style: TextStyle(color: adminMuted, fontSize: 12))
                  ]))
            else
              InkWell(
                  onTap: () => details(
                      context,
                      '${monthLabel.format(d)} · saved payroll',
                      ['Employee', 'Gross', 'Deductions', 'Net'],
                      rows(d)
                          .map((r) => [
                                name(r),
                                money(grossOf(r)),
                                money(deductionsOf(r)),
                                money(grossOf(r) - deductionsOf(r))
                              ])
                          .toList()),
                  child: bar(monthLabel.format(d), total(rows(d), grossOf),
                      maximum, adminGold)),
          const Text(
              'Select a month to inspect the employee totals. Unsaved months are excluded from comparisons.',
              style: TextStyle(color: adminMuted, fontSize: 11))
        ]));
    final split = card(
        'Payroll composition',
        '$period · ${current.length} saved payroll records',
        current.isEmpty
            ? empty('No saved payroll for this month.')
            : Column(children: [
                bar('Gross earnings', gross, math.max(gross, net), adminGold),
                bar('Net pay', net, math.max(gross, net),
                    const Color(0xFF27675D)),
                bar('Employee deductions', deduction, math.max(gross, net),
                    const Color(0xFFB46B45)),
                Text(
                    gross > 0 && net >= 0 && deduction >= 0
                        ? '${(net / gross * 100).toStringAsFixed(1)}% net pay · ${(deduction / gross * 100).toStringAsFixed(1)}% deductions'
                        : 'Review payroll values before interpreting the split.',
                    style: const TextStyle(color: adminMuted, fontSize: 12)),
                const SizedBox(height: 14),
                for (final category in <String, String>{
                  'EPF (employee)': 'epf_employee',
                  'SOCSO (employee)': 'socso_employee',
                  'EIS (employee)': 'eis_employee',
                  'PCB': 'pcb',
                  'Late deductions': 'late_deduction',
                  'Unpaid leave': 'unpaid_deduction',
                  'Zakat': 'zakat',
                  'Advance': 'advance'
                }.entries)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                            child: Text(category.key,
                                style: const TextStyle(
                                    color: adminMuted, fontSize: 12))),
                        Text(
                            money(total(
                                current, (r) => number(r[category.value]))),
                            style:
                                const TextStyle(color: adminInk, fontSize: 12))
                      ])),
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () => details(
                            context,
                            'Payroll detail · $period',
                            ['Employee', 'Gross', 'Deductions', 'Net'],
                            current
                                .map((r) => [
                                      name(r),
                                      money(grossOf(r)),
                                      money(deductionsOf(r)),
                                      money(grossOf(r) - deductionsOf(r))
                                    ])
                                .toList()),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View employee breakdown')))
              ]));
    return LayoutBuilder(
        builder: (_, c) => c.maxWidth < 1000
            ? Column(children: [trend, const SizedBox(height: 18), split])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: trend),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: split)
              ]));
  }
}
