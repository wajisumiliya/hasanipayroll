import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const adminInk = Color(0xFF20242C);
const adminGold = Color(0xFF987033);
const adminCanvas = Color(0xFFF5F1E8);
const adminBorder = Color(0xFFE7DED0);
const adminMuted = Color(0xFF746B60);

/// Pure live-data projection shared by desktop and mobile.
class AdminOverviewMetrics {
  AdminOverviewMetrics({
    required this.employees,
    required this.activity,
    this.branch,
  });
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic> activity;
  final String? branch;
  static String key(dynamic value) => '${value ?? ''}'.trim().toUpperCase();
  String id(Map row) => key(row['employee_id'] ?? row['id']);
  bool matches(Map row) =>
      branch == null || key(row['branch_id']) == key(branch);
  bool validCheckIn(Map row) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$')
        .firstMatch('${row['check_in'] ?? row['working_in'] ?? ''}'.trim());
    return match != null &&
        int.parse(match[1]!) < 24 &&
        int.parse(match[2]!) < 60;
  }

  bool active(Map row) =>
      row['is_active'] == true || key(row['is_active']) == 'TRUE';
  late final List<Map<String, dynamic>> people =
      employees.where(matches).toList();
  late final Set<String> allIds = employees.map(id).toSet();
  late final Set<String> activeIds = people.where(active).map(id).toSet();
  List<Map<String, dynamic>>? rows(String field) => activity[field] is List
      ? (activity[field] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList()
      : null;
  late final List<Map<String, dynamic>>? lateRows =
      rows('late')?.where((r) => matches(r) && allIds.contains(id(r))).toList();
  late final List<Map<String, dynamic>>? _attendance = rows('attendance');
  late final Set<String>? checkedIn = _checkedIn();
  Set<String>? _checkedIn() {
    final attendance = _attendance;
    if (attendance == null) return null;
    return attendance
        .where(
          (r) =>
              matches(r) &&
              activeIds.contains(id(r)) &&
              validCheckIn(r) &&
              !{
                'OFF',
                'MC',
                'PL',
                'AL',
                'EL',
                'UNPAID',
                'PH-OFF',
                'PH-SPL',
              }.contains(key(r['status'])),
        )
        .map(id)
        .toSet();
  }

  late final Set<String>? lateIds = _lateIds();
  Set<String>? _lateIds() {
    final attendance = _attendance;
    if (attendance == null) return null;
    return attendance
        .where(
          (r) =>
              checkedIn!.contains(id(r)) &&
              matches(r) &&
              key(r['status']).contains('LATE'),
        )
        .map(id)
        .toSet();
  }

  late final Set<String>? offIds = _offIds();
  Set<String>? _offIds() {
    final attendance = _attendance;
    if (attendance == null) return null;
    return attendance
        .where(
          (r) =>
              matches(r) &&
              activeIds.contains(id(r)) &&
              !checkedIn!.contains(id(r)) &&
              {
                'OFF',
                'MC',
                'PL',
                'AL',
                'EL',
                'PH',
                'UNPAID',
                'PH-OFF',
                'PH-SPL',
              }.contains(key(r['status'])),
        )
        .map(id)
        .toSet();
  }

  int? get present =>
      checkedIn == null ? null : checkedIn!.length - lateIds!.length;
  int? get notChecked => checkedIn == null
      ? null
      : activeIds.difference({...checkedIn!, ...offIds!}).length;
  int? pending(String field) => rows(field)
      ?.where(
        (r) =>
            matches(r) &&
            (field == 'employee'
                ? (activity['staff_scope'] != 'local' &&
                        activity['staff_scope'] != 'foreign' ||
                    (activity['staff_scope'] == 'foreign') ==
                        key(r['address']).contains('FRN'))
                : allIds.contains(id(r))) &&
            (field == 'employee'
                ? key(r['status']) == 'PENDING'
                : key(r['status']) == 'PENDING_ADMIN'),
      )
      .length;
}

