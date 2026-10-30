import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/payroll_calculation_service.dart';
import 'modern_admin_overview.dart';

/// Selected-month records only. No sample employees or invented increments.
class AdminActivityCards extends StatelessWidget {
  const AdminActivityCards(
      {super.key,
      required this.month,
      required this.branch,
      required this.employees,
      required this.payroll,
      required this.activity,
      required this.onMonth,
      required this.onLate,
      required this.onPayroll});
  final DateTime month;
  final String? branch;
  final List<Map<String, dynamic>> employees, payroll;
  final Future<Map<String, dynamic>> activity;
  final ValueChanged<DateTime> onMonth;
  final VoidCallback onLate, onPayroll;
  static String canonical(dynamic v) => '${v ?? ''}'.trim().toUpperCase();
  static String employeeId(Map r) => canonical(r['employee_id'] ?? r['id']);
  static double number(dynamic v) =>
      double.tryParse('$v'.replaceAll(',', '')) ?? 0;
  bool matches(Map r) =>
      branch == null || canonical(r['branch_id']) == canonical(branch);
  bool active(Map r) => canonical(r['is_active']) == 'TRUE';
  DateTime? date(Map r, List<String> keys) {
    for (final key in keys) {
      final parsed = DateTime.tryParse('${r[key] ?? ''}');
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<Map<String, dynamic>> occasions(bool anniversary) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = DateTime(now.year, now.month, now.day);
    final result = <Map<String, dynamic>>[];
    for (final employee in employees.where((r) => matches(r) && active(r))) {
      final original = date(
          employee,
          anniversary
              ? ['joining_date', 'joiningDate']
              : ['birthday', 'date_of_birth']);
      if (original == null ||
          original.month != month.month ||
          original.year > month.year) continue;
      final years = month.year - original.year;
      if (anniversary && years < 1) continue;
      final last = DateTime(month.year, month.month + 1, 0).day;
      final event = DateTime(
          month.year, month.month, original.day > last ? last : original.day);
      result.add({
        ...employee,
        'event': event,
        'original': original,
        'years': years,
        'days': event.difference(today).inDays
      });
    }
    result.sort(
        (a, b) => (a['event'] as DateTime).compareTo(b['event'] as DateTime));
    return result;
  }

  List<Map<String, dynamic>> increments() {
    final result = <Map<String, dynamic>>[];
    for (final employee in employees.where(matches)) {
      final records =
          payroll.where((r) => employeeId(r) == employeeId(employee)).toList();
      // A saved record in the selected month is required.
      if (!records.any((r) {
        final period = DateTime.tryParse('${r['period']}');
        return period != null &&
            period.year == month.year &&
            period.month == month.month &&
            (branch == null ||
                canonical(canonical(r['branch_id']).isEmpty
                        ? employee['branch_id']
                        : r['branch_id']) ==
                    canonical(branch));
      })) continue;
      final history = records
          .where((r) => DateTime.tryParse('${r['period']}') != null)
          .map((r) => (
                period: DateTime.parse('${r['period']}'),
                basicSalary: number(r['basic_salary']),
                attendanceAllowance: number(r['elaun_kedatangan']),
                serviceAllowance: number(r['elaun_perkhidmatan']),
                diligenceAllowance: number(r['elaun_kerajinan'])
              ))
          .toList();
      final change =
          PayrollCalculationService.payrollIncrementComparisonForMonth(
              history, month);
      if (change == null || change.amount <= 0) continue;
      result.add({
        ...employee,
        'amount': change.amount,
        'event': change.currentPeriod
      });
    }
    result.sort((a, b) => number(b['amount']).compareTo(number(a['amount'])));
    return result;
  }

  String name(Map r) => '${r['name'] ?? r['employee_name'] ?? employeeId(r)}';
  String position(Map r) =>
      '${r['position'] ?? r['designation'] ?? r['job_title'] ?? '—'}';
  String initials(Map r) {
    final words =
        name(r).trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2);
    return words.map((s) => s[0]).join().toUpperCase();
  }

  Future<void> chooseMonth(BuildContext context) async {
    final result = await showDatePicker(
        context: context,
        initialDate: DateTime(month.year, month.month),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
        helpText: 'Select reporting month');
    if (result != null) onMonth(DateTime(result.year, result.month));
  }

