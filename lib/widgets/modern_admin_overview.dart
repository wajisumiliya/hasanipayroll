import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const adminInk = Color(0xFF252A32);
const adminGold = Color(0xFF8D652B);
const adminCanvas = Color(0xFFF6F3EC);
const adminBorder = Color(0xFFE9E1D4);
const adminMuted = Color(0xFF796F63);

/// Pure live-data projection shared by desktop and mobile.
class AdminOverviewMetrics {
  AdminOverviewMetrics(
      {required this.employees, required this.activity, this.branch});
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
        .where((r) =>
            matches(r) &&
            activeIds.contains(id(r)) &&
            validCheckIn(r) &&
            !{'OFF', 'MC', 'PL', 'AL', 'EL', 'UNPAID', 'PH-OFF', 'PH-SPL'}
                .contains(key(r['status'])))
        .map(id)
        .toSet();
  }

  late final Set<String>? lateIds = _lateIds();
  Set<String>? _lateIds() {
    final attendance = _attendance;
    if (attendance == null) return null;
    return attendance
        .where((r) =>
            checkedIn!.contains(id(r)) &&
            matches(r) &&
            key(r['status']).contains('LATE'))
        .map(id)
        .toSet();
  }

  late final Set<String>? offIds = _offIds();
  Set<String>? _offIds() {
    final attendance = _attendance;
    if (attendance == null) return null;
    return attendance
        .where((r) =>
            matches(r) &&
            activeIds.contains(id(r)) &&
            !checkedIn!.contains(id(r)) &&
            {'OFF', 'MC', 'PL', 'AL', 'EL', 'PH', 'UNPAID', 'PH-OFF', 'PH-SPL'}
                .contains(key(r['status'])))
        .map(id)
        .toSet();
  }

  int? get present =>
      checkedIn == null ? null : checkedIn!.length - lateIds!.length;
  int? get notChecked => checkedIn == null
      ? null
      : activeIds.difference({...checkedIn!, ...offIds!}).length;
  int? pending(String field) => rows(field)
      ?.where((r) =>
          matches(r) &&
          (field == 'employee'
              ? (activity['staff_scope'] != 'local' &&
                      activity['staff_scope'] != 'foreign' ||
                  (activity['staff_scope'] == 'foreign') ==
                      key(r['address']).contains('FRN'))
              : allIds.contains(id(r))) &&
          (field == 'employee'
              ? key(r['status']) == 'PENDING'
              : key(r['status']) == 'PENDING_ADMIN'))
      .length;
}

