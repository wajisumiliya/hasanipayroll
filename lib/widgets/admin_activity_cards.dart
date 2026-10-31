import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/payroll_calculation_service.dart';
import 'modern_admin_overview.dart';

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
      required this.onPayroll,
      this.referenceDate});
  final DateTime month;
  final String? branch;
  final List<Map<String, dynamic>> employees, payroll;
  final Future<Map<String, dynamic>> activity;
  final ValueChanged<DateTime> onMonth;
  final VoidCallback onLate, onPayroll;
  final DateTime? referenceDate;
  static const ink = Color(0xFF0B1A3C), muted = Color(0xFF3C587F);
  static const pink = Color(0xFFFF214B),
      green = Color(0xFF00A96F),
      gold = Color(0xFFF3A000),
      blue = Color(0xFF0876FF);
  static String canonical(dynamic v) => '${v ?? ''}'.trim().toUpperCase();
  static String employeeId(Map r) => canonical(r['employee_id'] ?? r['id']);
  static double number(dynamic v) =>
      double.tryParse('$v'.replaceAll(',', '')) ?? 0;
  bool matches(Map r) =>
      branch == null || canonical(r['branch_id']) == canonical(branch);
  bool active(Map r) => canonical(r['is_active']) == 'TRUE';
  DateTime get today {
    final now =
        referenceDate ?? DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime(now.year, now.month, now.day);
  }

  List<Map<String, dynamic>> get people =>
      employees.where((r) => matches(r) && active(r)).toList();
  DateTime? date(Map r, List<String> keys) {
    for (final key in keys) {
      final value = DateTime.tryParse('${r[key] ?? ''}');
      if (value != null) return value;
    }
    return null;
  }

  // Today through the fifth following day, including cross-month/year events.
  List<Map<String, dynamic>> occasions(bool anniversary) {
    final result = <Map<String, dynamic>>[];
    final start = today;
    for (final e in people) {
      final original = date(
          e,
          anniversary
              ? ['joining_date', 'joiningDate']
              : ['birthday', 'date_of_birth']);
      if (original == null || original.isAfter(start)) continue;
      DateTime occurrence(int year) {
        final last = DateTime(year, original.month + 1, 0).day;
        return DateTime(year, original.month, math.min(original.day, last));
      }

      var event = occurrence(start.year);
      if (event.isBefore(start)) event = occurrence(start.year + 1);
      final days = event.difference(start).inDays;
      final years = event.year - original.year;
      if (days > 5 || (anniversary && years < 1)) continue;
      result.add({
        ...e,
        'event': event,
        'original': original,
        'days': days,
        'years': years
      });
    }
    result.sort(
        (a, b) => (a['event'] as DateTime).compareTo(b['event'] as DateTime));
    return result;
  }

  // Maintained increment schedules identify eligibility even before payroll is generated.
  List<Map<String, dynamic>> increments() {
    final result = <Map<String, dynamic>>[];
    const months = {
      'JAN': 1,
      'FEB': 2,
      'MAR': 3,
      'APR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AUG': 8,
      'SEP': 9,
      'SEPT': 9,
      'OCT': 10,
      'NOV': 11,
      'DEC': 12
    };
    for (final e in people) {
      final text = canonical(e['inc_details']);
      final match =
          RegExp(r'^([A-Z]{3,4})[-/](\d{4}|\d{2})(?:\D|$)').firstMatch(text);
      if (match == null) continue;
      var year = int.parse(match[2]!);
      if (year < 100) year += 2000;
      final separator = text.lastIndexOf('/');
      final amount = separator < 0
          ? null
          : double.tryParse(text.substring(separator + 1).trim());
      if (months[match[1]] != month.month ||
          year != month.year ||
          amount == null ||
          !PayrollCalculationService.isValidPayrollIncrementAmount(amount))
        continue;
      final prior =
          payroll.where((r) => employeeId(r) == employeeId(e)).where((r) {
        final d = DateTime.tryParse('${r['period']}');
        return d != null && d.isBefore(DateTime(month.year, month.month));
      }).toList()
            ..sort((a, b) => '${b['period']}'.compareTo('${a['period']}'));
      final baseline = prior.isEmpty
          ? 0.0
          : number(prior.first['basic_salary']) +
              number(prior.first['elaun_kedatangan']) +
              number(prior.first['elaun_perkhidmatan']) +
              number(prior.first['elaun_kerajinan']);
      result.add({
        ...e,
        'amount': amount,
        'event': DateTime(year, month.month),
        'percent': baseline > 0 ? amount / baseline * 100 : null
      });
    }
    result.sort((a, b) => number(b['amount']).compareTo(number(a['amount'])));
    return result;
  }

  static List<Map<String, dynamic>> arrivals(Map r) =>
      (r['events'] as List? ?? [])
          .whereType<Map>()
          .where((e) => e['type'] == 'arrival')
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  static double? lateMinutes(Map r) {
    final events = arrivals(r);
    return events.isEmpty
        ? null
        : events.fold<double>(0, (sum, e) => sum + number(e['minutes']));
  }

  static String hours(double? minutes) =>
      minutes == null ? '—' : '${(minutes / 60).toStringAsFixed(2)} h';
  String name(Map r) => '${r['name'] ?? r['employee_name'] ?? employeeId(r)}';
  String position(Map r) =>
      '${r['position'] ?? r['designation'] ?? r['job_title'] ?? '—'}';
  String initials(Map r) => name(r)
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .take(2)
      .map((s) => s[0])
      .join()
      .toUpperCase();
  Future<void> chooseMonth(BuildContext context) async {
    final selected = await showDatePicker(
        context: context,
        initialDate: DateTime(month.year, month.month),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
        helpText: 'Select payroll month');
    if (selected != null) onMonth(DateTime(selected.year, selected.month));
  }

  Widget avatar(Map row, Color color) {
    final url = '${row['photo_url'] ?? row['profile_photo_url'] ?? ''}';
    final uri = Uri.tryParse(url);
    return CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: .13),
        child: uri != null && uri.scheme == 'https'
            ? ClipOval(
                child: Image.network(url,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(initials(row),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold))))
            : Text(initials(row),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: ink)));
  }

  Widget badge(String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(18)),
      child: Text(value,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)));
  void lateDetails(BuildContext context, Map<String, dynamic> row) {
    final events = arrivals(row)
      ..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(
                    '${name(row)} · ${row['arrival_count']} late days · ${hours(lateMinutes(row))}'),
                content: SizedBox(
                    width: 680,
                    child: SingleChildScrollView(
                        child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                                columns: ['Date', 'Scheduled', 'Check-in', 'Late minutes'].map((v) => DataColumn(label: Text(v))).toList(),
                                rows: events
                                    .map((e) => DataRow(
                                            cells: [
                                          '${e['date']}',
                                          '${e['scheduled'] ?? '—'}',
                                          '${e['actual'] ?? '—'}',
                                          '${e['minutes']}'
                                        ].map((v) => DataCell(Text(v))).toList()))
                                    .toList())))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ]));
  }

  Widget recordsTable(
          BuildContext context,
          List<Map<String, dynamic>> rows,
          List<String> headers,
          List<String> Function(Map<String, dynamic>) values,
          Color color,
          {bool late = false,
          bool increments = false}) =>
      LayoutBuilder(
          builder: (_, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                  width: math.max(c.maxWidth, 620),
                  child: Column(children: [
                    Container(
                        height: 32,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF2F5FA),
                            borderRadius: BorderRadius.circular(9)),
                        child: Row(children: [
                          const SizedBox(
                              width: 34,
                              child: Text('#',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: ink))),
                          for (final title in [
                            'Employee',
                            'Position',
                            ...headers
                          ])
                            Expanded(
                                flex: title == 'Employee' ? 3 : 2,
                                child: Text(title,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: ink)))
                        ])),
                    for (var i = 0; i < rows.length; i++)
                      Padding(
                          padding: EdgeInsets.only(top: late ? 4 : 0),
                          child: Material(
                              color: Colors.white
                                  .withValues(alpha: late ? .85 : .2),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(late ? 10 : 0),
                                  side: BorderSide(
                                      color: late
                                          ? color.withValues(alpha: .09)
                                          : const Color(0xFFF1F4F8))),
                              child: InkWell(
                                  onTap: late
                                      ? () => lateDetails(context, rows[i])
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                      height: late ? 49 : 47,
                                      child: Row(children: [
                                        SizedBox(
                                            width: 34,
                                            child: Text('${i + 1}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    color: ink, fontSize: 12))),
                                        Expanded(
                                            flex: 3,
                                            child: Row(children: [
                                              avatar(rows[i], color),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                  child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Text(employeeId(rows[i]),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: ink,
                                                            fontSize: 12)),
                                                    Text(name(rows[i]),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            color: muted,
                                                            fontSize: 12))
                                                  ]))
                                            ])),
                                        Expanded(
                                            flex: 2,
                                            child: Text(position(rows[i]),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: muted,
                                                    fontSize: 11))),
                                        for (var cell = 0;
                                            cell < values(rows[i]).length;
                                            cell++)
                                          Expanded(
                                              flex: 2,
                                              child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: (late && cell == 0) ||
                                                          (!increments &&
                                                              cell == 1 &&
                                                              !late)
                                                      ? badge(
                                                          values(rows[i])[cell],
                                                          color)
                                                      : Text(
                                                          values(rows[i])[cell],
                                                          style: TextStyle(
                                                              color:
                                                                  increments &&
                                                                          cell ==
                                                                              0
                                                                      ? green
                                                                      : muted,
                                                              fontSize: 12,
                                                              fontWeight: increments &&
                                                                      cell == 0
                                                                  ? FontWeight
                                                                      .w700
                                                                  : FontWeight
                                                                      .w400))))
                                      ])))))
                  ]))));
  void showAll(
      BuildContext context,
      String title,
      List<Map<String, dynamic>> rows,
      List<String> headers,
      List<String> Function(Map<String, dynamic>) values,
      Color color,
      {bool late = false,
      bool increments = false}) {
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))
                          ]),
                          Expanded(
                              child: SingleChildScrollView(
                                  child: recordsTable(
                                      context, rows, headers, values, color,
                                      late: late, increments: increments)))
                        ])))));
  }

  Widget stats(List<(IconData, String, String, Color)> entries) =>
      LayoutBuilder(builder: (_, c) {
        final columns = c.maxWidth < 450 ? 2 : 4;
        final width = (c.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
            spacing: 10,
            runSpacing: 8,
            children: entries
                .map((e) => Container(
                    width: width,
                    height: 64,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: e.$4.withValues(alpha: .08))),
                    child: Row(children: [
                      Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: e.$4.withValues(alpha: .05),
                              shape: BoxShape.circle),
                          child: Icon(e.$1, color: e.$4, size: 24)),
                      const SizedBox(width: 7),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            SizedBox(
                                height: 24,
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(e.$2,
                                        style: const TextStyle(
                                            fontSize: 20,
                                            height: 1,
                                            fontWeight: FontWeight.w800,
                                            color: ink)))),
                            const SizedBox(height: 3),
                            Flexible(
                                child: Tooltip(
                                    message: e.$3,
                                    child: Text(e.$3,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 9,
                                            height: 1.1,
                                            color: muted))))
                          ]))
                    ])))
                .toList());
      });
  Widget card(BuildContext context,
      {required String title,
      required String subtitle,
      required Color color,
      required IconData icon,
      required List<(IconData, String, String, Color)> totals,
      required List<Map<String, dynamic>>? rows,
      required List<String> headers,
      required List<String> Function(Map<String, dynamic>) values,
      required String note,
      bool late = false,
      bool increments = false,
      bool upcoming = false}) {
    final chip = OutlinedButton.icon(
        onPressed: upcoming ? null : () => chooseMonth(context),
        style: OutlinedButton.styleFrom(
            foregroundColor: color,
            disabledForegroundColor: color,
            backgroundColor: color.withValues(alpha: .035),
            side: BorderSide(color: color.withValues(alpha: .15)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
        icon: Icon(Icons.calendar_month, size: 17, color: color),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(DateFormat('MMMM yyyy').format(upcoming ? today : month),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down, size: 17, color: color)
        ]));
    final heading = Row(children: [
      Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: color.withValues(alpha: .09)),
          child: Icon(icon, color: color, size: 35)),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            key: ValueKey('activity-heading-$title'),
            style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: muted))
      ]))
    ]);
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: .15)),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, color.withValues(alpha: .025)])),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: LayoutBuilder(
                  builder: (_, c) => c.maxWidth >= 630
                      ? Row(children: [
                          Expanded(child: heading),
                          const SizedBox(width: 10),
                          chip
                        ])
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              heading,
                              Align(
                                  alignment: Alignment.centerRight, child: chip)
                            ]))),
          Divider(height: 1, color: color.withValues(alpha: .08)),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: stats(totals)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 260),
                  child: rows == null
                      ? const Center(
                          child: Text(
                              'Report data unavailable. Refresh to retry.'))
                      : rows.isEmpty
                          ? Center(
                              child: Text(
                                  upcoming
                                      ? 'No events in the next 5 days.'
                                      : 'No matching records for this month.',
                                  style: const TextStyle(
                                      color: muted, fontSize: 12)))
                          : recordsTable(context, rows.take(5).toList(),
                              headers, values, color,
                              late: late, increments: increments))),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 14),
              child: Row(children: [
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            color: color.withValues(alpha: .065)),
                        child: Row(children: [
                          Icon(Icons.info, color: color, size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                              child: Text(note,
                                  style: TextStyle(fontSize: 11, color: color)))
                        ]))),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: rows == null
                        ? null
                        : () => showAll(
                            context, title, rows, headers, values, color,
                            late: late, increments: increments),
                    style: TextButton.styleFrom(foregroundColor: color),
                    child: Row(children: [
                      const Text('View All',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward, size: 18)
                    ]))
              ]))
        ]));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: activity,
      builder: (_, snapshot) {
        final metrics = AdminOverviewMetrics(
            employees: employees,
            activity: snapshot.data ?? {},
            branch: branch);
        final byId = {for (final e in employees) employeeId(e): e};
        final late = metrics.lateRows
            ?.where((r) => number(r['arrival_count']) >= 3)
            .map((r) => {...?byId[employeeId(r)], ...r})
            .toList()
          ?..sort((a, b) =>
              number(b['arrival_count']).compareTo(number(a['arrival_count'])));
        final inc = increments(),
            birthdays = occasions(false),
            anniversaries = occasions(true);
        final count = people.length;
        final totalDays = late?.fold<int>(
            0, (sum, r) => sum + number(r['arrival_count']).toInt());
        final rate = late == null || count == 0
            ? '—'
            : '${(late.length / count * 100).toStringAsFixed(1)}%';
        final totalAmount =
            inc.fold<double>(0, (sum, r) => sum + number(r['amount']));
        final percents =
            inc.map((r) => r['percent']).whereType<double>().toList();
        String money(double value) => NumberFormat.currency(
                locale: 'en_MY', symbol: 'RM ', decimalDigits: 2)
            .format(value);
        List<(IconData, String, String, Color)> eventStats(
            List<Map<String, dynamic>> rows, bool anniversary) {
          final start = today;
          final endOfWeek = start.add(Duration(days: 7 - start.weekday));
          return [
            (
              anniversary ? Icons.groups : Icons.cake,
              '${rows.length}',
              anniversary ? 'Upcoming Anniversaries' : 'Upcoming Birthdays',
              anniversary ? blue : gold
            ),
            (
              anniversary ? Icons.workspace_premium : Icons.card_giftcard,
              '${rows.where((r) => !(r['event'] as DateTime).isAfter(endOfWeek)).length}',
              'This Week',
              anniversary ? blue : gold
            ),
            (
              Icons.calendar_month,
              '${rows.where((r) => (r['event'] as DateTime).month == start.month).length}',
              'This Month',
              anniversary ? blue : gold
            ),
            (
              Icons.groups,
              '$count',
              'Total Employees',
              anniversary ? blue : gold
            )
          ];
        }

        final cards = [
          card(context,
              title: 'Attendance Late (3 and above)',
              subtitle: 'Employees with 3 or more late arrivals this month',
              color: pink,
              icon: Icons.alarm,
              totals: [
                (
                  Icons.groups,
                  '${late?.length ?? '—'}',
                  'Total Late (≥3)',
                  pink
                ),
                (Icons.warning, '${totalDays ?? '—'}', 'Total Late Days', pink),
                (
                  Icons.person,
                  '$count',
                  'Total Employees',
                  const Color(0xFF008CB5)
                ),
                (Icons.pie_chart, rate, 'Late Rate', gold)
              ],
              rows: late,
              headers: ['Late Days', 'Late Hours'],
              values: (r) => ['${r['arrival_count']}', hours(lateMinutes(r))],
              note: 'Showing employees with 3 or more late days this month.',
              late: true),
          card(context,
              title: 'Increment List',
              subtitle: 'Employees eligible for this payroll month',
              color: green,
              icon: Icons.trending_up,
              totals: [
                (Icons.groups, '${inc.length}', 'Employees Eligible', green),
                (
                  Icons.payments,
                  money(totalAmount),
                  'Total Increment Amount',
                  green
                ),
                (
                  Icons.trending_up,
                  percents.isEmpty || percents.length != inc.length
                      ? '—'
                      : '+${(percents.reduce((a, b) => a + b) / percents.length).toStringAsFixed(1)}%',
                  'Avg. Increment',
                  const Color(0xFF00BEAA)
                ),
                (
                  Icons.calendar_month,
                  inc.isEmpty
                      ? '—'
                      : DateFormat('MMM-yy').format(month).toUpperCase(),
                  'Increment Month',
                  blue
                )
              ],
              rows: inc,
              headers: ['Increment', 'Effective'],
              values: (r) => [
                    money(number(r['amount'])),
                    DateFormat('MMM yyyy').format(r['event'] as DateTime)
                  ],
              note:
                  'Eligible in the selected payroll month from maintained increment schedules.',
              increments: true),
          card(context,
              title: 'Upcoming Birthdays',
              subtitle: 'Employees celebrating their birthday',
              color: gold,
              icon: Icons.cake,
              totals: eventStats(birthdays, false),
              rows: birthdays,
              headers: ['Birthday', 'Days Left'],
              values: (r) => [
                    DateFormat('d MMM yyyy').format(r['event'] as DateTime),
                    r['days'] == 0 ? 'Today' : '${r['days']} days'
                  ],
              note: 'Shows upcoming birthdays within the next 5 days.',
              upcoming: true),
          card(context,
              title: 'Work Anniversary',
              subtitle: 'Employees celebrating their service anniversary',
              color: blue,
              icon: Icons.star,
              totals: eventStats(anniversaries, true),
              rows: anniversaries,
              headers: ['Joined Date', 'Years'],
              values: (r) => [
                    DateFormat('d MMM yyyy').format(r['original'] as DateTime),
                    '${r['years']} years'
                  ],
              note: 'Shows work anniversaries within the next 5 days.',
              upcoming: true)
        ];
        return LayoutBuilder(
            builder: (_, c) => Wrap(spacing: 16, runSpacing: 12, children: [
                  for (final item in cards)
                    SizedBox(
                        width: c.maxWidth >= 1100
                            ? (c.maxWidth - 16) / 2
                            : c.maxWidth,
                        child: item)
                ]));
      });
}
