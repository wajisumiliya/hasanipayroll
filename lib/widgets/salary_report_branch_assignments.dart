import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Report grouping only. Saving never updates employee or payroll records.
class SalaryReportBranchAssignments extends StatefulWidget {
  const SalaryReportBranchAssignments({super.key, required this.startYear,
    required this.load, required this.save});
  final int startYear;
  final Future<Map<String, dynamic>> Function(int year) load;
  final Future<void> Function(Map<String, dynamic> assignment, bool remove) save;

  @override
  State<SalaryReportBranchAssignments> createState() => _AssignmentState();
}

class _AssignmentState extends State<SalaryReportBranchAssignments> {
  Map<String, dynamic>? data;
  String? employee, branch, error, success;
  late String from = '${widget.startYear}-07';
  late String through = '${widget.startYear + 1}-06';
  bool loading = true, saving = false;
  List<Map<String, dynamic>> rows(String field) =>
      (data?[field] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<String> get months => List.generate(12, (i) =>
      DateFormat('yyyy-MM').format(DateTime(widget.startYear, 7 + i)));
  String monthLabel(String value) => DateFormat('MMM yyyy').format(DateTime.parse('$value-01'));
  bool get busy => loading || saving;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.load(widget.startYear);
      if (mounted) setState(() {
        data = result;
        if (!rows('employees').any((row) => row['employee_id'] == employee)) employee = null;
        if (!rows('branches').any((row) => row['id'] == branch)) branch = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to load assignments: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit(bool remove) async {
    if (employee == null || (!remove && branch == null)) {
      setState(() => error = 'Select an employee and branch first.');
      return;
    }
    if (from.compareTo(through) > 0) {
      setState(() => error = 'The end month must be on or after the start month.');
      return;
    }
    if (remove) {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('Remove report assignments?'),
        content: Text('Remove $employee assignments for ${monthLabel(from)} through ${monthLabel(through)}? The report will use the saved payroll branch, or the employee branch if none was saved.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))]));
      if (confirm != true || !mounted) return;
    }
    setState(() { saving = true; error = null; success = null; });
    try {
      await widget.save({'employee_id': employee, if (!remove) 'branch_id': branch,
        'from_month': from, 'through_month': through}, remove);
      if (!mounted) return;
      setState(() => success = remove ? 'Assignments removed.' : 'Assignments saved. Excel and PDF will use this branch.');
      await reload();
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to save assignments: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget select({required String label, required String? value,
    required List<DropdownMenuItem<String>> items, required ValueChanged<String?> changed}) =>
      DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'), initialValue: value, isExpanded: true,
        decoration: InputDecoration(labelText: label), items: items,
        onChanged: busy ? null : changed);

  @override
  Widget build(BuildContext context) {
    final selected = rows('assignments').where((a) => a['employee_id'] == employee).toList();
    final branchNames = {for (final b in rows('branches')) '${b['id']}': '${b['name']}'};
    return PopScope(canPop: !saving, child: AlertDialog(
      title: const Text('Salary Report Branch Assignments'),
      content: SizedBox(width: 640, height: 520, child: loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Jul ${widget.startYear} – Jun ${widget.startYear + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Choose an employee, a branch, and a month or month range. This changes Salary Report grouping only; salary amounts and the employee’s current branch stay unchanged.'),
          const SizedBox(height: 16),
          select(label: 'Employee', value: employee,
            items: rows('employees').map((e) => DropdownMenuItem<String>(value: '${e['employee_id']}',
              child: Text('${e['employee_id']} · ${e['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
            changed: (value) => setState(() { employee = value; success = null; error = null; })),
          const SizedBox(height: 14),
          select(label: 'Payroll branch for report', value: branch,
            items: rows('branches').map((b) => DropdownMenuItem<String>(value: '${b['id']}',
              child: Text('${b['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
            changed: (value) => setState(() => branch = value)),
          const SizedBox(height: 14),
          select(label: 'From month', value: from,
            items: months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
            changed: (value) => setState(() => from = value!)),
          const SizedBox(height: 14),
          select(label: 'Through month', value: through,
            items: months.map((m) => DropdownMenuItem(value: m, child: Text(monthLabel(m)))).toList(),
            changed: (value) => setState(() => through = value!)),
          const SizedBox(height: 12),
          const Text('Existing assignments cannot overlap. To replace a branch, remove assignments for the selected range, then save the replacement.'),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          if (success != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(success!, style: const TextStyle(color: Colors.green))),
          if (employee != null) ...[
            const SizedBox(height: 16),
            const Text('Saved assignments', style: TextStyle(fontWeight: FontWeight.bold)),
            if (selected.isEmpty) const Text('No assignments. The report uses the saved payroll branch, then the employee branch.'),
            for (final a in selected) Padding(padding: const EdgeInsets.only(top: 4),
              child: Text('${monthLabel('${a['month']}')} — ${branchNames['${a['branch_id']}'] ?? a['branch_id']}')),
          ],
        ]))),
      actions: [
        TextButton(onPressed: busy ? null : reload, child: const Text('Refresh')),
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Done')),
        TextButton(onPressed: busy || selected.isEmpty ? null : () => submit(true), child: const Text('Remove selected range')),
        FilledButton(onPressed: busy || data == null ? null : () => submit(false), child: Text(saving ? 'Saving…' : 'Save assignment')),
      ],
    ));
  }
}