class ModernAdminOverview extends StatelessWidget {
  const ModernAdminOverview(
      {super.key,
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
      this.reports});
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
  String money(double v) =>
      NumberFormat.currency(locale: 'en_MY', symbol: 'RM ', decimalDigits: 2)
          .format(v);
  Widget panel(String title, IconData icon, Widget child,
          {String? action, VoidCallback? onAction}) =>
      Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x12000000),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: adminBorder)),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(builder: (context, c) {
                      final heading = Row(children: [
                        Icon(icon, color: adminGold, size: 21),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: adminInk)))
                      ]);
                      if (action == null) return heading;
                      if (c.maxWidth < 400) {
                        return Row(children: [
                          Expanded(child: heading),
                          IconButton(
                              tooltip: action,
                              onPressed: onAction,
                              icon: const Icon(Icons.chevron_right,
                                  color: adminGold))
                        ]);
                      }
                      return Row(children: [
                        Expanded(child: heading),
                        TextButton(onPressed: onAction, child: Text(action))
                      ]);
                    }),
                    const SizedBox(height: 16),
                    child,
                  ])));
  Widget paired(Widget left, Widget right, {int flex = 3}) => LayoutBuilder(
      builder: (_, c) => c.maxWidth >= 950
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: flex, child: left),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: right)
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [left, const SizedBox(height: 16), right]));

  Future<void> choosePeriod(BuildContext context) async {
    var selection = month;
    final result = await showDialog<DateTime>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: const Text('Choose report month'),
                  content: SizedBox(
                      width: 320,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<int>(
                            initialValue: selection.month,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Month'),
                            items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(DateFormat('MMMM')
                                        .format(DateTime(2026, i + 1))))),
                            onChanged: (v) {
                              if (v != null) {
                                update(() =>
                                    selection = DateTime(selection.year, v));
                              }
                            }),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                            initialValue: selection.year,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Year'),
                            items: (<int>{
                              month.year,
                              DateTime.now().year + 1,
                              ...List.generate(
                                  15, (i) => DateTime.now().year - i)
                            }.toList()
                                  ..sort((a, b) => b.compareTo(a)))
                                .map((y) => DropdownMenuItem(
                                    value: y, child: Text('$y')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                update(() =>
                                    selection = DateTime(v, selection.month));
                              }
                            }),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, selection),
                        child: const Text('Apply'))
                  ],
                )));
    if (result != null) onMonth(result);
  }

  Widget filters(BuildContext context) => LayoutBuilder(builder: (_, c) {
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
                                  prefixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 14)),
                              child: Row(children: [
                                Expanded(
                                    child: Text(
                                        DateFormat(compact
                                                ? 'MMM yyyy'
                                                : 'MMMM yyyy')
                                            .format(month),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12))),
                                const Icon(Icons.expand_more, size: 18)
                              ]))))),
              SizedBox(
                  width: compact ? (c.maxWidth - 10) / 2 : 220,
                  child: DropdownButtonFormField<String>(
                      key: ValueKey('branch-$branch'),
                      initialValue: branch ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Branch',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 14)),
                      items: [
                        const DropdownMenuItem(
                            value: '',
                            child: Text('All branches',
                                style: TextStyle(fontSize: 12))),
                        ...branches.entries.map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12))))
                      ],
                      onChanged: (v) => onBranch(v == '' ? null : v))),
              OutlinedButton.icon(
                  onPressed: () => onNavigate(6),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export report')),
            ]);
      });

  Widget metrics(AdminOverviewMetrics m) => LayoutBuilder(builder: (_, c) {
        final compact = c.maxWidth < 800;
        final columns = c.maxWidth < 580 ? 2 : 4;
        final entries = [
          (
            'Total employees',
            '${m.people.length}',
            Icons.groups_outlined,
            adminGold,
            () => onNavigate(1)
          ),
          (
            'Active employees',
            '${m.activeIds.length}',
            Icons.person_outline,
            const Color(0xFF16A777),
            () => onNavigate(1)
          ),
          (
            'Present today',
            m.present?.toString() ?? '—',
            Icons.event_available_outlined,
            adminGold,
            () => onNavigate(3)
          ),
          (
            'Late today',
            m.lateIds?.length.toString() ?? '—',
            Icons.schedule,
            const Color(0xFFE59320),
            () => onNavigate(3)
          )
        ];
        return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: entries
                .map((e) => SizedBox(
                    width: (c.maxWidth - (columns - 1) * 12) / columns,
                    child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide.none),
                        child: InkWell(
                            onTap: e.$5,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                                padding: EdgeInsets.all(compact ? 12 : 18),
                                child: Row(children: [
                                  CircleAvatar(
                                      radius: compact ? 15 : 22,
                                      backgroundColor:
                                          e.$4.withValues(alpha: .09),
                                      child: Icon(e.$3,
                                          color: e.$4,
                                          size: compact ? 18 : 22)),
                                  SizedBox(width: compact ? 8 : 14),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(e.$1,
                                            style: TextStyle(
                                                color: adminMuted,
                                                fontSize: compact ? 10 : 12)),
                                        const SizedBox(height: 4),
                                        Text(e.$2,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: compact ? 23 : 29,
                                                color: adminInk))
                                      ])),
                                ]))))))
                .toList());
      });
  Widget payroll() => panel(
      'Payroll overview',
      Icons.bar_chart_outlined,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Net payroll', style: TextStyle(color: adminMuted)),
        InkWell(
            onTap: onNet,
            child: Text(money(net),
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: adminInk))),
        const SizedBox(height: 18),
        Wrap(spacing: 30, runSpacing: 12, children: [
          InkWell(
              onTap: onGross,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gross payroll'),
                    Text(money(gross),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: adminInk))
                  ])),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Deductions'),
            Text(money(deductions),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: adminInk))
          ])
        ]),
        const SizedBox(height: 22),
        const Text('Gross payroll', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
            value: gross > 0 ? 1 : 0,
            minHeight: 9,
            borderRadius: BorderRadius.circular(9),
            backgroundColor: const Color(0xFFF1EBDF),
            color: adminGold),
        const SizedBox(height: 14),
        const Text('Net payroll', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        LinearProgressIndicator(
            value: gross > 0 ? (net / gross).clamp(0, 1) : 0,
            minHeight: 9,
            borderRadius: BorderRadius.circular(9),
            backgroundColor: const Color(0xFFF1EBDF),
            color: const Color(0xFFD7BE8B)),
      ]),
      action: 'View payroll',
      onAction: () => onNavigate(2));

  Widget attendance(AdminOverviewMetrics m) {
    final values = [
      m.present ?? 0,
      m.lateIds?.length ?? 0,
      m.notChecked ?? 0,
      m.offIds?.length ?? 0
    ];
    const colors = [
      Color(0xFF20B879),
      Color(0xFFF4BE42),
      Color(0xFF9DACBF),
      Color(0xFFDEE6F0)
    ];
    Widget legend(int i, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(shape: BoxShape.circle)
                  .copyWith(color: colors[i])),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(m.checkedIn == null ? '—' : '${values[i]}',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, color: adminInk))
        ]));
    return panel(
        'Attendance today',
        Icons.event_available_outlined,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              DateFormat('EEE, dd MMM yyyy')
                  .format(DateTime.now().toUtc().add(const Duration(hours: 8))),
              style: const TextStyle(fontSize: 12, color: adminMuted)),
          const SizedBox(height: 18),
          Row(children: [
            SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                    painter: _AttendanceRing(values, colors),
                    child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${m.activeIds.length}',
                          style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: adminInk)),
                      const Text('Active', style: TextStyle(fontSize: 12))
                    ])))),
            const SizedBox(width: 20),
            Expanded(
                child: Column(children: [
              legend(0, 'Present'),
              legend(1, 'Late'),
              legend(2, 'Not checked in'),
              if (values[3] > 0) legend(3, 'Off / leave')
            ]))
          ]),
          if (m.checkedIn == null)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'Attendance is loading or unavailable. Refresh to retry.',
                    style: TextStyle(fontSize: 12, color: adminMuted))),
        ]),
        action: 'View attendance',
        onAction: () => onNavigate(3));
  }

  Widget late(AdminOverviewMetrics m) => panel(
      'Late Report',
      Icons.schedule,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('3 or more combined monthly occurrences',
            style: TextStyle(fontSize: 12, color: adminMuted)),
        const SizedBox(height: 14),
        if (m.lateRows == null)
          const Text('Report is loading or unavailable. Refresh to retry.')
        else if (m.lateRows!.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('No employees meet the monthly threshold.'))
        else
          LayoutBuilder(builder: (_, c) {
            final rows = m.lateRows!.take(5).toList();
            Widget badge(dynamic count) {
              final value = (count as num).toInt();
              final color = value >= 7
                  ? const Color(0xFFBB3434)
                  : value >= 5
                      ? const Color(0xFFB76920)
                      : const Color(0xFFA87A10);
              return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$value',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w800)));
            }

            if (c.maxWidth < 600) {
              return Column(
                  children: rows
                      .map((r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: onLateReport,
                          title: Text('${r['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${branches[AdminOverviewMetrics.key(r['branch_id'])] ?? r['branch_id']} · ${r['arrival_count']} arrivals · ${r['break_count']} breaks'),
                          trailing: badge(r['count'])))
                      .toList());
            }
            return Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(1.8),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                  4: FlexColumnWidth()
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFFAF7F1)),
                      children: [
                        'Employee',
                        'Branch',
                        'Arrivals',
                        'Breaks',
                        'Total'
                      ]
                          .map((s) => Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(s,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600))))
                          .toList()),
                  ...rows.map((r) => TableRow(
                          children: [
                        r['name'],
                        branches[AdminOverviewMetrics.key(r['branch_id'])] ??
                            r['branch_id'],
                        r['arrival_count'],
                        r['break_count'],
                        r['count']
                      ]
                              .asMap()
                              .entries
                              .map((e) => InkWell(
                                  onTap: onLateReport,
                                  child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: e.key == 4
                                          ? badge(e.value)
                                          : Text('${e.value}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 12)))))
                              .toList())),
                ]);
          }),
      ]),
      action: 'View report',
      onAction: onLateReport);

  Widget approvals(AdminOverviewMetrics m) => panel(
      'Needs your approval',
      Icons.fact_check_outlined,
      Column(children: [
        for (final item in [
          ('Leave requests', 'leave', 13),
          ('Overtime requests', 'ot', 11),
          ('Employee requests', 'employee', 10)
        ])
          ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: () => onNavigate(item.$3),
              title: Text(item.$1),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(m.pending(item.$2)?.toString() ?? '—',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: adminInk)),
                const SizedBox(width: 12),
                const Icon(Icons.chevron_right, size: 18)
              ])),
      ]));
  Widget celebrations() => panel(
      'Upcoming celebrations',
      Icons.card_giftcard_outlined,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final item in [
          (birthdays, false, 'Birthday', Icons.cake_outlined),
          (anniversaries, true, 'Work anniversary', Icons.star_outline)
        ]) ...[
          Text(item.$3,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: adminInk)),
          if (item.$1.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No events in the next 3 days',
                    style: TextStyle(fontSize: 12, color: adminMuted)))
          else
            ...item.$1.take(3).map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading:
                    Icon(item.$4, color: const Color(0xFFD7A22F), size: 20),
                title: Text('${e['name']}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text((e['days'] as int) == 0
                    ? 'Today'
                    : (e['days'] as int) == 1
                        ? 'Tomorrow'
                        : 'In ${e['days']} days'),
                trailing: IconButton(
                    tooltip: 'Send ${item.$3.toLowerCase()} wish',
                    onPressed: () => onCelebrate(e, item.$2),
                    icon: const Icon(Icons.send_outlined, size: 17)))),
          const SizedBox(height: 8),
        ],
      ]));

  @override
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
            primary: adminGold,
            secondary: Color(0xFFD4A532),
            surface: Colors.white,
            onSurface: adminInk),
        textTheme: Theme.of(context)
            .textTheme
            .apply(bodyColor: adminInk, displayColor: adminInk),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: adminBorder))),
      ),
      child: RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WELCOME BACK',
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w600,
                            color: adminGold)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          child: const Text('Payroll Dashboard',
                              style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: adminInk))),
                      IconButton(
                          tooltip: 'Refresh dashboard',
                          onPressed: () => onRefresh(),
                          icon: const Icon(Icons.refresh, color: adminInk))
                    ]),
                    const SizedBox(height: 5),
                    const Text(
                        'Monitor payroll, statutory contributions and workforce performance',
                        style: TextStyle(color: adminMuted)),
                    const SizedBox(height: 22),
                    filters(context),
                    const SizedBox(height: 22),
                    if (reports != null) ...[
                      const Text('Payroll reports',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: adminInk)),
                      const SizedBox(height: 5),
                      const Text('Preview or export each report separately',
                          style: TextStyle(color: adminMuted, fontSize: 12)),
                      const SizedBox(height: 12),
                      reports!,
                      const SizedBox(height: 22),
                    ],
                    FutureBuilder<Map<String, dynamic>>(
                        future: activity,
                        builder: (_, s) {
                          final m = AdminOverviewMetrics(
                              employees: employees,
                              activity:
                                  s.connectionState == ConnectionState.done
                                      ? s.data ?? {}
                                      : {},
                              branch: branch);
                          return paired(
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  panel('Workforce snapshot',
                                      Icons.groups_outlined, metrics(m)),
                                  const SizedBox(height: 18),
                                  payroll(),
                                  const SizedBox(height: 18),
                                  late(m),
                                ]),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  attendance(m),
                                  const SizedBox(height: 18),
                                  approvals(m),
                                  const SizedBox(height: 18),
                                  celebrations()
                                ]),
                          );
                        }),
                    const SizedBox(height: 20),
                    Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: adminBorder)),
                        child: ExpansionTile(
                            key: const PageStorageKey(
                                'overview-payroll-details'),
                            title: const Text('Detailed payroll breakdown'),
                            subtitle: const Text(
                                'Statutory contributions, allowances and payroll tools'),
                            children: [breakdown])),
                    const SizedBox(height: 20),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExpansionTile(
                              key: const PageStorageKey(
                                  'overview-management-tools'),
                              title: const Text('More management tools'),
                              children: [tools]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            for (final action in [
                              ('Payslips', 12, Icons.receipt_long_outlined),
                              ('Reports', 6, Icons.bar_chart_outlined),
                              ('Daily reports', 14, Icons.description_outlined),
                              ('Branch logs', 9, Icons.store_outlined),
                              ('Settings', 7, Icons.settings_outlined)
                            ])
                              OutlinedButton.icon(
                                  onPressed: () => onNavigate(action.$2),
                                  icon: Icon(action.$3, size: 17),
                                  label: Text(action.$1))
                          ])
                        ]),
                  ]))));
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
        ring, 0, math.pi * 2, false, p..color = const Color(0xFFF1EBDF));
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
    'Payroll Summary'
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
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
                reports.map((report) => itemBuilder(width, report)).toList());
      });
}

/// Concept B report library: independent report actions with live monthly figures.
class IvoryAdminReportCard extends StatelessWidget {
  const IvoryAdminReportCard(
      {super.key,
      required this.width,
      required this.title,
      required this.icon,
      required this.value,
      required this.caption,
      required this.onTap,
      this.logoBytes});
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
        elevation: 1,
        shadowColor: const Color(0x18000000),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: const BorderSide(color: adminBorder)),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(children: [
                  Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8F1E3),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: adminGold, size: 27)),
                  const SizedBox(width: 15),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(title,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: adminInk))),
                          if (logoBytes != null)
                            Image.memory(logoBytes!,
                                width: 30,
                                height: 19,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink())
                        ]),
                        const SizedBox(height: 7),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(value,
                                maxLines: 1,
                                style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: adminInk))),
                        const SizedBox(height: 6),
                        Text(caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: adminMuted)),
                      ])),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: adminGold, size: 17),
                ]))),
      ));
}