  Widget recordsTable(List<Map<String, dynamic>> records, List<String> headings,
          List<String> Function(Map<String, dynamic>) cells, Color accent) =>
      LayoutBuilder(
          builder: (_, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: DataTable(
                      headingRowColor:
                          WidgetStatePropertyAll(accent.withValues(alpha: .05)),
                      horizontalMargin: 12,
                      columnSpacing: 20,
                      dataRowMinHeight: 62,
                      dataRowMaxHeight: 72,
                      headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF23354F),
                          fontSize: 12),
                      columns: ['#', 'Employee', 'Position', ...headings]
                          .map((h) => DataColumn(label: Text(h)))
                          .toList(),
                      rows: List.generate(records.length, (index) {
                        final row = records[index];
                        return DataRow(cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Row(children: [
                            CircleAvatar(
                                radius: 18,
                                backgroundColor: accent.withValues(alpha: .12),
                                child: Text(initials(row),
                                    style: TextStyle(
                                        color: accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold))),
                            const SizedBox(width: 9),
                            Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(employeeId(row),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                  Text(name(row),
                                      style: const TextStyle(fontSize: 12))
                                ])
                          ])),
                          DataCell(Text(position(row),
                              style: const TextStyle(fontSize: 12))),
                          ...cells(row).map((v) => DataCell(
                              Text(v, style: const TextStyle(fontSize: 12))))
                        ]);
                      })))));
  void showAll(
      BuildContext context,
      String title,
      List<Map<String, dynamic>> rows,
      List<String> headings,
      List<String> Function(Map<String, dynamic>) cells,
      Color color) {
    showDialog<void>(
        context: context,
        builder: (context) => Dialog(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 1100, maxHeight: 650),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20))),
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))
                          ]),
                          Expanded(
                              child: SingleChildScrollView(
                                  child: recordsTable(
                                      rows, headings, cells, color)))
                        ])))));
  }

  Widget card(BuildContext context,
          {required String title,
          required String subtitle,
          required IconData icon,
          required Color color,
          required List<Map<String, dynamic>>? rows,
          required List<String> headings,
          required List<String> Function(Map<String, dynamic>) cells,
          required String note,
          VoidCallback? onAll}) =>
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: .12)),
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withValues(alpha: .045), Colors.white])),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(15)),
                      child: Icon(icon, color: color, size: 30)),
                  SizedBox(
                      width: 250,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF102041))),
                            const SizedBox(height: 4),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF566780)))
                          ])),
                  OutlinedButton.icon(
                      onPressed: () => chooseMonth(context),
                      icon: Icon(Icons.calendar_month, size: 17, color: color),
                      label: Text(DateFormat('MMMM yyyy').format(month),
                          style: TextStyle(color: color)))
                ]),
            const SizedBox(height: 18),
            if (rows == null)
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Report data unavailable. Refresh to retry.'))
            else if (rows.isEmpty)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No matching records for this month.'))
            else
              recordsTable(rows.take(5).toList(), headings, cells, color),
            const SizedBox(height: 16),
            Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(note,
                          style: TextStyle(fontSize: 11, color: color))),
                  TextButton.icon(
                      onPressed: rows == null
                          ? null
                          : onAll ??
                              () => showAll(
                                  context, title, rows, headings, cells, color),
                      label: const Text('View All'),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      style: TextButton.styleFrom(foregroundColor: color))
                ])
          ]));
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: activity,
      builder: (_, snapshot) {
        final metrics = AdminOverviewMetrics(
            employees: employees,
            activity: snapshot.data ?? {},
            branch: branch);
        final people = {for (final e in employees) employeeId(e): e};
        final late = metrics.lateRows
            ?.where((r) => number(r['arrival_count']) >= 3)
            .map((r) => {...?people[employeeId(r)], ...r})
            .toList()
          ?..sort((a, b) =>
              number(b['arrival_count']).compareTo(number(a['arrival_count'])));
        String lastLate(Map r) {
          final events = (r['events'] as List? ?? [])
              .whereType<Map>()
              .where((e) => e['type'] == 'arrival')
              .map((e) => DateTime.tryParse('${e['date']}'))
              .whereType<DateTime>()
              .toList()
            ..sort();
          return events.isEmpty
              ? '—'
              : DateFormat('d MMM yyyy').format(events.last);
        }

        String days(Map r) {
          final count = r['days'] as int;
          return count == 0
              ? 'Today'
              : count > 0
                  ? 'In $count days'
                  : '${-count} days ago';
        }

        final cards = [
          card(context,
              title: 'Attendance Late (3 and above)',
              subtitle: 'Employees with 3 or more late arrivals this month',
              icon: Icons.schedule,
              color: const Color(0xFFE32950),
              rows: late,
              headings: ['Late days', 'Last late'],
              cells: (r) => ['${r['arrival_count']}', lastLate(r)],
              note:
                  'Late arrivals only. Full Late Report also includes excess breaks.',
              onAll: onLate),
          card(
            context,
            title: 'Increment List',
            subtitle: 'Saved payroll increases under existing increment rules',
            icon: Icons.trending_up,
            color: const Color(0xFF009E66),
            rows: increments(),
            headings: ['Increment', 'Payroll month'],
            cells: (r) => [
              NumberFormat.currency(symbol: 'RM ', decimalDigits: 2)
                  .format(r['amount']),
              DateFormat('MMM yyyy').format(r['event'] as DateTime)
            ],
            note:
                'Calculated from saved payroll; not an approval or effective-date record.',
          ),
          card(context,
              title: 'Upcoming Birthdays',
              subtitle: 'Employee birthdays in the selected month',
              icon: Icons.cake,
              color: const Color(0xFFD99400),
              rows: occasions(false),
              headings: ['Birthday', 'Days left'],
              cells: (r) => [
                    DateFormat('d MMM yyyy').format(r['event'] as DateTime),
                    days(r)
                  ],
              note:
                  'Active employees · selected month · past dates labelled clearly.'),
          card(context,
              title: 'Work Anniversary',
              subtitle: 'Employees celebrating their service anniversary',
              icon: Icons.star,
              color: const Color(0xFF1976F9),
              rows: occasions(true),
              headings: ['Joined date', 'Years'],
              cells: (r) => [
                    DateFormat('d MMM yyyy').format(r['original'] as DateTime),
                    '${r['years']} years'
                  ],
              note: 'Completed service years in the selected month.')
        ];
        return LayoutBuilder(
            builder: (_, c) => Wrap(spacing: 16, runSpacing: 16, children: [
                  for (final item in cards)
                    SizedBox(
                        width: c.maxWidth >= 1100
                            ? (c.maxWidth - 16) / 2
                            : c.maxWidth,
                        child: item)
                ]));
      });
}
