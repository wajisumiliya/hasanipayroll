import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'supabase_service.dart';

class MonthlyRosterPage extends StatefulWidget {
  final String branchId;
  const MonthlyRosterPage({super.key, required this.branchId});

  @override
  State<MonthlyRosterPage> createState() => _MonthlyRosterPageState();
}

class _Shift {
  final String label;
  final String start;
  final String end;
  final int breakMinutes;
  const _Shift(this.label, this.start, this.end, this.breakMinutes);
}

class _MonthlyRosterPageState extends State<MonthlyRosterPage> {
  static const shifts = <_Shift>[
    _Shift('9:00 AM – 5:30 PM', '09:00', '17:30', 60),
    _Shift('9:00 AM – 6:00 PM', '09:00', '18:00', 90),
    _Shift('10:00 AM – 7:00 PM', '10:00', '19:00', 90),
    _Shift('11:00 AM – 8:00 PM', '11:00', '20:00', 90),
    _Shift('12:00 PM – 9:00 PM', '12:00', '21:00', 90),
    _Shift('1:00 PM – 10:00 PM', '13:00', '22:00', 90),
  ];
  static const weekdays = <int, String>{
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  int week = 1;
  _Shift shift = shifts.first;
  int? offDay;
  String search = '';
  final selectedIds = <String>{};
  bool saving = false;

  Future<List<dynamic>> _load() => Future.wait([
        SupabaseService.getEmployeesByBranch(widget.branchId),
        SupabaseService.getMonthlyRosters(
          branchId: widget.branchId,
          year: month.year,
          month: month.month,
        ),
      ]);

  String _id(Map<String, dynamic> employee) =>
      (employee['employee_id'] ?? employee['id'] ?? '').toString().trim();

  String _time(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  Future<void> _chooseMonth() async {
    final result = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result == null || !mounted) return;
    setState(() {
      month = DateTime(result.year, result.month);
      selectedIds.clear();
    });
  }

  Future<void> _save() async {
    if (selectedIds.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final updatedAt = DateTime.now().toUtc().toIso8601String();
      for (final employeeId in selectedIds) {
        await SupabaseService.saveMonthlyRoster({
          'branch_id': widget.branchId,
          'employee_id': employeeId,
          'roster_year': month.year,
          'roster_month': month.month,
          'week_number': week,
          'shift_start': shift.start,
          'shift_end': shift.end,
          'break_minutes': shift.breakMinutes,
          'off_weekday': offDay,
          'updated_at': updatedAt,
        });
      }
      final activityId = await SupabaseService.startBranchActivity(
        branchId: widget.branchId,
        action: 'ROSTER_ASSIGNED',
        details: {
          'month': DateFormat('yyyy-MM').format(month),
          'week': week,
          'shift': shift.label,
          'shift_start': shift.start,
          'shift_end': shift.end,
          'break_minutes': shift.breakMinutes,
          'off_day': offDay == null ? 'None' : weekdays[offDay],
          'employee_count': selectedIds.length,
          'employee_ids': selectedIds.toList()..sort(),
        },
      );
      await SupabaseService.closeBranchActivity(activityId);
      if (!mounted) return;
      final count = selectedIds.length;
      setState(() {
        saving = false;
        selectedIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count employee(s) assigned for Week $week.'),
        backgroundColor: Colors.green,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Unable to save shift: $error'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load roster:\n${snapshot.error}'));
          }
          final all =
              List<Map<String, dynamic>>.from(snapshot.data![0] as List);
          final rosters =
              List<Map<String, dynamic>>.from(snapshot.data![1] as List);
          final query = search.trim().toLowerCase();
          final employees = all
              .where((employee) =>
                  query.isEmpty ||
                  (employee['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(query) ||
                  _id(employee).toLowerCase().contains(query))
              .toList();
          final visibleIds =
              employees.map(_id).where((id) => id.isNotEmpty).toSet();
          final allSelected =
              visibleIds.isNotEmpty && visibleIds.every(selectedIds.contains);

          return ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Monthly Shift Roster',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Choose a shift, select employees, then save the assignment.'),
            const SizedBox(height: 16),
            Card(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _chooseMonth,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(DateFormat('MMMM yyyy').format(month)),
                    ),
                    SizedBox(
                        width: 130,
                        child: DropdownButtonFormField<int>(
                          initialValue: week,
                          decoration: const InputDecoration(
                              labelText: 'Week', isDense: true),
                          items: List.generate(
                              5,
                              (i) => DropdownMenuItem(
                                  value: i + 1, child: Text('Week ${i + 1}'))),
                          onChanged: (value) =>
                              setState(() => week = value ?? week),
                        )),
                    SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<_Shift>(
                          initialValue: shift,
                          decoration: const InputDecoration(
                              labelText: 'Available shift', isDense: true),
                          items: shifts
                              .map((item) => DropdownMenuItem(
                                  value: item, child: Text(item.label)))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => shift = value ?? shift),
                        )),
                    SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<int?>(
                          initialValue: offDay,
                          decoration: const InputDecoration(
                              labelText: 'Weekly OFF day', isDense: true),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('No OFF day')),
                            ...weekdays.entries.map((entry) =>
                                DropdownMenuItem<int?>(
                                    value: entry.key,
                                    child: Text(entry.value))),
                          ],
                          onChanged: (value) => setState(() => offDay = value),
                        )),
                  ]),
            )),
            const SizedBox(height: 8),
            Text(
                '${shift.label} • ${shift.breakMinutes} minutes break • Net 7 hours 30 minutes',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search employee name or ID',
                    isDense: true),
              )),
              const SizedBox(width: 12),
              Checkbox(
                  value: allSelected,
                  onChanged: visibleIds.isEmpty
                      ? null
                      : (value) {
                          setState(() => value == true
                              ? selectedIds.addAll(visibleIds)
                              : selectedIds.removeAll(visibleIds));
                        }),
              const Text('Select all'),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: selectedIds.isEmpty || saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text('Save (${selectedIds.length})'),
              ),
            ]),
            const SizedBox(height: 12),
            ...employees.map((employee) {
              final employeeId = _id(employee);
              final matches = rosters.where((item) =>
                  item['employee_id'].toString() == employeeId &&
                  item['week_number'].toString() == week.toString());
              final current = matches.isEmpty ? null : matches.first;
              final assignment = current == null
                  ? 'Not assigned for Week $week'
                  : '${_time(current['shift_start'])}–${_time(current['shift_end'])} • '
                      '${current['break_minutes']} min break${current['off_weekday'] == null ? '' : ' • OFF ${weekdays[int.tryParse(current['off_weekday'].toString())]}'}';
              final name = (employee['name'] ?? employeeId).toString();
              return Card(
                  child: CheckboxListTile(
                dense: true,
                value: selectedIds.contains(employeeId),
                onChanged: employeeId.isEmpty
                    ? null
                    : (value) => setState(() => value == true
                        ? selectedIds.add(employeeId)
                        : selectedIds.remove(employeeId)),
                secondary: CircleAvatar(
                    child: Text(name.trim().isEmpty ? '?' : name.trim()[0])),
                title: Text(name),
                subtitle: Text('$employeeId • $assignment'),
              ));
            }),
          ]);
        },
      );
}