class ModernAdminOverview extends StatelessWidget {
  const ModernAdminOverview({
    super.key,
    required this.month,
    required this.branch,
    required this.branches,
    required this.employees,
    required this.gross,
    required this.deductions,
    required this.net,
    required this.activity,
    required this.onMonth,
    required this.onBranch,
    required this.onNavigate,
    required this.onRefresh,
    required this.onLateReport,
    required this.onGross,
    required this.onNet,
    required this.birthdays,
    required this.anniversaries,
    required this.onCelebrate,
    required this.breakdown,
    required this.tools,
    this.reports,
  });
  final DateTime month;
  final String? branch;
  final Map<String, String> branches;
  final List<Map<String, dynamic>> employees, birthdays, anniversaries;
  final double gross, deductions, net;
  final Future<Map<String, dynamic>> activity;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<String?> onBranch;
  final ValueChanged<int> onNavigate;
  final Future<void> Function() onRefresh;
  final VoidCallback onLateReport, onGross, onNet;
  final void Function(Map<String, dynamic>, bool) onCelebrate;
  final Widget breakdown, tools;
  final Widget? reports;
  String money(double v) => NumberFormat.currency(
        locale: 'en_MY',
        symbol: 'RM ',
        decimalDigits: 2,
      ).format(v);
  Widget panel(
    String title,
    IconData icon,
    Widget child, {
    String? action,
    VoidCallback? onAction,
  }) =>
      Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: adminBorder),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D30261B),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final heading = Row(
                    children: [
                      Icon(icon, color: adminGold, size: 21),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: adminInk,
                          ),
                        ),
                      ),
                    ],
                  );
                  if (action == null) return heading;
                  if (c.maxWidth < 400) {
                    return Row(
                      children: [
                        Expanded(child: heading),
                        IconButton(
                          tooltip: action,
                          onPressed: onAction,
                          icon:
                              const Icon(Icons.chevron_right, color: adminGold),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: heading),
                      TextButton(onPressed: onAction, child: Text(action)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );
  Widget paired(Widget left, Widget right, {int flex = 3}) => LayoutBuilder(
        builder: (_, c) => c.maxWidth >= 950
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: flex, child: left),
                  const SizedBox(width: 18),
                  Expanded(flex: 2, child: right),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 16), right],
              ),
      );

  Future<void> choosePeriod(BuildContext context) async {
    var selection = month;
    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Choose report month'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selection.month,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Month'),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(
                        DateFormat('MMMM').format(DateTime(2026, i + 1)),
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) {
                      update(() => selection = DateTime(selection.year, v));
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selection.year,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Year'),
                  items: (<int>{
                    month.year,
                    DateTime.now().year + 1,
                    ...List.generate(
                      15,
                      (i) => DateTime.now().year - i,
                    ),
                  }.toList()
                        ..sort((a, b) => b.compareTo(a)))
                      .map(
                        (y) => DropdownMenuItem(value: y, child: Text('$y')),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      update(() => selection = DateTime(v, selection.month));
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selection),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null) onMonth(result);
  }

  Widget filters(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final compact = c.maxWidth < 500;
          return Wrap(
            spacing: 10,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? (c.maxWidth - 10) / 2 : 190,
                child: Material(
                  color: Colors.white,
                  child: InkWell(
                    onTap: () => choosePeriod(context),
                    borderRadius: BorderRadius.circular(9),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Period',
                        prefixIcon:
                            Icon(Icons.calendar_today_outlined, size: 16),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat(compact ? 'MMM yyyy' : 'MMMM yyyy')
                                  .format(month),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const Icon(Icons.expand_more, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: compact ? (c.maxWidth - 10) / 2 : 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('branch-$branch'),
                  initialValue: branch ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Branch',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child:
                          Text('All branches', style: TextStyle(fontSize: 12)),
                    ),
                    ...branches.entries.map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => onBranch(v == '' ? null : v),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate(6),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export report'),
              ),
            ],
          );
        },
      );

  Widget metrics(AdminOverviewMetrics m) => LayoutBuilder(
        builder: (_, c) {
          final compact = c.maxWidth < 800;
          final columns = c.maxWidth < 580 ? 2 : 4;
          final entries = [
            (
              'Total employees',
              '${m.people.length}',
              Icons.groups_outlined,
              adminGold,
              () => onNavigate(1),
            ),
            (
              'Active employees',
              '${m.activeIds.length}',
              Icons.person_outline,
              const Color(0xFF16A777),
              () => onNavigate(1),
            ),
            (
              'Present today',
              m.present?.toString() ?? '—',
              Icons.event_available_outlined,
              adminGold,
              () => onNavigate(3),
            ),
            (
              'Late today',
              m.lateIds?.length.toString() ?? '—',
              Icons.schedule,
              const Color(0xFFE59320),
              () => onNavigate(3),
            ),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: entries
                .map(
                  (e) => SizedBox(
                    width: (c.maxWidth - (columns - 1) * 12) / columns,
                    child: Material(
                      color: e.$4.withValues(alpha: .045),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: e.$4.withValues(alpha: .12)),
                      ),
                      child: InkWell(
                        onTap: e.$5,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 12 : 18),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: compact ? 15 : 22,
                                backgroundColor: e.$4.withValues(alpha: .09),
                                child: Icon(
                                  e.$3,
                                  color: e.$4,
                                  size: compact ? 18 : 22,
                                ),
                              ),
                              SizedBox(width: compact ? 8 : 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.$1,
                                      style: TextStyle(
                                        color: adminMuted,
                                        fontSize: compact ? 10 : 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.$2,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: compact ? 23 : 29,
                                        color: adminInk,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      e.$1 == 'Total employees'
                                          ? 'Directory'
                                          : e.$1 == 'Active employees'
                                              ? 'Current workforce'
                                              : 'Live status',
                                      style: TextStyle(
                                        color: e.$4,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
  Widget payroll() => panel(
        'Payroll overview',
        Icons.bar_chart_outlined,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Net payroll', style: TextStyle(color: adminMuted)),
            InkWell(
              onTap: onNet,
              child: Text(
                money(net),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: adminInk,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 30,
              runSpacing: 12,
              children: [
                InkWell(
                  onTap: onGross,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gross payroll'),
                      Text(
                        money(gross),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: adminInk,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Deductions'),
                    Text(
                      money(deductions),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: adminInk,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Gross payroll', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: gross > 0 ? 1 : 0,
              minHeight: 9,
              borderRadius: BorderRadius.circular(9),
              backgroundColor: const Color(0xFFF1EBDF),
              color: adminGold,
            ),
            const SizedBox(height: 14),
            const Text('Net payroll', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: gross > 0 ? (net / gross).clamp(0, 1) : 0,
              minHeight: 9,
              borderRadius: BorderRadius.circular(9),
              backgroundColor: const Color(0xFFF1EBDF),
              color: const Color(0xFFD7BE8B),
            ),
          ],
        ),
        action: 'View payroll',
        onAction: () => onNavigate(2),
      );

  Widget attendance(AdminOverviewMetrics m) {
    final values = [
      m.present ?? 0,
      m.lateIds?.length ?? 0,
      m.notChecked ?? 0,
      m.offIds?.length ?? 0,
    ];
    const colors = [
      Color(0xFF20B879),
      Color(0xFFF4BE42),
      Color(0xFF9DACBF),
      Color(0xFFDEE6F0),
    ];
    Widget legend(int i, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(shape: BoxShape.circle)
                    .copyWith(color: colors[i]),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 12))),
              Text(
                m.checkedIn == null ? '—' : '${values[i]}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: adminInk,
                ),
              ),
            ],
          ),
        );
    return panel(
      'Attendance today',
      Icons.event_available_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEE, dd MMM yyyy')
                .format(DateTime.now().toUtc().add(const Duration(hours: 8))),
            style: const TextStyle(fontSize: 12, color: adminMuted),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                  painter: _AttendanceRing(values, colors),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${m.activeIds.length}',
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: adminInk,
                          ),
                        ),
                        const Text('Active', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    legend(0, 'Present'),
                    legend(1, 'Late'),
                    legend(2, 'Not checked in'),
                    if (values[3] > 0) legend(3, 'Off / leave'),
                  ],
                ),
              ),
            ],
          ),
          if (m.checkedIn == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Attendance is loading or unavailable. Refresh to retry.',
                style: TextStyle(fontSize: 12, color: adminMuted),
              ),
            ),
        ],
      ),
      action: 'View attendance',
      onAction: () => onNavigate(3),
    );
  }

  Widget late(AdminOverviewMetrics m) => panel(
        'Late Report',
        Icons.schedule,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '3 or more combined monthly occurrences',
              style: TextStyle(fontSize: 12, color: adminMuted),
            ),
            const SizedBox(height: 14),
            if (m.lateRows == null)
              const Text('Report is loading or unavailable. Refresh to retry.')
            else if (m.lateRows!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('No employees meet the monthly threshold.'),
              )
            else
              LayoutBuilder(
                builder: (_, c) {
                  final rows = m.lateRows!.take(5).toList();
                  Widget badge(dynamic count) {
                    final value = (count as num).toInt();
                    final color = value >= 7
                        ? const Color(0xFFBB3434)
                        : value >= 5
                            ? const Color(0xFFB76920)
                            : const Color(0xFFA87A10);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$value',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w800),
                      ),
                    );
                  }

                  if (c.maxWidth < 600) {
                    return Column(
                      children: rows
                          .map(
                            (r) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: onLateReport,
                              title: Text(
                                '${r['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${branches[AdminOverviewMetrics.key(r['branch_id'])] ?? r['branch_id']} · ${r['arrival_count']} arrivals · ${r['break_count']} breaks',
                              ),
                              trailing: badge(r['count']),
                            ),
                          )
                          .toList(),
                    );
                  }
                  return Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.2),
                      1: FlexColumnWidth(1.8),
                      2: FlexColumnWidth(),
                      3: FlexColumnWidth(),
                      4: FlexColumnWidth(),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration:
                            const BoxDecoration(color: Color(0xFFFAF7F1)),
                        children: [
                          'Employee',
                          'Branch',
                          'Arrivals',
                          'Breaks',
                          'Total'
                        ]
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      ...rows.map(
                        (r) => TableRow(
                          children: [
                            r['name'],
                            branches[AdminOverviewMetrics.key(
                                  r['branch_id'],
                                )] ??
                                r['branch_id'],
                            r['arrival_count'],
                            r['break_count'],
                            r['count'],
                          ]
                              .asMap()
                              .entries
                              .map(
                                (e) => InkWell(
                                  onTap: onLateReport,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: e.key == 4
                                        ? badge(e.value)
                                        : Text(
                                            '${e.value}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
        action: 'View report',
        onAction: onLateReport,
      );

  Widget approvals(AdminOverviewMetrics m) => panel(
        'Needs your approval',
        Icons.fact_check_outlined,
        Column(
          children: [
            for (final item in [
              ('Leave requests', 'leave', 13),
              ('Overtime requests', 'ot', 11),
              ('Employee requests', 'employee', 10),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => onNavigate(item.$3),
                title: Text(item.$1),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.pending(item.$2)?.toString() ?? '—',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: adminInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
          ],
        ),
      );
  Widget celebrations() => panel(
        'Upcoming celebrations',
        Icons.card_giftcard_outlined,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in [
              (birthdays, false, 'Birthday', Icons.cake_outlined),
              (anniversaries, true, 'Work anniversary', Icons.star_outline),
            ]) ...[
              Text(
                item.$3,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: adminInk,
                ),
              ),
              if (item.$1.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No events in the next 3 days',
                    style: TextStyle(fontSize: 12, color: adminMuted),
                  ),
                )
              else
                ...item.$1.take(3).map(
                      (e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          item.$4,
                          color: const Color(0xFFD7A22F),
                          size: 20,
                        ),
                        title: Text(
                          '${e['name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          (e['days'] as int) == 0
                              ? 'Today'
                              : (e['days'] as int) == 1
                                  ? 'Tomorrow'
                                  : 'In ${e['days']} days',
                        ),
                        trailing: IconButton(
                          tooltip: 'Send ${item.$3.toLowerCase()} wish',
                          onPressed: () => onCelebrate(e, item.$2),
                          icon: const Icon(Icons.send_outlined, size: 17),
                        ),
                      ),
                    ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      );

  Widget executiveHeader(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final compact = c.maxWidth < 720;
          final branchName = branch == null
              ? 'All branches'
              : branches[AdminOverviewMetrics.key(branch!)] ?? branch!;
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(99),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .14)),
                ),
                child: const Text(
                  'EXECUTIVE WORKSPACE',
                  style: TextStyle(
                    color: Color(0xFFFFE7B7),
                    fontSize: 9,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Payroll Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A clear view of payroll, attendance and workforce performance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeaderChip(
                    icon: Icons.calendar_month_outlined,
                    label: 'Period · ${DateFormat('MMMM yyyy').format(month)}',
                  ),
                  _HeaderChip(icon: Icons.store_outlined, label: branchName),
                ],
              ),
            ],
          );
          final finance = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NET PAYROLL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .6),
                    fontSize: 9,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  money(net),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Gross ${money(gross)}',
                  style:
                      const TextStyle(color: Color(0xFFD9C6A3), fontSize: 11),
                ),
              ],
            ),
          );
          return Container(
            padding: EdgeInsets.all(compact ? 20 : 26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2F2923), Color(0xFF5B4327)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2431261A),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -55,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFC79B52).withValues(alpha: .09),
                    ),
                  ),
                ),
                compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton.filledTonal(
                              tooltip: 'Refresh dashboard',
                              onPressed: () => onRefresh(),
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                          title,
                          const SizedBox(height: 18),
                          finance,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 3, child: title),
                          const SizedBox(width: 24),
                          SizedBox(width: 230, child: finance),
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            tooltip: 'Refresh dashboard',
                            onPressed: () => onRefresh(),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
              ],
            ),
          );
        },
      );

  @override
  
  static const _blue = Color(0xFF2563EB);
  static const _navy = Color(0xFF10213A);
  static const _page = Color(0xFFF2F6FB);
  static const _stroke = Color(0xFFE3EAF3);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _violet = Color(0xFF8B5CF6);

  Widget _surface(String title, Widget content, {Widget? trailing}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _stroke)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _navy))),
        if (trailing != null) trailing]),
      const SizedBox(height: 12), content,
    ]),
  );

  Widget _stat(String label, String amount, IconData icon, Color color, {VoidCallback? tap}) => InkWell(
    onTap: tap, borderRadius: BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _stroke)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 23)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF55657D), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _navy))),
        ])),
      ]),
    ),
  );

  Widget _responsiveCards(List<Widget> children, double width, {double min = 175, double gap = 10}) {
    final cols = math.max(1, (width / (min + gap)).floor());
    final cell = (width - (cols - 1) * gap) / cols;
    return Wrap(spacing: gap, runSpacing: gap, children: [for(final item in children) SizedBox(width: cell, child: item)]);
  }

  Widget _branchGrid(AdminOverviewMetrics m) {
    final counts = <String, int>{};
    for (final p in m.people) {
      final branchId = AdminOverviewMetrics.key(p['branch_id']);
      counts[branchId] = (counts[branchId] ?? 0) + 1;
    }
    final entries = counts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return Column(children: [
      const Row(children: [
        Expanded(flex: 5, child: Text('BRANCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('EMPLOYEES', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
      ]),
      const Divider(height: 14),
      if (entries.isEmpty) const Text('No branch data for the selected period'),
      for (final entry in entries.take(6)) Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(flex: 5, child: Text(branches[entry.key] ?? entry.key, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('${entry.value}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
        ])),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => onNavigate(2), child: const Text('View branches'))),
    ]);
  }

  Widget _salaryBars() {
    final items = <(String, double, Color)>[
      ('Gross', gross, _blue), ('Deductions', deductions, _red), ('Net', net, _green),
    ];
    final highest = math.max(1.0, [gross, deductions, net].reduce(math.max));
    return Column(children: [
      for (final entry in items) Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(entry.$1, style: const TextStyle(fontSize: 12))),
            Text(money(entry.$2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(
            value: (entry.$2 / highest).clamp(0.0, 1.0), minHeight: 13,
            color: entry.$3, backgroundColor: const Color(0xFFEAF0F7))),
        ]),
      ),
    ]);
  }

  Widget _overviewContent(AdminOverviewMetrics m, double width) {
    final total = m.people.length;
    final present = m.present;
    final missing = m.notChecked;
    final attendanceRate = present == null || m.activeIds.isEmpty ? '—' :
      '${(present / m.activeIds.length * 100).toStringAsFixed(1)}%';
    final spacing = width >= 1100 ? 12.0 : 10.0;
    final pairedWidth = width >= 980 ? (width - spacing) / 2 : width;
    final split = width >= 980;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _responsiveCards([
        _stat('Total Employees', '$total', Icons.groups_rounded, _blue, tap: () => onNavigate(1)),
        _stat('Monthly Payroll Amount', money(gross), Icons.account_balance_wallet_rounded, _blue, tap: onGross),
        _stat('Net Salary', money(net), Icons.check_circle_rounded, _green, tap: onNet),
        _stat('Deductions', money(deductions), Icons.timelapse_rounded, _red),
        _stat('Attendance Rate', attendanceRate, Icons.bar_chart_rounded, _green),
        _stat('Missing Check-ins', missing?.toString() ?? '—', Icons.timer_outlined, _violet),
      ], width, min: width >= 1100 ? 165 : 190),
      const SizedBox(height: 12),
      Wrap(spacing: spacing, runSpacing: spacing, children: [
        SizedBox(width: split ? pairedWidth : width, child: _surface('Monthly Payroll Overview', _salaryBars())),
        SizedBox(width: split ? pairedWidth : width, child: _surface('Payroll Split & Salary', Column(children: [
          _salaryBars(),
          const Divider(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: onGross, child: const Text('Gross details'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: onNet, child: const Text('Net details'))),
          ]),
        ]))),
        SizedBox(width: split ? pairedWidth : width, child: _surface('Attendance Monitoring', attendance(m))),
        SizedBox(width: split ? pairedWidth : width, child: _surface('Salary Analytics', Column(children: [
          _salaryBars(),
          TextButton(onPressed: () => onNavigate(3), child: const Text('Open payroll analytics')),
        ]))),
        SizedBox(width: split ? pairedWidth : width, child: _surface('Branch Monitoring', _branchGrid(m))),
        SizedBox(width: split ? pairedWidth : width, child: _surface('Quick Actions & Pending Approvals', Column(children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: () => onNavigate(3), icon: const Icon(Icons.play_arrow), label: const Text('Payroll')),
            OutlinedButton.icon(onPressed: () => onNavigate(12), icon: const Icon(Icons.receipt_long), label: const Text('Payslips')),
            OutlinedButton.icon(onPressed: () => onNavigate(6), icon: const Icon(Icons.table_chart), label: const Text('Reports')),
            OutlinedButton.icon(onPressed: () => onNavigate(4), icon: const Icon(Icons.fact_check), label: const Text('Attendance')),
          ]),
          approvals(m),
        ]))),
      ]),
      const SizedBox(height: 12),
      ExpansionTile(key: const PageStorageKey('hasani-dashboard-financial-details'),
        title: const Text('Detailed payroll breakdown'), children: [breakdown]),
      ExpansionTile(key: const PageStorageKey('hasani-dashboard-management-tools'),
        title: const Text('Additional management tools'), children: [tools]),
      if (reports != null) ExpansionTile(title: const Text('Payroll Reports'), children: [reports!]),
    ]);
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: _blue),
      scaffoldBackgroundColor: _page,
    ),
    child: RefreshIndicator(onRefresh: onRefresh,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = math.max(1.0, constraints.maxWidth - (constraints.maxWidth < 600 ? 24 : 36));
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dashboard Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _navy)),
                Text('Payroll, people and branch performance in one place',
                  style: TextStyle(fontSize: 12, color: Color(0xFF61718B))),
              ]),
              filters(context),
            ]),
            const SizedBox(height: 14),
            FutureBuilder<Map<String, dynamic>>(future: activity, builder: (context, snapshot) {
              final m = AdminOverviewMetrics(employees: employees,
                activity: snapshot.connectionState == ConnectionState.done ? (snapshot.data ?? {}) : {},
                branch: branch);
              return _overviewContent(m, width);
            }),
          ]),
        );
      }),
    ),
  );
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
          maxWidth: math.max(120, MediaQuery.sizeOf(context).width - 100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFFFE7B7), size: 14),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _AttendanceRing extends CustomPainter {
  _AttendanceRing(this.values, this.colors);
  final List<int> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ring = rect.deflate(8);
    final total = values.fold<int>(0, (a, b) => a + b);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawArc(
      ring,
      0,
      math.pi * 2,
      false,
      p..color = const Color(0xFFF1EBDF),
    );
    if (total == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final angle = values[i] / total * math.pi * 2;
      canvas.drawArc(ring, start, angle, false, p..color = colors[i]);
      start += angle;
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceRing old) =>
      old.values.toString() != values.toString();
}

