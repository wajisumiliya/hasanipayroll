import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/payroll_calculation_service.dart';

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
    this.analytics,
    this.workforceHeader,
    this.payrollRecords = const [],
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
  final Widget? reports, analytics, workforceHeader;
  final List<Map<String, dynamic>> payrollRecords;
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
  Widget build(BuildContext context) => _ReferencePayrollDashboard(view: this);

  Widget legacyBuild(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: adminGold,
            secondary: Color(0xFFD4A532),
            surface: Colors.white,
            onSurface: adminInk,
          ),
          textTheme: Theme.of(context)
              .textTheme
              .apply(bodyColor: adminInk, displayColor: adminInk),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: adminBorder),
            ),
          ),
        ),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                executiveHeader(context),
                const SizedBox(height: 20),
                filters(context),
                const SizedBox(height: 26),
                if (reports != null) ...[
                  const Text(
                    'Payroll reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: adminInk,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Preview or export each report separately',
                    style: TextStyle(color: adminMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  reports!,
                  const SizedBox(height: 22),
                ],
                FutureBuilder<Map<String, dynamic>>(
                  future: activity,
                  builder: (_, s) {
                    final m = AdminOverviewMetrics(
                      employees: employees,
                      activity: s.connectionState == ConnectionState.done
                          ? s.data ?? {}
                          : {},
                      branch: branch,
                    );
                    return paired(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          panel(
                            'Workforce snapshot',
                            Icons.groups_outlined,
                            metrics(m),
                          ),
                          const SizedBox(height: 18),
                          payroll(),
                          const SizedBox(height: 18),
                          late(m),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          attendance(m),
                          const SizedBox(height: 18),
                          approvals(m),
                          const SizedBox(height: 18),
                          celebrations(),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: adminBorder),
                  ),
                  child: ExpansionTile(
                    key: const PageStorageKey('overview-payroll-details'),
                    title: const Text('Detailed payroll breakdown'),
                    subtitle: const Text(
                      'Statutory contributions, allowances and payroll tools',
                    ),
                    children: [breakdown],
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ExpansionTile(
                      key: const PageStorageKey('overview-management-tools'),
                      title: const Text('More management tools'),
                      children: [tools],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final action in [
                          ('Payslips', 12, Icons.receipt_long_outlined),
                          ('Reports', 6, Icons.bar_chart_outlined),
                          ('Daily reports', 14, Icons.description_outlined),
                          ('Branch logs', 9, Icons.store_outlined),
                          ('Settings', 7, Icons.settings_outlined),
                        ])
                          OutlinedButton.icon(
                            onPressed: () => onNavigate(action.$2),
                            icon: Icon(action.$3, size: 17),
                            label: Text(action.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _ReferencePayrollDashboard extends StatelessWidget {
  const _ReferencePayrollDashboard({required this.view});
  final ModernAdminOverview view;

  static const navy = Color(0xFF071B35);
  static const blue = Color(0xFF2678F3);
  static const cyan = Color(0xFF20B8EA);
  static const green = Color(0xFF08B86E);
  static const red = Color(0xFFFF4D58);
  static const purple = Color(0xFF7C42F5);
  static const orange = Color(0xFFFFA31A);
  static const canvas = Color(0xFFF4F8FD);
  static const line = Color(0xFFDDE7F3);
  static const muted = Color(0xFF58708F);

  BoxDecoration card() => BoxDecoration(
        color: Colors.white,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0B123766), blurRadius: 12, offset: Offset(0, 3)),
        ],
      );

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}'.replaceAll(',', '').trim()) ?? 0;
  String _key(dynamic value) => '${value ?? ''}'.trim().toUpperCase();
  String _employeeId(Map row) => _key(row['employee_id'] ?? row['id']);
  DateTime? _period(Map row) => DateTime.tryParse('${row['period'] ?? ''}');
  double _gross(Map row) {
    final salary = _number(row['fw_salary']) != 0
        ? _number(row['fw_salary'])
        : _number(row['basic_salary']);
    return salary +
        _number(row['elaun_kedatangan']) +
        _number(row['elaun_perkhidmatan']) +
        _number(row['elaun_kerajinan']) +
        _number(row['elaun_makanan']) +
        _number(row['overtime']) +
        _number(row['bonus']) +
        _number(row['commission']) +
        _number(row['other_earnings']) +
        _number(row['cuti_umum']);
  }

  double _deductions(Map row) =>
      _number(row['late_deduction']) +
      _number(row['unpaid_deduction']) +
      _number(row['epf_employee']) +
      _number(row['socso_employee']) +
      _number(row['eis_employee']) +
      _number(row['pcb']) +
      _number(row['zakat']) +
      _number(row['advance']);
  double _net(Map row) {
    final stored = _number(row['net_pay'] ?? row['net_salary']);
    return stored != 0 ? stored : _gross(row) - _deductions(row);
  }

  Map<String, String> get _employeeBranches => {
        for (final employee in view.employees)
          _employeeId(employee): _key(employee['branch_id'])
      };
  String _recordBranch(Map row) => _key(row['branch_id']).isNotEmpty
      ? _key(row['branch_id'])
      : _employeeBranches[_employeeId(row)] ?? '';
  bool _monthMatches(Map row, DateTime month) {
    final period = _period(row);
    return period != null &&
        period.year == month.year &&
        period.month == month.month;
  }

  List<Map<String, dynamic>> _periodPayroll() => view.payrollRecords
      .where((row) => _monthMatches(row, view.month))
      .where((row) =>
          view.branch == null || _recordBranch(row) == _key(view.branch))
      .toList();
  List<Map<String, dynamic>> _people() => view.employees
      .where((row) =>
          view.branch == null || _key(row['branch_id']) == _key(view.branch))
      .toList();

  List<Map<String, dynamic>> _increments() {
    final employeeNames = {
      for (final e in view.employees)
        _employeeId(e): '${e['name'] ?? _employeeId(e)}'
    };
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in view.payrollRecords) {
      final id = _employeeId(row);
      if (id.isNotEmpty) grouped.putIfAbsent(id, () => []).add(row);
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in grouped.entries) {
      final currentRows =
          entry.value.where((r) => _monthMatches(r, view.month)).toList();
      if (currentRows.isEmpty) continue;
      final current = currentRows.last;
      if (view.branch != null && _recordBranch(current) != _key(view.branch)) {
        continue;
      }
      final history = entry.value
          .map((r) {
            final period = _period(r);
            if (period == null) return null;
            return (
              period: period,
              basicSalary: _number(r['basic_salary']),
              attendanceAllowance: _number(r['elaun_kedatangan']),
              serviceAllowance: _number(r['elaun_perkhidmatan']),
              diligenceAllowance: _number(r['elaun_kerajinan'])
            );
          })
          .whereType<
              ({
                DateTime period,
                double basicSalary,
                double attendanceAllowance,
                double serviceAllowance,
                double diligenceAllowance
              })>()
          .toList();
      final comparison =
          PayrollCalculationService.payrollIncrementComparisonForMonth(
              history, view.month);
      if (comparison == null) continue;
      result.add({
        'employee_id': entry.key,
        'name': employeeNames[entry.key] ?? entry.key,
        'branch_id': _recordBranch(current),
        'previous': comparison.previousBasicSalary +
            comparison.previousAttendanceAllowance +
            comparison.previousServiceAllowance +
            comparison.previousDiligenceAllowance,
        'current': comparison.currentBasicSalary +
            comparison.currentAttendanceAllowance +
            comparison.currentServiceAllowance +
            comparison.currentDiligenceAllowance,
        'amount': comparison.amount
      });
    }
    result.sort((a, b) => _number(b['amount']).compareTo(_number(a['amount'])));
    return result;
  }

  Future<void> _showDetails(
      BuildContext context,
      String title,
      List<Map<String, dynamic>> rows,
      List<(String, String Function(Map))> columns) async {
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                  width: 760,
                  height: math.min(520, 100.0 + rows.length * 48),
                  child: rows.isEmpty
                      ? const Center(
                          child: Text(
                              'No database records for the selected filter.'))
                      : Scrollbar(
                          child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: columns
                                        .map((c) =>
                                            DataColumn(label: Text(c.$1)))
                                        .toList(),
                                    rows: rows
                                        .map((row) => DataRow(
                                            cells: columns
                                                .map((c) =>
                                                    DataCell(Text(c.$2(row))))
                                                .toList()))
                                        .toList(),
                                  ))))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: canvas,
          colorScheme:
              const ColorScheme.light(primary: blue, surface: Colors.white),
          textTheme: Theme.of(context)
              .textTheme
              .apply(bodyColor: navy, displayColor: navy),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: view.activity,
          builder: (context, snapshot) {
            final activity = snapshot.data ?? <String, dynamic>{};
            final metrics = AdminOverviewMetrics(
              employees: view.employees,
              activity: activity,
              branch: view.branch,
            );
            return RefreshIndicator(
              onRefresh: view.onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 12 : 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context),
                      const SizedBox(height: 12),
                      _kpis(context, metrics),
                      const SizedBox(height: 12),
                      if (view.analytics != null)
                        view.analytics!
                      else ...[
                        _topAnalytics(context, metrics),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      _detailsAndTools(),
                    ]),
              ),
            );
          },
        ),
      );

  Widget _header(BuildContext context) => LayoutBuilder(builder: (_, c) {
        final compact = c.maxWidth < 850;
        final title = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard Overview',
                  style: TextStyle(
                      fontSize: 24, height: 1, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text(
                  "Welcome back! Here's what's happening with your payroll today.",
                  style: TextStyle(fontSize: 12, color: muted)),
            ]);
        final controls = Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (!compact)
                SizedBox(
                    width: 290,
                    height: 42,
                    child: TextField(
                        decoration: InputDecoration(
                            hintText:
                                'Search employees, payroll, or anything...',
                            hintStyle: const TextStyle(fontSize: 11),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: line))))),
              _periodButton(context),
              _branchButton(),
              IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => view.onNavigate(7),
                  icon: const Badge(
                      label: Text('12'),
                      child:
                          Icon(Icons.notifications_none_rounded, color: navy))),
              const CircleAvatar(
                  radius: 19,
                  backgroundColor: Color(0xFFE8EEF6),
                  child: Icon(Icons.person, color: navy)),
              const SizedBox(
                  width: 100,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin User',
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                        Text('System Admin',
                            style: TextStyle(fontSize: 10, color: muted))
                      ])),
            ]);
        final heading = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 12), controls])
            : Row(children: [Expanded(child: title), controls]);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              if (view.workforceHeader != null) ...[
                const SizedBox(height: 10),
                Align(
                    alignment: Alignment.centerRight,
                    child: view.workforceHeader!),
              ],
            ]);
      });

  Widget _periodButton(BuildContext context) => OutlinedButton.icon(
        onPressed: () => view.choosePeriod(context),
        icon: const Icon(Icons.calendar_month_outlined, size: 16),
        label: Text(DateFormat('MMMM yyyy').format(view.month)),
        style: OutlinedButton.styleFrom(
            foregroundColor: navy,
            backgroundColor: Colors.white,
            side: const BorderSide(color: line),
            minimumSize: const Size(142, 42),
            textStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _branchButton() => Container(
        width: 150,
        height: 42,
        decoration: card(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonFormField<String>(
          initialValue: view.branch ?? '',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 17),
          decoration: const InputDecoration(
              border: InputBorder.none, contentPadding: EdgeInsets.zero),
          items: [
            const DropdownMenuItem(value: '', child: Text('All Branches')),
            ...view.branches.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis)))
          ],
          onChanged: (v) => view.onBranch(v == '' ? null : v),
        ),
      );

  Widget _kpis(BuildContext context, AdminOverviewMetrics m) {
    final active = m.activeIds.length;
    final attendance = active == 0 || m.checkedIn == null
        ? 0.0
        : m.checkedIn!.length / active * 100;
    final payroll = _periodPayroll();
    final attendanceRows = (m.activity['attendance'] as List? ?? const [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where((r) =>
            view.branch == null || _key(r['branch_id']) == _key(view.branch))
        .toList();
    final otRows = (m.activity['ot'] as List? ?? const [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where((r) =>
            view.branch == null || _key(r['branch_id']) == _key(view.branch))
        .toList();
    final otMinutes = otRows.fold<double>(
        0,
        (sum, row) =>
            sum +
            _number(row['approved_minutes'] ??
                row['minutes'] ??
                row['duration_minutes']));
    final values = <(String, String, String, IconData, Color, VoidCallback)>[
      (
        'Total Employees',
        '${m.people.length}',
        'Database employee records',
        Icons.groups_rounded,
        blue,
        () => _showDetails(context, 'Employees', _people(), [
              ('Employee ID', (r) => '${r['employee_id'] ?? r['id'] ?? ''}'),
              ('Name', (r) => '${r['name'] ?? ''}'),
              (
                'Branch',
                (r) =>
                    view.branches[_key(r['branch_id'])] ??
                    '${r['branch_id'] ?? ''}'
              ),
              ('Status', (r) => r['is_active'] == true ? 'Active' : 'Inactive')
            ])
      ),
      (
        'Monthly Payroll Amount',
        view.money(view.gross),
        '${payroll.length} payroll records',
        Icons.monetization_on_rounded,
        blue,
        () => _showDetails(context, 'Monthly Payroll', payroll, [
              ('Employee', (r) => '${r['employee_id'] ?? ''}'),
              ('Gross', (r) => view.money(_gross(r))),
              ('Deductions', (r) => view.money(_deductions(r))),
              ('Net', (r) => view.money(_net(r)))
            ])
      ),
      (
        'Paid Payroll',
        view.money(view.net),
        'Calculated net payroll',
        Icons.check_circle_rounded,
        green,
        () => _showDetails(context, 'Net Payroll', payroll, [
              ('Employee', (r) => '${r['employee_id'] ?? ''}'),
              ('Net Pay', (r) => view.money(_net(r)))
            ])
      ),
      (
        'Payroll Deductions',
        view.money(view.deductions),
        'Statutory and other deductions',
        Icons.schedule_rounded,
        red,
        () => _showDetails(context, 'Payroll Deductions', payroll, [
              ('Employee', (r) => '${r['employee_id'] ?? ''}'),
              ('Deductions', (r) => view.money(_deductions(r)))
            ])
      ),
      (
        'Attendance Rate',
        '${attendance.toStringAsFixed(1)}%',
        '${attendanceRows.length} attendance records',
        Icons.bar_chart_rounded,
        const Color(0xFF12BFB4),
        () => _showDetails(context, 'Today Attendance', attendanceRows, [
              ('Employee', (r) => '${r['employee_id'] ?? ''}'),
              ('Status', (r) => '${r['status'] ?? ''}'),
              ('Check in', (r) => '${r['check_in'] ?? r['working_in'] ?? ''}')
            ])
      ),
      (
        'Overtime Hours',
        (otMinutes / 60).toStringAsFixed(1),
        '${otRows.length} OT requests',
        Icons.timer_outlined,
        purple,
        () => _showDetails(context, 'Overtime Requests', otRows, [
              ('Employee', (r) => '${r['employee_id'] ?? ''}'),
              ('Status', (r) => '${r['status'] ?? ''}'),
              (
                'Minutes',
                (r) =>
                    '${r['approved_minutes'] ?? r['minutes'] ?? r['duration_minutes'] ?? 0}'
              )
            ])
      )
    ];
    return LayoutBuilder(builder: (_, c) {
      final cols = c.maxWidth >= 1180
          ? 6
          : c.maxWidth >= 720
              ? 3
              : c.maxWidth >= 420
                  ? 2
                  : 1;
      final width = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: values
              .map((v) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                      onTap: v.$6,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                          width: width,
                          height: 124,
                          padding: const EdgeInsets.all(12),
                          decoration: card(),
                          child: Stack(children: [
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                          color: v.$5.withValues(alpha: .11),
                                          borderRadius:
                                              BorderRadius.circular(13)),
                                      child: Icon(v.$4, color: v.$5, size: 24)),
                                  const SizedBox(width: 11),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(v.$1,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF26466D))),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(v.$2,
                                                style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight:
                                                        FontWeight.w900))),
                                        const SizedBox(height: 5),
                                        Text(v.$3,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: muted,
                                                fontWeight: FontWeight.w700))
                                      ]))
                                ]),
                            Positioned(
                                right: 0,
                                bottom: 0,
                                child: CustomPaint(
                                    size: const Size(48, 20),
                                    painter: _SparkPainter(v.$5))),
                          ])))))
              .toList());
    });
  }

  Widget _topAnalytics(BuildContext context, AdminOverviewMetrics m) =>
      _responsive(
        context,
        [
          (2.35, _panel('Monthly Payroll Trend', _payrollTrend())),
          (
            1.08,
            _panel(
                'Payroll Split (${DateFormat('MMMM yyyy').format(view.month)})',
                _payrollSplit())
          ),
          (1.02, _panel('Gross vs Net Salary', _grossNet())),
        ],
        minWide: 1040,
      );

  Widget _middleAnalytics(BuildContext context, AdminOverviewMetrics m) =>
      _responsive(
        context,
        [
          (1.45, _panel('Attendance Monitoring', _attendance(context, m))),
          (1.45, _panel('Salary Analytics', _salaryAnalytics())),
        ],
        minWide: 900,
      );

  Widget _bottomAnalytics(BuildContext context, AdminOverviewMetrics m) =>
      _responsive(
        context,
        [
          (1.55, _panel('Branch Monitoring', _branchesTable(m))),
          (0.9, _panel('Branch Distribution', _branchDistribution())),
          (0.9, _panel('Quick Actions', _quickActions())),
          (0.9, _panel('Pending Approvals & Alerts', _approvals(m))),
        ],
        minWide: 1100,
      );

  Widget _responsive(BuildContext context, List<(double, Widget)> children,
          {required double minWide}) =>
      LayoutBuilder(builder: (_, c) {
        if (c.maxWidth < minWide) {
          return Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i].$2,
              if (i < children.length - 1) const SizedBox(height: 10)
            ]
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(
                flex: (children[i].$1 * 100).round(), child: children[i].$2),
            if (i < children.length - 1) const SizedBox(width: 10)
          ]
        ]);
      });

  Widget _panel(String title, Widget child) => Container(
      padding: const EdgeInsets.all(12),
      decoration: card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        child
      ]));

  Widget _payrollTrend() {
    final months = List.generate(
        7, (i) => DateTime(view.month.year, view.month.month - 6 + i));
    final values = months
        .map((month) => view.payrollRecords
            .where((r) => _monthMatches(r, month))
            .where((r) =>
                view.branch == null || _recordBranch(r) == _key(view.branch))
            .fold<double>(0, (sum, r) => sum + _gross(r)))
        .toList();
    return SizedBox(
        height: 190,
        child: Column(children: [
          Expanded(
              child: CustomPaint(
                  size: Size.infinite, painter: _ComboChartPainter(values))),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final month in months)
                  SizedBox(
                      width: 58,
                      child: Text(DateFormat('MMM yy').format(month),
                          textAlign: TextAlign.center))
              ]))
        ])).withTextScale(.72);
  }

  Widget _payrollSplit() {
    final total = view.net + view.deductions;
    final netPercent = total <= 0 ? 0.0 : view.net / total * 100;
    final deductionPercent = total <= 0 ? 0.0 : view.deductions / total * 100;
    return SizedBox(
        height: 190,
        child: Row(children: [
          Expanded(
              child: Stack(alignment: Alignment.center, children: [
            CustomPaint(
                size: const Size.square(150),
                painter: _DonutPainter([view.net, view.deductions])),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text(view.money(view.gross),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900)),
              const Text('Total Payroll', style: TextStyle(fontSize: 9))
            ])
          ])),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                _legend(
                    'Net payroll', '${netPercent.toStringAsFixed(1)}%', green),
                _legend('Deductions', '${deductionPercent.toStringAsFixed(1)}%',
                    orange)
              ]))
        ]));
  }

  Widget _legend(String label, String value, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 10))),
        Text(value,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800))
      ]));

  Widget _grossNet() {
    final previous = DateTime(view.month.year, view.month.month - 1);
    final previousRows = view.payrollRecords
        .where((r) => _monthMatches(r, previous))
        .where(
            (r) => view.branch == null || _recordBranch(r) == _key(view.branch))
        .toList();
    final previousGross =
        previousRows.fold<double>(0, (sum, r) => sum + _gross(r));
    final previousNet = previousRows.fold<double>(0, (sum, r) => sum + _net(r));
    return SizedBox(
        height: 190,
        child: CustomPaint(
            size: Size.infinite,
            painter: _DualBarsPainter(
                previousGross, previousNet, view.gross, view.net)));
  }

  Widget _attendance(BuildContext context, AdminOverviewMetrics m) {
    final present = m.present ?? 0,
        late = m.lateIds?.length ?? 0,
        leave = m.offIds?.length ?? 0,
        active = m.activeIds.length;
    final absent = math.max(0, active - present - late - leave);
    final boxes = [
      ('Present', present, green, Icons.groups),
      ('Absent', absent, red, Icons.person_off),
      ('Late', late, orange, Icons.timer),
      ('On Leave', leave, blue, Icons.work_off),
      ('Pending OT', m.pending('ot') ?? 0, purple, Icons.timelapse)
    ];
    final anomalies = m.lateRows ?? [];
    final attendanceRows = (m.activity['attendance'] as List? ?? const [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where((r) =>
            view.branch == null || _key(r['branch_id']) == _key(view.branch))
        .toList();
    return SingleChildScrollView(
        child: Column(children: [
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: boxes.map((b) {
            return Material(
                color: Colors.transparent,
                child: InkWell(
                    onTap: () {
                      if (b.$1 == 'Pending OT') {
                        view.onNavigate(11);
                        return;
                      }
                      final rows = attendanceRows.where((r) {
                        final status = _key(r['status']);
                        if (b.$1 == 'Present') {
                          return status == 'PRESENT' || status.isEmpty;
                        }
                        if (b.$1 == 'Late') return status.contains('LATE');
                        const leaveStatuses = {
                          'OFF',
                          'MC',
                          'PL',
                          'AL',
                          'EL',
                          'UNPAID',
                          'PH-OFF',
                          'PH-SPL'
                        };
                        if (b.$1 == 'On Leave') {
                          return leaveStatuses.contains(status);
                        }
                        return !leaveStatuses.contains(status) &&
                            status != 'PRESENT' &&
                            status != 'LATE';
                      }).toList();
                      _showDetails(context, '${b.$1} attendance', rows, [
                        ('Employee', (r) => '${r['employee_id'] ?? ''}'),
                        ('Status', (r) => '${r['status'] ?? ''}'),
                        (
                          'Check in',
                          (r) => '${r['check_in'] ?? r['working_in'] ?? ''}'
                        )
                      ]);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                        width: 112,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: b.$3.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(8)),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(b.$4, color: b.$3),
                              const SizedBox(height: 3),
                              Text(b.$1, style: const TextStyle(fontSize: 9)),
                              Text('${b.$2}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900))
                            ]))));
          }).toList()),
      const SizedBox(height: 12),
      SizedBox(
          height: 150,
          child: Row(children: [
            Expanded(
                child: CustomPaint(
                    size: Size.infinite,
                    painter:
                        _WeeklyBarsPainter([present, absent, late, leave]))),
            const SizedBox(width: 10),
            Expanded(
                child: _simpleTable(
                    ['Employee', 'Branch', 'Issue'],
                    anomalies
                        .take(5)
                        .map((r) => [
                              '${r['name']}',
                              '${view.branches[AdminOverviewMetrics.key(r['branch_id'])] ?? r['branch_id']}',
                              '${r['count']} occurrences'
                            ])
                        .toList()))
          ]))
    ]));
  }

  Widget _salaryAnalytics() {
    final records = _periodPayroll();
    final components = <double>[
      records.fold(
          0,
          (s, r) =>
              s +
              (_number(r['fw_salary']) != 0
                  ? _number(r['fw_salary'])
                  : _number(r['basic_salary']))),
      records.fold(0, (s, r) => s + _number(r['elaun_kedatangan'])),
      records.fold(0, (s, r) => s + _number(r['elaun_perkhidmatan'])),
      records.fold(0, (s, r) => s + _number(r['elaun_kerajinan'])),
      records.fold(0, (s, r) => s + _number(r['overtime'])),
      records.fold(0, (s, r) => s + _deductions(r)),
    ];
    final increments = _increments();
    return SizedBox(
        height: 238,
        child: Row(children: [
          Expanded(
              child: CustomPaint(
                  size: Size.infinite,
                  painter: _SalaryBarsPainter(components))),
          const SizedBox(width: 12),
          Expanded(
              child: _simpleTable(
                  ['Employee', 'Previous', 'Current', 'Increment'],
                  increments
                      .take(5)
                      .map((r) => [
                            '${r['name']}',
                            view.money(_number(r['previous'])),
                            view.money(_number(r['current'])),
                            view.money(_number(r['amount']))
                          ])
                      .toList()))
        ]));
  }

  Widget _branchesTable(AdminOverviewMetrics m) {
    final payroll = _periodPayroll();
    final attendance = (m.activity['attendance'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final rows = view.branches.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return _simpleTable([
      '#',
      'Branch',
      'Employees',
      'Payroll Total (RM)',
      'Checked in',
      'Records'
    ], [
      for (var i = 0; i < rows.length; i++)
        [
          '${i + 1}',
          rows[i].value,
          '${view.employees.where((e) => AdminOverviewMetrics.key(e['branch_id']) == AdminOverviewMetrics.key(rows[i].key)).length}',
          NumberFormat('#,##0.00').format(payroll
              .where((r) =>
                  _recordBranch(r) == AdminOverviewMetrics.key(rows[i].key))
              .fold<double>(0, (sum, r) => sum + _gross(r))),
          '${attendance.where((r) => AdminOverviewMetrics.key(r['branch_id']) == AdminOverviewMetrics.key(rows[i].key)).length}',
          '${payroll.where((r) => _recordBranch(r) == AdminOverviewMetrics.key(rows[i].key)).length}'
        ]
    ]);
  }

  Widget _branchDistribution() {
    final rows = view.branches.entries.map((entry) {
      final count = view.employees
          .where((e) =>
              AdminOverviewMetrics.key(e['branch_id']) ==
              AdminOverviewMetrics.key(entry.key))
          .length;
      return (entry.value, count);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final maximum = rows.fold<int>(1, (value, row) => math.max(value, row.$2));
    return SizedBox(
      height: 145,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 2),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 7),
        itemBuilder: (_, index) {
          final row = rows[index];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(row.$1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w700))),
                  Text('${row.$2}',
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800))
                ]),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: row.$2 / maximum,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                  color: blue,
                  backgroundColor: const Color(0xFFEAF1FA),
                )
              ]);
        },
      ),
    );
  }

  Widget _quickActions() => GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: .74,
          children: [
            _action('Run Payroll', Icons.play_circle, blue,
                () => view.onNavigate(2)),
            _action('Generate Payslips', Icons.receipt_long, green,
                () => view.onNavigate(12)),
            _action('Export Excel', Icons.file_download,
                const Color(0xFF00A890), view.onGross),
            _action('Review Attendance', Icons.calendar_month, purple,
                () => view.onNavigate(3)),
            _action('Approve Adjustments', Icons.check_circle, orange,
                () => view.onNavigate(10)),
          ]);
  Widget _action(String label, IconData icon, Color color, VoidCallback tap) =>
      Material(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
              onTap: tap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: color, size: 26),
                        const SizedBox(height: 6),
                        Text(label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700))
                      ]))));

  Widget _approvals(AdminOverviewMetrics m) {
    final payrollIssues = _periodPayroll()
        .where(
            (r) => _gross(r) <= 0 || _net(r) < 0 || _deductions(r) > _gross(r))
        .length;
    final increments = _increments().length;
    return Column(children: [
      _alert(
          'Missing Attendance',
          '${m.notChecked ?? 0} employees with missing check-in',
          red,
          () => view.onNavigate(3)),
      _alert('Payroll Mismatch', '$payrollIssues records require verification',
          orange, () => view.onNavigate(2)),
      _alert(
          'Pending Leave Requests',
          '${m.pending('leave') ?? 0} leave requests pending approval',
          purple,
          () => view.onNavigate(13)),
      _alert('Salary Increment Review', '$increments salary changes found',
          orange, () => view.onNavigate(10)),
    ]);
  }

  Widget _alert(String title, String detail, Color color, VoidCallback tap) =>
      InkWell(
          onTap: tap,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.assignment_outlined,
                        color: color, size: 16)),
                const SizedBox(width: 7),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700)),
                      Text(detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 8, color: muted))
                    ])),
                const Icon(Icons.chevron_right, size: 16)
              ])));

  Widget _simpleTable(List<String> headers, List<List<String>> rows) =>
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
              headingRowHeight: 30,
              dataRowMinHeight: 29,
              dataRowMaxHeight: 34,
              horizontalMargin: 7,
              columnSpacing: 13,
              headingTextStyle:
                  const TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
              dataTextStyle: const TextStyle(fontSize: 8),
              columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
              rows: rows
                  .map((r) => DataRow(
                      cells: r
                          .map((v) => DataCell(Text(v,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color:
                                      v.startsWith('+') || v.contains('Healthy')
                                          ? green
                                          : null,
                                  fontWeight: v.startsWith('+')
                                      ? FontWeight.w800
                                      : null))))
                          .toList()))
                  .toList()));

  Widget _detailsAndTools() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (view.reports != null) ...[
          const ListTile(
              title: Text('Payroll reports'),
              subtitle: Text(
                  'Open payroll, EPF, SOCSO, EIS, HRDF and summary reports')),
          Padding(padding: const EdgeInsets.all(12), child: view.reports!),
        ],
        ExpansionTile(
            key: const PageStorageKey('overview-payroll-details'),
            title: const Text('Detailed payroll breakdown'),
            children: [view.breakdown]),
        const ListTile(title: Text('More management tools')),
        view.tools,
      ]);
}

