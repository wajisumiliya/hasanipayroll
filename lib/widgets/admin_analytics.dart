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
    final trend = card(
        'Monthly Gross Payroll Amount',
        'Saved gross payroll · eight months ending $period',
        MonthlyGrossPayrollChart(
          months: history,
          values: history
              .map((d) => rows(d).isEmpty ? null : total(rows(d), grossOf))
              .toList(),
          onMonth: (index) {
            final d = history[index];
            details(
                context,
                '${DateFormat('MMM yy').format(d)} · saved payroll',
                ['Employee', 'Gross', 'Deductions', 'Net'],
                rows(d)
                    .map((r) => [
                          name(r),
                          money(grossOf(r)),
                          money(deductionsOf(r)),
                          money(grossOf(r) - deductionsOf(r))
                        ])
                    .toList());
          },
        ));
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

/// Labelled, scrollable bars preserve readable values on narrow displays.
class MonthlyGrossPayrollChart extends StatelessWidget {
  const MonthlyGrossPayrollChart(
      {super.key,
      required this.months,
      required this.values,
      required this.onMonth});
  final List<DateTime> months;
  final List<double?> values;
  final ValueChanged<int> onMonth;
  static const colors = [
    Color(0xFF378DF5),
    Color(0xFF26BDE8),
    Color(0xFF23CCA0),
    Color(0xFF8ADA54),
    Color(0xFFFFCF3E),
    Color(0xFFFF9445),
    Color(0xFFFF626B),
    Color(0xFFFA459A)
  ];
  @override
  Widget build(BuildContext context) {
    final maximum = values.whereType<double>().fold<double>(0, math.max);
    final magnitude = maximum <= 0
        ? 1.0
        : math.pow(10, (math.log(maximum) / math.ln10).floor()).toDouble();
    final ceiling =
        maximum <= 0 ? 1.0 : (maximum / magnitude).ceil() * magnitude;
    final currency =
        NumberFormat.currency(locale: 'en_MY', symbol: 'RM ', decimalDigits: 2);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Text('Amount (RM)', style: TextStyle(fontSize: 11, color: adminMuted)),
        Spacer(),
        Icon(Icons.circle, size: 10, color: Color(0xFF378DF5)),
        SizedBox(width: 6),
        Text('Gross payroll', style: TextStyle(fontSize: 11, color: adminMuted))
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(
          builder: (_, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                  width: math.max(760, constraints.maxWidth),
                  height: 276,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 65,
                            height: 260,
                            child: Stack(children: [
                              for (var tick = 0; tick <= 5; tick++)
                                Positioned(
                                    top: 17 + tick * 44.0,
                                    right: 8,
                                    child: Text(
                                        NumberFormat('#,##0.##')
                                            .format(ceiling * (5 - tick) / 5),
                                        style: const TextStyle(
                                            fontSize: 10, color: adminMuted)))
                            ])),
                        Expanded(
                            child: Column(children: [
                          SizedBox(
                              height: 244,
                              child: Stack(children: [
                                for (var tick = 0; tick <= 5; tick++)
                                  Positioned(
                                      top: 24 + tick * 44.0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                          height: 1,
                                          color: const Color(0xFFE2EAF5))),
                                Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (var index = 0;
                                          index < values.length;
                                          index++)
                                        Expanded(
                                            child: Tooltip(
                                                message: values[index] == null
                                                    ? 'No saved payroll'
                                                    : currency
                                                        .format(values[index]),
                                                child: InkWell(
                                                    onTap: values[index] == null
                                                        ? null
                                                        : () => onMonth(index),
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6),
                                                        child: SizedBox(
                                                            height: 244,
                                                            child: Column(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .end,
                                                                children: [
                                                                  SizedBox(
                                                                      height:
                                                                          19,
                                                                      child: FittedBox(
                                                                          fit: BoxFit
                                                                              .scaleDown,
                                                                          child: Text(
                                                                              values[index] == null ? '—' : currency.format(values[index]),
                                                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: adminInk)))),
                                                                  Container(
                                                                      height: values[index] ==
                                                                              null
                                                                          ? 0
                                                                          : (values[index]! / ceiling * 220)
                                                                              .clamp(0, 220)
                                                                              .toDouble(),
                                                                      decoration: BoxDecoration(
                                                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                                                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
                                                                            colors[index % colors.length].withValues(alpha: .85),
                                                                            colors[index %
                                                                                colors.length]
                                                                          ])))
                                                                ]))))))
                                    ])
                              ])),
                          const SizedBox(height: 8),
                          Row(children: [
                            for (final month in months)
                              Expanded(
                                  child: Text(
                                      DateFormat('MMM yy').format(month),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 11, color: adminMuted)))
                          ])
                        ]))
                      ])))),
      if (values.any((v) => v == null))
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No saved payroll',
                style: TextStyle(color: adminMuted, fontSize: 11))),
      const SizedBox(height: 8),
      const Text(
          'Select a bar to inspect saved employee totals. Missing months have no bar.',
          style: TextStyle(color: adminMuted, fontSize: 11)),
    ]);
  }
}