/// Always-visible report entry points retained from the original dashboard.
class AdminDashboardReportCards extends StatelessWidget {
  const AdminDashboardReportCards({super.key, required this.itemBuilder});
  final Widget Function(double width, String report) itemBuilder;
  static const reports = [
    'Payroll',
    'EPF',
    'SOCSO',
    'EIS',
    'HRDF',
    'Payroll Summary',
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 900
              ? 3
              : c.maxWidth >= 540
                  ? 2
                  : 1;
          final width = (c.maxWidth - 10 * (columns - 1)) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                reports.map((report) => itemBuilder(width, report)).toList(),
          );
        },
      );
}

/// Concept B report library: independent report actions with live monthly figures.
class IvoryAdminReportCard extends StatelessWidget {
  const IvoryAdminReportCard({
    super.key,
    required this.width,
    required this.title,
    required this.icon,
    required this.value,
    required this.caption,
    required this.onTap,
    this.logoBytes,
  });
  final double width;
  final String title, value, caption;
  final IconData icon;
  final VoidCallback onTap;
  final Uint8List? logoBytes;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Material(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: adminBorder),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F1E3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: adminGold, size: 27),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: adminInk,
                                ),
                              ),
                            ),
                            if (logoBytes != null)
                              Image.memory(
                                logoBytes!,
                                width: 30,
                                height: 19,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: adminInk,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 10, color: adminMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: adminGold, size: 17),
                ],
              ),
            ),
          ),
        ),
      );
}