extension on Widget {
  Widget withTextScale(double factor) => MediaQuery(
      data: const MediaQueryData()
          .copyWith(textScaler: TextScaler.linear(factor)),
      child: this);
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    final path = Path()..moveTo(0, s.height);
    for (var i = 1; i < 8; i++) {
      path.lineTo(
          s.width * i / 7, s.height - (i % 3 + 2) * s.height / 5 + (i * 2 % 5));
    }
    c.drawPath(path, p);
    c.drawPath(
        Path.from(path)
          ..lineTo(s.width, s.height)
          ..lineTo(0, s.height)
          ..close(),
        Paint()..color = color.withValues(alpha: .09));
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _ComboChartPainter extends CustomPainter {
  const _ComboChartPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()
      ..color = _ReferencePayrollDashboard.line
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      c.drawLine(
          Offset(0, s.height * i / 5), Offset(s.width, s.height * i / 5), grid);
    }
    final maximum = values.fold<double>(1, math.max);
    final count = math.max(1, values.length);
    final bw = s.width / (count * 1.65);
    for (var i = 0; i < values.length; i++) {
      final ratio = values[i] / maximum;
      c.drawRect(
          Rect.fromLTWH(s.width * (i + .2) / count, s.height * (1 - ratio * .9),
              bw, s.height * ratio * .9),
          Paint()
            ..shader = const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF58A1FF), Color(0xFF1E65E8)])
                .createShader(Offset.zero & s));
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final o = Offset(s.width * (i + .5) / count,
          s.height * (1 - values[i] / maximum * .9));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      c.drawCircle(o, 5, Paint()..color = const Color(0xFF0FA7A7));
    }
    c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0FA7A7)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTWH(12, 12, s.width - 24, s.height - 24),
        p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    var start = -math.pi / 2;
    final colors = [
      _ReferencePayrollDashboard.green,
      _ReferencePayrollDashboard.orange
    ];
    if (total <= 0) {
      c.drawArc(r, start, math.pi * 2, false,
          p..color = _ReferencePayrollDashboard.line);
      return;
    }
    for (var i = 0; i < values.length; i++) {
      final a = values[i] / total * math.pi * 2;
      c.drawArc(r, start, a, false, p..color = colors[i % colors.length]);
      start += a;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _DualBarsPainter extends CustomPainter {
  const _DualBarsPainter(
      this.previousGross, this.previousNet, this.currentGross, this.currentNet);
  final double previousGross, previousNet, currentGross, currentNet;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint();
    for (var i = 0; i < 5; i++) {
      c.drawLine(Offset(0, s.height * i / 5), Offset(s.width, s.height * i / 5),
          Paint()..color = _ReferencePayrollDashboard.line);
    }
    final maxValue = [previousGross, previousNet, currentGross, currentNet]
        .fold<double>(1, math.max);
    for (var group = 0; group < 2; group++) {
      final gross = group == 0 ? previousGross : currentGross;
      final net = group == 0 ? previousNet : currentNet;
      final x = s.width * (.18 + group * .5);
      c.drawRect(
          Rect.fromLTWH(x, s.height * (1 - gross / maxValue * .75),
              s.width * .14, s.height * gross / maxValue * .75),
          p..color = _ReferencePayrollDashboard.cyan);
      c.drawRect(
          Rect.fromLTWH(
              x + s.width * .15,
              s.height * (1 - net / maxValue * .75),
              s.width * .14,
              s.height * net / maxValue * .75),
          p..color = const Color(0xFF114989));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _WeeklyBarsPainter extends CustomPainter {
  const _WeeklyBarsPainter(this.values);
  final List<int> values;

  @override
  void paint(Canvas c, Size s) {
    final colors = [
      _ReferencePayrollDashboard.green,
      _ReferencePayrollDashboard.red,
      _ReferencePayrollDashboard.orange,
      _ReferencePayrollDashboard.purple
    ];
    final maximum = values.fold<int>(1, math.max);
    for (var i = 0; i < values.length; i++) {
      final x = s.width * (i + .25) / math.max(1, values.length);
      final h = s.height * values[i] / maximum * .9;
      c.drawRect(Rect.fromLTWH(x, s.height - h, s.width * .1, h),
          Paint()..color = colors[i % colors.length]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _SalaryBarsPainter extends CustomPainter {
  const _SalaryBarsPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas c, Size s) {
    final colors = [
      _ReferencePayrollDashboard.blue,
      _ReferencePayrollDashboard.cyan,
      _ReferencePayrollDashboard.green,
      _ReferencePayrollDashboard.orange,
      _ReferencePayrollDashboard.purple,
      _ReferencePayrollDashboard.red
    ];
    final maximum = values.fold<double>(1, math.max);
    for (var i = 0; i < values.length; i++) {
      final w = s.width / 9,
          x = s.width * (i + .45) / 6,
          h = (s.height - 20) * values[i] / maximum;
      c.drawRect(
          Rect.fromLTWH(x, s.height - h, w, h), Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
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
